//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP.v
//   Module Name : B2BCD_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module B2BCD_IP #(parameter WIDTH = 20, parameter DIGIT = 7) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Declaration
// ===============================================================
input  [WIDTH-1:0]   Binary_code;
output [DIGIT*4-1:0] BCD_code;
wire [DIGIT*4-1:0] bcd [WIDTH-1:0];
genvar i,j;
// ===============================================================
// Soft IP DESIGN
// ===============================================================
generate
for(i = 0; i < WIDTH-1  ; i = i + 1) begin
    for(j = 0; j < DIGIT ; j = j + 1) begin
        if(i==0) begin
            if(j==0)
                assign bcd[i][3:0] = {3'b000,Binary_code[WIDTH-1]};
            else
                assign bcd[i][j*4+3:j*4] = 4'b0000;
        end
        else begin
            if(j==0)
                assign bcd[i][3:0] = ({bcd[i-1][2:0],Binary_code[WIDTH-1-i]} > 4) ?
                                      {bcd[i-1][2:0],Binary_code[WIDTH-1-i]} + 4'd3 : {bcd[i-1][2:0],Binary_code[WIDTH-1-i]};
            else
                assign bcd[i][j*4+3:j*4] = (bcd[i-1][j*4+2:j*4-1] > 4) ?
                                            {bcd[i-1][j*4+2:j*4-1]} + 4'd3 : {bcd[i-1][j*4+2:j*4-1]};
        end
    end
end
endgenerate

assign BCD_code = (WIDTH==1)? Binary_code : {bcd[WIDTH-2][DIGIT*4-2:0],Binary_code[0]};

endmodule