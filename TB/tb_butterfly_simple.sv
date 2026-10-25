import complex_pack::*;

module tb_butterfly_rad4;

complex [3:0] p;
complex [3:0] twiddle;
complex [3:0] y;

butterfly_rad4 dut (
    .p(p),
    .twiddle(twiddle),
    .y(y)
);

initial 
begin
    for (int i = 0; i < 4; i++) 
        twiddle[i] = '{re: 16'h4000, im: 16'h0000};
        
    p[0] = '{re: 16'h1000, im: 16'h0000}; // 1.0
    p[1] = '{re: 16'h2000, im: 16'h0000}; // 2.0
    p[2] = '{re: 16'h3000, im: 16'h0000}; // 3.0
    p[3] = '{re: 16'h4000, im: 16'h0000}; // 4.0

    #10;
    #10;
    $finish;
end

endmodule