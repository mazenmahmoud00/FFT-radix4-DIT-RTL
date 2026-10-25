`timescale 1ns/1ps
import complex_pack::*;

// Self-checking testbench for fft_top (64-pt radix-4 DIT, 3-stage pipeline)
//   in : Q4.12   out: Q4.12, scaled by 1/64  ->  ref = FFT(x)/64
module tb_top_fft;

    localparam int    LATENCY = 3;      // s1_reg, s2_reg, y
    localparam int    TOL_LSB = 8;      // allowed |error| in LSB (truncation noise)
    localparam real   PI      = 3.14159265358979323846;

    logic clk;
    logic rst_n;
    complex [0:63] x;
    complex [0:63] y;

    fft_top dut (.clk(clk), .rst_n(rst_n), .x(x), .y(y));

    // ---------------- clock ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- real-valued views (for the waveform) ----------------
    real x_re_r [0:63], x_im_r [0:63];
    real y_re_r [0:63], y_im_r [0:63];
    real y_mag  [0:63];
    real ref_re [0:63], ref_im [0:63];

    always_comb
        for (int i = 0; i < 64; i++) begin
            x_re_r[i] = real'($signed(x[i].re)) / 4096.0;
            x_im_r[i] = real'($signed(x[i].im)) / 4096.0;
            y_re_r[i] = real'($signed(y[i].re)) / 4096.0;
            y_im_r[i] = real'($signed(y[i].im)) / 4096.0;
            y_mag [i] = $sqrt(y_re_r[i]*y_re_r[i] + y_im_r[i]*y_im_r[i]);
        end

    // ---------------- golden model: ideal DFT / 64, in LSB units ----------------
    task automatic compute_ref();
        real ar, ai, c, s, xr, xi;
        for (int k = 0; k < 64; k++) begin
            ar = 0.0; ai = 0.0;
            for (int n = 0; n < 64; n++) begin
                xr = real'($signed(x[n].re));
                xi = real'($signed(x[n].im));
                c  =  $cos(2.0*PI*n*k/64.0);
                s  = -$sin(2.0*PI*n*k/64.0);       // e^{-j2pi nk/N}
                ar += xr*c - xi*s;
                ai += xr*s + xi*c;
            end
            ref_re[k] = ar / 64.0;
            ref_im[k] = ai / 64.0;
        end
    endtask

    // ---------------- check ----------------
    int total_err = 0;
    int test_no   = 0;

    task automatic run_test(input string name);
        real er, ei, worst;
        int  bad;
        compute_ref();
        // x was driven on a negedge; output is valid after LATENCY posedges
        repeat (LATENCY) @(posedge clk);
        #1;
        worst = 0.0; bad = 0;
        for (int k = 0; k < 64; k++) begin
            er = real'($signed(y[k].re)) - ref_re[k];
            ei = real'($signed(y[k].im)) - ref_im[k];
            if (er < 0) er = -er;
            if (ei < 0) ei = -ei;
            if (er > worst) worst = er;
            if (ei > worst) worst = ei;
            if (er > TOL_LSB || ei > TOL_LSB) begin
                bad++;
                if (bad <= 5)
                    $display("  [%s] bin %0d: got (%0d,%0d)  exp (%.1f,%.1f)", name, k,
                             $signed(y[k].re), $signed(y[k].im), ref_re[k], ref_im[k]);
            end
        end
        test_no++;
        total_err += bad;
        $display("TEST %0d %-14s : %s  (max err = %.2f LSB, bad bins = %0d)",
                 test_no, name, (bad == 0) ? "PASS" : "FAIL", worst, bad);
    endtask

    task automatic drive_all(input shortint re, input shortint im);
        @(negedge clk);
        for (int i = 0; i < 64; i++) x[i] = '{re: re, im: im};
    endtask

    // ---------------- stimulus ----------------
    initial begin
        rst_n = 0;
        for (int i = 0; i < 64; i++) x[i] = '{re: 16'sd0, im: 16'sd0};
        repeat (4) @(posedge clk);
        @(negedge clk) rst_n = 1;

        // 1) DC: all ones (1.0) -> y[0] = 1.0 (4096), others 0
        drive_all(16'sd4096, 16'sd0);
        run_test("DC");

        // 2) Impulse at n=0 -> flat spectrum 1/64
        @(negedge clk);
        for (int i = 0; i < 64; i++) x[i] = '{re: 16'sd0, im: 16'sd0};
        x[0] = '{re: 16'sd4096, im: 16'sd0};
        run_test("IMPULSE_0");

        // 3) Delayed impulse at n=5 -> pure phase ramp (checks twiddle indexing)
        @(negedge clk);
        for (int i = 0; i < 64; i++) x[i] = '{re: 16'sd0, im: 16'sd0};
        x[5] = '{re: 16'sd4096, im: 16'sd0};
        run_test("IMPULSE_5");

        // 4) Complex tone, bin 7 -> single peak y[7] = A
        @(negedge clk);
        for (int i = 0; i < 64; i++)
            x[i] = '{re: shortint'($rtoi(3000.0*$cos(2.0*PI*7*i/64.0))),
                     im: shortint'($rtoi(3000.0*$sin(2.0*PI*7*i/64.0)))};
        run_test("TONE_7");

        // 5) Real cosine, bin 13 -> peaks at 13 and 51
        @(negedge clk);
        for (int i = 0; i < 64; i++)
            x[i] = '{re: shortint'($rtoi(3500.0*$cos(2.0*PI*13*i/64.0))), im: 16'sd0};
        run_test("COS_13");

        // 6) Random vectors (full amplitude +-0.9)
        for (int t = 0; t < 20; t++) begin
            @(negedge clk);
            for (int i = 0; i < 64; i++)
                x[i] = '{re: shortint'($urandom_range(7372, 0)) - 16'sd3686,
                         im: shortint'($urandom_range(7372, 0)) - 16'sd3686};
            run_test($sformatf("RANDOM_%0d", t));
        end

        $display("--------------------------------------------");
        if (total_err == 0) $display("ALL %0d TESTS PASSED", test_no);
        else                $display("FAILED: %0d bad bins over %0d tests", total_err, test_no);
        $finish;
    end

    // safety net
    initial begin
        #200000;
        $display("TIMEOUT");
        $finish;
    end

endmodule