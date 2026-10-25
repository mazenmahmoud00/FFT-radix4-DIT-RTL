package complex_pack;

// Used in F4 matrix & multiplication function c_mul_f4
    typedef enum logic [1:0] { 
        C_1  = 2'b00, // +1
        C_J  = 2'b01, // +j
        C_N1 = 2'b10, // -1
        C_NJ = 2'b11  // -j
    } f4_sel_t;

// The 4x4 DFT Matrix (each row is used for one of the 4 butterfly points)
    const f4_sel_t F4 [0:3][0:3] = '{
    '{C_1,  C_1,   C_1,   C_1 },   // Row 0 (p0):  1,  1,  1,  1
    '{C_1,  C_NJ,  C_N1,  C_J },   // Row 1 (p1):  1, -j, -1,  j
    '{C_1,  C_N1,  C_1,   C_N1},   // Row 2 (p2):  1, -1,  1, -1
    '{C_1,  C_J,   C_N1,  C_NJ}    // Row 3 (p3):  1,  j, -1, -j
    };


/*******************************Q4.12********************************/                 
/********************************************************************/                 

/*****************************Structures*****************************/                 

// Custom data type for complex numbers with fixed-point representation (Q4.12)
    localparam WIDTH = 16;
    typedef struct packed {
        logic signed [WIDTH-1:0] re;
        logic signed [WIDTH-1:0] im;
    } complex;
    // Multiplication of 2 complex numbers results in a complex number where
    // the real (re) and imaginary (im) parts are up to (2 * WIDTH) bits wide
    typedef struct packed { 
        logic signed [2*WIDTH:0] re;
        logic signed [2*WIDTH:0] im;
    } complex_2Np1; 

/*****************************Functions*****************************/    

//Complex addition function
    function automatic complex c_add4 (complex a, complex b, complex c, complex d);
        c_add4.re = a.re + b.re + c.re + d.re;
        c_add4.im = a.im + b.im + c.im + d.im;
    endfunction

//Complex Multiplication with F4 function
function automatic complex c_mul_f4 (complex a, f4_sel_t b);
    unique case (b)
        C_1:  c_mul_f4 = a;
        C_J:  c_mul_f4 = '{re: -a.im, im:  a.re};
        C_N1: c_mul_f4 = '{re: -a.re, im: -a.im};
        C_NJ: c_mul_f4 = '{re:  a.im, im: -a.re};
    endcase
endfunction

//Complex Multiplication function
    function automatic complex c_mul (complex a, complex b,int FRAC1=12 ,int FRAC2=12);
        complex_2Np1 result;
        int SHIFT;
        result.re = a.re * b.re - a.im * b.im;
        result.im = a.re * b.im + a.im * b.re;
        SHIFT = (FRAC1 + FRAC2) - 12;//12 is the required fractional bits for the result
        c_mul.re = result.re >>> SHIFT;
        c_mul.im = result.im >>> SHIFT;
    endfunction


/*******************************Q2.14********************************/
/********************************************************************/   
                  
//Q2.14 representation for twiddle factors
localparam complex  C1 = 32'h4000_0000; // +1.0

endpackage

