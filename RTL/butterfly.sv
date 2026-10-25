import complex_pack::*;

module butterfly
(
    input  complex [0:3] p,
    input  complex [0:3] twiddle,
    output complex [0:3] y
);
    complex [0:3] p_dash;
    complex [0:3] p_dash_reg;

// [1] Pre-multiply the input points with the twiddle factors
always_comb 
    for (int i = 0; i < 4; i++)
        p_dash[i] = c_mul(p[i], twiddle[i], 12, 14);

// [2] Radix-4 butterfly operation
always_comb
    for (int i = 0; i < 4; i++)
        begin
        y[i] = c_add4(c_mul_f4(p_dash[0], F4[0][i]),
                      c_mul_f4(p_dash[1], F4[1][i]),
                      c_mul_f4(p_dash[2], F4[2][i]),
                      c_mul_f4(p_dash[3], F4[3][i]));

// [3] Scaling by 4 each stage (4*4*4 = 64)
        // y[i].re = y[i].re >>> 2;
        // y[i].im = y[i].im >>> 2;                     
        end
    
endmodule