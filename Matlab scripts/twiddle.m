N = 64;
fid = fopen('twiddles_w64.mem', 'w');

for k = 0:(N-1)
    angle = -2 * pi * k / N;
    re_float = cos(angle);
    im_float = sin(angle);
    
    % Q2.14 scaling
    re_q = round(re_float * 16384);
    im_q = round(im_float * 16384);
    
    % Two's complement conversion for 16-bit signed integers
    re_16 = typecast(int16(re_q), 'uint16');
    im_16 = typecast(int16(im_q), 'uint16');
    
    % Combine: Upper 16 bits Re, Lower 16 bits Im
    combined = bitor(bitshift(uint32(re_16), 16), uint32(im_16));
    
    % Write hex line
    fprintf(fid, '%08X\n', combined);
end

fclose(fid);