import complex_pack::*;

// 64-point radix-4 DIT FFT, 3 stages, in-place structure
//   input  : digit-reversed (base 4)
//   stage 1: butterflies on stride 1  (twiddle = 1)
//   stage 2: butterflies on stride 4  (twiddle W64^(4*m*k), k = 0..3)
//   stage 3: butterflies on stride 16 (twiddle W64^(m*k),   k = 0..15)
//   output : natural order, scaled by 1/64
module fft_top
(
    input  logic clk, rst_n,
    input  complex [0:63] x,
    output complex [0:63] y
);

complex twiddle_rom [0:63];
initial $readmemh("twiddles_w64.mem", twiddle_rom);

complex [0:63] x_shuffled;
complex [0:63] s1_out, s2_out, s3_out;
complex [0:63] s1_reg, s2_reg;

// Base-4 digit reversal: i = (d2 d1 d0) -> (d0 d1 d2)
always_comb
    for (int i = 0; i < 64; i++)  
        x_shuffled[i] = x[(i%4)*16 + ((i/4)%4)*4 + (i/16)];
        

always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        begin
        s1_reg <= '0;
        s2_reg <= '0;
        y      <= '0;
        end
    else
        begin
        s1_reg <= s1_out;
        s2_reg <= s2_out;
        y      <= s3_out;
        end

// ---------------- Stage 1: elements {4b, 4b+1, 4b+2, 4b+3} ----------------
generate
    for (genvar b = 0; b < 16; b++) begin : gen_bf1
        complex [0:3] bf_y;
        butterfly u_bf (
            .p       (x_shuffled[4*b +: 4]),
            .twiddle ('{C1, C1, C1, C1}),
            .y       (bf_y)
        );
        for (genvar m = 0; m < 4; m++) begin : gen_out
            assign s1_out[4*b + m] = bf_y[m];
        end
    end
endgenerate

// ---------------- Stage 2: elements {base + 4m}, base = (b/4)*16 + b%4 ----
generate
    for (genvar b = 0; b < 16; b++) begin : gen_bf2
        localparam int K    = b % 4;
        localparam int BASE = (b / 4) * 16 + K;
        complex [0:3] bf_y;
        butterfly u_bf (
            .p       ('{s1_reg[BASE], s1_reg[BASE+4], s1_reg[BASE+8], s1_reg[BASE+12]}),
            .twiddle ('{twiddle_rom[0],     twiddle_rom[4*1*K],
                        twiddle_rom[4*2*K], twiddle_rom[4*3*K]}),
            .y       (bf_y)
        );
        for (genvar m = 0; m < 4; m++) begin : gen_out
            assign s2_out[BASE + 4*m] = bf_y[m];
        end
    end
endgenerate

// ---------------- Stage 3: elements {k, k+16, k+32, k+48} ------------------
generate
    for (genvar k = 0; k < 16; k++) begin : gen_bf3
        complex [0:3] bf_y;
        butterfly u_bf (
            .p       ('{s2_reg[k], s2_reg[k+16], s2_reg[k+32], s2_reg[k+48]}),
            .twiddle ('{twiddle_rom[0],   twiddle_rom[1*k],
                        twiddle_rom[2*k], twiddle_rom[3*k]}),
            .y       (bf_y)
        );
        for (genvar m = 0; m < 4; m++) begin : gen_out
            assign s3_out[k + 16*m] = bf_y[m];
        end
    end
endgenerate

endmodule
