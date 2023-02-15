module HD(
	code_word1,
	code_word2,
	out_n
);

input  [6:0]code_word1, code_word2;
output reg signed[5:0] out_n;

wire [2:0] s1,s2;
wire [1:0] op;
reg [3:0] c1,c2;

assign s1[2] = code_word1[6] ^ code_word1[3] ^ code_word1[2] ^ code_word1[1];
assign s1[1] = code_word1[5] ^ code_word1[3] ^ code_word1[2] ^ code_word1[0];
assign s1[0] = code_word1[4] ^ code_word1[3] ^ code_word1[1] ^ code_word1[0];

assign s2[2] = code_word2[6] ^ code_word2[3] ^ code_word2[2] ^ code_word2[1];
assign s2[1] = code_word2[5] ^ code_word2[3] ^ code_word2[2] ^ code_word2[0];
assign s2[0] = code_word2[4] ^ code_word2[3] ^ code_word2[1] ^ code_word2[0];

assign op[1] =  (s1 == 3'b100) ? code_word1[6]:
	 	(s1 == 3'b010) ? code_word1[5]:
	 	(s1 == 3'b001) ? code_word1[4]:
		(s1 == 3'b111) ? code_word1[3]:
	 	(s1 == 3'b110) ? code_word1[2]:
	 	(s1 == 3'b101) ? code_word1[1]:
		(s1 == 3'b011) ? code_word1[0]:
		0;

assign op[0] =  (s2 == 3'b100) ? code_word2[6]:
	 	(s2 == 3'b010) ? code_word2[5]:
	 	(s2 == 3'b001) ? code_word2[4]:
		(s2 == 3'b111) ? code_word2[3]:
	 	(s2 == 3'b110) ? code_word2[2]:
		(s2 == 3'b101) ? code_word2[1]:
		(s2 == 3'b011) ? code_word2[0]:
		0;

always@(*)
begin
	if(s1 == 3'b111)begin
		c1 = {~code_word1[3],code_word1[2:0]}; 
	end
	else if(s1 == 3'b110)begin
		c1 = {code_word1[3],~code_word1[2],code_word1[1:0]}; 
	end
	else if(s1 == 3'b101)begin
		c1 = {code_word1[3:2],~code_word1[1],code_word1[0]}; 
	end
	else if(s1 == 3'b011)begin
		c1 = {code_word1[3:1],~code_word1[0]}; 
	end
	else begin
		c1 = code_word1[3:0];
	end

	if(s2 == 3'b111)begin
		c2 = {~code_word2[3],code_word2[2:0]}; 
	end
	else if(s2 == 3'b110)begin
		c2 = {code_word2[3],~code_word2[2],code_word2[1:0]}; 
	end
	else if(s2 == 3'b101)begin
		c2 = {code_word2[3:2],~code_word2[1],code_word2[0]}; 
	end
	else if(s2 == 3'b011)begin
		c2 = {code_word2[3:1],~code_word2[0]}; 
	end
	else begin
		c2 = code_word2[3:0];
	end
	
	if(op==2'b00)begin
		out_n = 2*$signed(c1[3:0]) + $signed(c2[3:0]);
	end
	else if(op==2'b01)begin
		out_n = 2*$signed(c1[3:0]) - $signed(c2[3:0]);
	end
	else if(op==2'b10)begin
		out_n = $signed(c1[3:0]) - 2*$signed(c2[3:0]);
	end
	else if(op==2'b11)begin
		out_n = $signed(c1[3:0]) + 2*$signed(c2[3:0]);
	end
end
endmodule
