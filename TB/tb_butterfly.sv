`timescale 1ns / 1ps
import complex_pack::*;

module tb();

    // Tolerance: truncation in c_mul (>>>) gives up to ~1 LSB per term, 4 terms
    localparam real LSB_OUT = 1.0 / 4096.0;   // Q4.12
    localparam real TOL     = 6.0 * LSB_OUT;
    localparam real PI      = 3.14159265358979;

    complex [3:0] p, twiddle, y;

    butterfly_rad4 uut (.*);

    int errors = 0;
    int tests  = 0;

    // Test vector storage (real values)
    real g_pr[4], g_pi[4], g_tr[4], g_ti[4];

    // Quantized values (what the DUT actually sees) and expected outputs
    real q_pr[4], q_pi[4], q_tr[4], q_ti[4];
    real exp_r[4], exp_i[4];

    /************** Helpers **************/
    function automatic real absr (real v);
        return (v < 0.0) ? -v : v;
    endfunction

    // real -> Q4.12
    function automatic logic signed [15:0] to_q12 (real v);
        return 16'($rtoi(v * 4096.0 + ((v >= 0.0) ? 0.5 : -0.5)));
    endfunction

    // real -> Q2.14
    function automatic logic signed [15:0] to_q14 (real v);
        return 16'($rtoi(v * 16384.0 + ((v >= 0.0) ? 0.5 : -0.5)));
    endfunction

    function automatic real from_q12 (logic signed [15:0] v);
        return $itor(v) / 4096.0;
    endfunction

    function automatic real from_q14 (logic signed [15:0] v);
        return $itor(v) / 16384.0;
    endfunction

    /************** Golden model (forward DFT-4, W = -j) **************/
    task automatic golden;
        real ar[4], ai[4];
        int  m;
        begin
            for (int n = 0; n < 4; n++) begin      // p' = p * twiddle
                ar[n] = q_pr[n]*q_tr[n] - q_pi[n]*q_ti[n];
                ai[n] = q_pr[n]*q_ti[n] + q_pi[n]*q_tr[n];
            end
            for (int k = 0; k < 4; k++) begin
                exp_r[k] = 0.0;
                exp_i[k] = 0.0;
                for (int n = 0; n < 4; n++) begin
                    m = (n*k) % 4;                  // (-j)^(n*k)
                    case (m)
                        0: begin exp_r[k] += ar[n];  exp_i[k] += ai[n];  end
                        1: begin exp_r[k] += ai[n];  exp_i[k] += -ar[n]; end  // *(-j)
                        2: begin exp_r[k] += -ar[n]; exp_i[k] += -ai[n]; end  // *(-1)
                        3: begin exp_r[k] += -ai[n]; exp_i[k] += ar[n];  end  // *(+j)
                    endcase
                end
            end
        end
    endtask

    /************** Apply current vector and check **************/
    task automatic run_test (input string name);
        real got_r, got_i;
        bit  fail;
        begin
            fail = 0;

            // Drive DUT + save the quantized values for the golden model
            for (int i = 0; i < 4; i++) begin
                p[i].re       = to_q12(g_pr[i]);
                p[i].im       = to_q12(g_pi[i]);
                twiddle[i].re = to_q14(g_tr[i]);
                twiddle[i].im = to_q14(g_ti[i]);

                q_pr[i] = from_q12(p[i].re);
                q_pi[i] = from_q12(p[i].im);
                q_tr[i] = from_q14(twiddle[i].re);
                q_ti[i] = from_q14(twiddle[i].im);
            end
            #10;

            golden();

            for (int k = 0; k < 4; k++) begin
                got_r = from_q12(y[k].re);
                got_i = from_q12(y[k].im);
                if (absr(got_r - exp_r[k]) > TOL || absr(got_i - exp_i[k]) > TOL) begin
                    fail = 1;
                    $display("  [%s] y[%0d] MISMATCH: got (%f, %f)  exp (%f, %f)",
                             name, k, got_r, got_i, exp_r[k], exp_i[k]);
                end
            end

            tests++;
            if (fail) errors++;
            else      $display("PASS: %s", name);
        end
    endtask

    /************** Test vectors **************/
    real ang;

    initial begin
        // Test 1: twiddle = 1, real inputs
        g_pr = '{0.5, 1.0, 1.5, 1.0};   g_pi = '{0.0, 0.0, 0.0, 0.0};
        g_tr = '{1.0, 1.0, 1.0, 1.0};   g_ti = '{0.0, 0.0, 0.0, 0.0};
        run_test("tw=1, real in");

        // Test 2: complex inputs, twiddle = 1
        g_pr = '{0.5, -0.25, 1.0, 0.75};  g_pi = '{0.25, 0.5, -0.5, 1.0};
        g_tr = '{1.0, 1.0, 1.0, 1.0};     g_ti = '{0.0, 0.0, 0.0, 0.0};
        run_test("tw=1, complex in");

        // Test 3: twiddles = 1, -j, +j, -1
        g_pr = '{1.0, 0.5, 0.5, 0.25};    g_pi = '{0.0, 0.5, -0.5, 0.0};
        g_tr = '{1.0, 0.0, 0.0, -1.0};    g_ti = '{0.0, -1.0, 1.0, 0.0};
        run_test("tw = 1, -j, j, -1");

        // Test 4: FFT-16 twiddles W16^i
        g_pr = '{1.0, 0.5, -0.5, 0.25};   g_pi = '{0.0, 0.25, 0.5, -0.75};
        for (int i = 0; i < 4; i++) begin
            g_tr[i] =  $cos(2.0 * PI * i / 16.0);
            g_ti[i] = -$sin(2.0 * PI * i / 16.0);
        end
        run_test("W16 twiddles");

        // Test 5: random vectors (|re|,|im| <= 1.0 so the sum stays < 8)
        for (int t = 0; t < 50; t++) begin
            for (int i = 0; i < 4; i++) begin
                g_pr[i] = (int'($urandom_range(0, 2000)) - 1000) / 1000.0;
                g_pi[i] = (int'($urandom_range(0, 2000)) - 1000) / 1000.0;
                ang     = 2.0 * PI * int'($urandom_range(0, 255)) / 256.0;
                g_tr[i] =  $cos(ang);
                g_ti[i] = -$sin(ang);
            end
            run_test($sformatf("random %0d", t));
        end

        $display("=========================================");
        $display(" Tests: %0d   Failed: %0d", tests, errors);
        $display("=========================================");
        $finish;
    end

endmodule