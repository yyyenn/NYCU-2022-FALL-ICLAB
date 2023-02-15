module NN(
	// Input signals
	clk,
	rst_n,
	in_valid_u,
	in_valid_w,
	in_valid_v,
	in_valid_x,
	weight_u,
	weight_w,
	weight_v,
	data_x,
	// Output signals
	out_valid,
	out
);

//================================================================
//   PARAMETER
//================================================================

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

parameter s_idle = 1'b0;
parameter s_RNN = 1'b1;

//================================================================
//   INPUT AND OUTPUT DECLARATION
//================================================================
input  clk, rst_n, in_valid_u, in_valid_w, in_valid_v, in_valid_x;
input [inst_sig_width+inst_exp_width:0] weight_u, weight_w, weight_v;
input [inst_sig_width+inst_exp_width:0] data_x;
output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//================================================================
//   WIRE AND REG DECLARATION
//================================================================
reg c_state, n_state;
reg [5:0] counter;//31
//  input reg
reg [inst_sig_width+inst_exp_width:0] U[0:2][0:2];
reg [inst_sig_width+inst_exp_width:0] W[0:2][0:2];
reg [inst_sig_width+inst_exp_width:0] V[0:2][0:2];
reg [inst_sig_width+inst_exp_width:0] x1[0:2], x2[0:2], x3[0:2];
reg [inst_sig_width+inst_exp_width:0] h1[0:2], h2[0:2], h3[0:2];
reg [inst_sig_width+inst_exp_width:0] y1[0:2], y2[0:2], y3[0:2];
reg [inst_sig_width+inst_exp_width:0] Ux2[0:2],Ux3[0:2];

wire [7:0] status_inst;

//  Pipeline Stage 1.
reg  [inst_sig_width+inst_exp_width:0] data_in_r11;
reg  [inst_sig_width+inst_exp_width:0] data_in_r12;
reg  [inst_sig_width+inst_exp_width:0] data_in_r13;
wire [inst_sig_width+inst_exp_width:0] data_out_w1;

//  Pipeline Stage 2.
reg  [inst_sig_width+inst_exp_width:0] data_in_r21;
reg  [inst_sig_width+inst_exp_width:0] data_in_r22;
reg  [inst_sig_width+inst_exp_width:0] data_in_r23;
wire [inst_sig_width+inst_exp_width:0] data_out_w2;

//  Pipeline Stage 3.
reg  [inst_sig_width+inst_exp_width:0] data_in_r31;
reg  [inst_sig_width+inst_exp_width:0] data_in_r32;
reg  [inst_sig_width+inst_exp_width:0] data_in_r33;
wire [inst_sig_width+inst_exp_width:0] data_out_w3;

//  Pipeline Stage 4.
reg  [inst_sig_width+inst_exp_width:0] data_in_r4;
wire [inst_sig_width+inst_exp_width:0] data_out_w4;

//  Pipeline Stage 5.
reg  [inst_sig_width+inst_exp_width:0] data_in_r5;
wire [inst_sig_width+inst_exp_width:0] data_out_w5;

//  Pipeline Stage 6.
reg  [inst_sig_width+inst_exp_width:0] data_in_r6;
wire [inst_sig_width+inst_exp_width:0] data_out_w6;

//================================================================
//   ALGORITHM
//================================================================
/***********************************************************/
/*                         stage 1                         */
/***********************************************************/
// data_in_r11
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r11 <= 32'b0;
	else begin
		case(counter)
		0:  data_in_r11 <= weight_u;
		3:  data_in_r11 <= weight_u;
		4:  data_in_r11 <= U[0][0];
		5:  data_in_r11 <= U[1][0];
		6:  data_in_r11 <= weight_u;
		7:  data_in_r11 <= U[2][0];
		8:  data_in_r11 <= U[0][0];
		9:  data_in_r11 <= U[1][0];
		10: data_in_r11 <= U[2][0];

		11: data_in_r11 <= W[0][0];
		12: data_in_r11 <= W[1][0];
		13: data_in_r11 <= W[2][0];
		14: data_in_r11 <= V[0][0];
		15: data_in_r11 <= V[1][0];
		16: data_in_r11 <= V[2][0];

		17: data_in_r11 <= W[0][0];
		18: data_in_r11 <= W[1][0];
		19: data_in_r11 <= W[2][0];
		20: data_in_r11 <= V[0][0];
		21: data_in_r11 <= V[1][0];
		22: data_in_r11 <= V[2][0];

		23: data_in_r11 <= V[0][0];
		24: data_in_r11 <= V[1][0];
		25: data_in_r11 <= V[2][0];
		default: data_in_r11 <= 32'b0;
		endcase
	end
end
// data_in_r12
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r12 <= 32'b0;
	else begin
		if (counter == 0)  									  data_in_r12 <= data_x;
		else if(counter == 3 || counter == 6)        		  data_in_r12 <= x1[0];
		else if(counter == 4 || counter == 5 || counter == 7) data_in_r12 <= x2[0];
		else if(counter == 8 || counter == 9 || counter == 10)data_in_r12 <= x3[0];
		else if(counter >= 11 && counter <= 16) 			  data_in_r12 <= h1[0];
		else if(counter == 17)                                data_in_r12 <= data_out_w6;
		else if(counter >= 18 && counter <= 22) 			  data_in_r12 <= h2[0];
		else if(counter == 23)                                data_in_r12 <= data_out_w6;
		else if(counter == 24 || counter == 25)				  data_in_r12 <= h3[0];
		else data_in_r12 <= 32'b0;
	end
end
// data_in_r13
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r13 <= 32'b0;
	else begin //backward
		case(counter)
		11: data_in_r13 <= Ux2[0];
		12: data_in_r13 <= Ux2[1];
		13: data_in_r13 <= Ux2[2];

		17: data_in_r13 <= Ux3[0];
		18: data_in_r13 <= Ux3[1];
		19: data_in_r13 <= Ux3[2];

		default: data_in_r13 <= 32'b0;
		endcase
	end
end

fp_MULT_ADD mult_add_1(.inst_a(data_in_r11),
					   .inst_b(data_in_r12),
					   .inst_c(data_in_r13),
					   .z_inst(data_out_w1));

/***********************************************************/
/*                         stage 2                         */
/***********************************************************/
// data_in_r21
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r21 <= 32'b0;
	else begin
		case(counter)
		1:  data_in_r21 <= weight_u;
		4:  data_in_r21 <= weight_u;
		5:  data_in_r21 <= U[0][1];
		6:  data_in_r21 <= U[1][1];
		7:  data_in_r21 <= weight_u;
		8:  data_in_r21 <= U[2][1];
		9:  data_in_r21 <= U[0][1];
		10: data_in_r21 <= U[1][1];
		11: data_in_r21 <= U[2][1];

		12: data_in_r21 <= W[0][1];
		13: data_in_r21 <= W[1][1];
		14: data_in_r21 <= W[2][1];
		15: data_in_r21 <= V[0][1];
		16: data_in_r21 <= V[1][1];
		17: data_in_r21 <= V[2][1];

		18: data_in_r21 <= W[0][1];
		19: data_in_r21 <= W[1][1];
		20: data_in_r21 <= W[2][1];
		21: data_in_r21 <= V[0][1];
		22: data_in_r21 <= V[1][1];
		23: data_in_r21 <= V[2][1];

		24: data_in_r21 <= V[0][1];
		25: data_in_r21 <= V[1][1];
		26: data_in_r21 <= V[2][1];
		default:  data_in_r21 <= 32'b0;
		endcase
	end
end
// data_in_r22
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r22 <= 32'b0;
	else begin
		if(counter == 1)			 						   data_in_r22 <= data_x;
		else if(counter == 4 || counter == 7)        		   data_in_r22 <= x1[1];
		else if(counter == 5 || counter == 6 || counter == 8)  data_in_r22 <= x2[1];
		else if(counter == 9 || counter == 10 || counter == 11)data_in_r22 <= x3[1];
		else if(counter >= 12 && counter <= 17) 			   data_in_r22 <= h1[1];
		else if(counter == 18)  							   data_in_r22 <= data_out_w6;
		else if(counter >= 19 && counter <= 23) 			   data_in_r22 <= h2[1];
		else if(counter == 24)  							   data_in_r22 <= data_out_w6;
		else if(counter == 25 || counter == 26)				   data_in_r22 <= h3[1];
		else data_in_r22 <= 32'b0;
	end
end
// data_in_r23
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r23 <= 32'b0;
	else data_in_r23 <= data_out_w1;
end

fp_MULT_ADD mult_add_2(.inst_a(data_in_r21),
					   .inst_b(data_in_r22),
					   .inst_c(data_in_r23),
					   .z_inst(data_out_w2));

/***********************************************************/
/*                         stage 3                         */
/***********************************************************/
// data_in_r31
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r31 <= 32'b0;
	else begin
		case(counter)
		2:  data_in_r31 <= weight_u;
		5:  data_in_r31 <= weight_u;
		6:  data_in_r31 <= U[0][2];
		7:  data_in_r31 <= U[1][2];
		8:  data_in_r31 <= weight_u;
		9:  data_in_r31 <= U[2][2];
		10: data_in_r31 <= U[0][2];
		11: data_in_r31 <= U[1][2];
		12: data_in_r31 <= U[2][2];

		13: data_in_r31 <= W[0][2];
		14: data_in_r31 <= W[1][2];
		15: data_in_r31 <= W[2][2];
		16: data_in_r31 <= V[0][2];
		17: data_in_r31 <= V[1][2];
		18: data_in_r31 <= V[2][2];

		19: data_in_r31 <= W[0][2];
		20: data_in_r31 <= W[1][2];
		21: data_in_r31 <= W[2][2];
		22: data_in_r31 <= V[0][2];
		23: data_in_r31 <= V[1][2];
		24: data_in_r31 <= V[2][2];

		25: data_in_r31 <= V[0][2];
		26: data_in_r31 <= V[1][2];
		27: data_in_r31 <= V[2][2];
		default:  data_in_r31 <= 32'b0;
		endcase
	end
end
// data_in_r32
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r32 <= 32'b0;
	else begin
		if (counter == 2)	  								    data_in_r32 <= data_x;
		else if(counter == 5 || counter == 8)        		    data_in_r32 <= x1[2];
		else if(counter == 6 || counter == 7 || counter == 9)   data_in_r32 <= x2[2];
		else if(counter == 10 || counter == 11 || counter == 12)data_in_r32 <= x3[2];
		else if(counter >= 13 && counter <= 18) 			    data_in_r32 <= h1[2];
		else if(counter == 19)									data_in_r32 <= data_out_w6;
		else if(counter >= 20 && counter <= 24) 			    data_in_r32 <= h2[2];
		else if(counter == 25)									data_in_r32 <= data_out_w6;
		else if(counter == 26 || counter == 27)				    data_in_r32 <= h3[2];
		else data_in_r32 <= 32'b0;
	end
end
// data_in_r33
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r33 <= 32'b0;
	else data_in_r33 <= data_out_w2;
end

fp_MULT_ADD mult_add_3(.inst_a(data_in_r31),
					   .inst_b(data_in_r32),
					   .inst_c(data_in_r33),
					   .z_inst(data_out_w3));


/************** Ux REG  **************/
// Ux2
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		Ux2[0] <= 32'b0;
		Ux2[1] <= 32'b0;
		Ux2[2] <= 32'b0;
	end
	else begin
		if(counter==7)  Ux2[0] <= data_out_w3;
		if(counter==8)  Ux2[1] <= data_out_w3;
		if(counter==10)  Ux2[2] <= data_out_w3;
	end
end

// Ux3
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		Ux3[0] <= 32'b0;
		Ux3[1] <= 32'b0;
		Ux3[2] <= 32'b0;
	end
	else begin
		if(counter==11) Ux3[0] <= data_out_w3;
		if(counter==12) Ux3[1] <= data_out_w3;
		if(counter==13) Ux3[2] <= data_out_w3;
	end
end

/**************  y REG  **************/
// y1
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		y1[0] <= 32'b0;
		y1[1] <= 32'b0;
		y1[2] <= 32'b0;
	end
	else begin
		if(counter==17)begin
			if(data_out_w3[31] == 1'b1) y1[0] <= 32'b0;
			else y1[0] <= data_out_w3;
		end
		else if(counter==18)begin
			if(data_out_w3[31] == 1'b1) y1[1] <= 32'b0;
			else y1[1] <= data_out_w3;
		end
		else if(counter==19)begin
			if(data_out_w3[31] == 1'b1) y1[2] <= 32'b0;
			else y1[2] <= data_out_w3;
		end
	end
end

// y2
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		y2[0] <= 32'b0;
		y2[1] <= 32'b0;
		y2[2] <= 32'b0;
	end
	else begin
		if(data_out_w3[31] == 1'b1)begin
			y2[0] <= 32'b0;
			y2[1] <= 32'b0;
			y2[2] <= 32'b0;
		end
		else if(counter==23) y2[0] <= data_out_w3;
		else if(counter==24) y2[1] <= data_out_w3;
		else if(counter==25) y2[2] <= data_out_w3;
	end
end

// y3
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		y3[0] <= 32'b0;
		y3[1] <= 32'b0;
		y3[2] <= 32'b0;
	end
	else begin
		if(counter==26)begin
			if(data_out_w3[31] == 1'b1) y3[0] <= 32'b0;
			else y3[0] <= data_out_w3;
		end
		else if(counter==27)begin
			if(data_out_w3[31] == 1'b1) y3[1] <= 32'b0;
			else y3[1] <= data_out_w3;
		end
		else if(counter==28)begin
			if(data_out_w3[31] == 1'b1) y3[2] <= 32'b0;
			else y3[2] <= data_out_w3;
		end
	end
end
/***********************************************************/
/*                         stage 4                         */
/***********************************************************/
// data_in_r4
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r4 <= 32'b0;
	else begin
		if(data_out_w3[31]==1'b0)
			data_in_r4 <= {1'b1, data_out_w3[30:0]};
		else if(data_out_w3[31]==1'b1)
			data_in_r4 <= {1'b0, data_out_w3[30:0]};
	end
end

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
			exp(.a(data_in_r4),
				.z(data_out_w4),
				.status(status_inst));

/***********************************************************/
/*                         stage 5                         */
/***********************************************************/
// data_in_r5
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r5 <= 32'b0;
	else data_in_r5 <= data_out_w4;
end

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
			add1(.a(data_in_r5),
				 .b(32'b00111111100000000000000000000000),
				 .rnd(3'b0),
				 .z(data_out_w5),
				 .status(status_inst));

/***********************************************************/
/*                         stage 6                         */
/***********************************************************/
// data_in_r6
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) data_in_r6 <= 32'b0;
	else data_in_r6 <= data_out_w5;
end

DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,inst_faithful_round)
        	recip(.a(data_in_r6),
                  .rnd(3'b000),
                  .z(data_out_w6),
                  .status(status_inst));

/**************  h REG  **************/
// h1
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		h1[0] <= 32'b0;
		h1[1] <= 32'b0;
		h1[2] <= 32'b0;
	end
	else begin
		if(counter==6)  h1[0] <= data_out_w6;
		if(counter==9)  h1[1] <= data_out_w6;
		if(counter==12) h1[2] <= data_out_w6;
	end
end

// h2
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		h2[0] <= 32'b0;
		h2[1] <= 32'b0;
		h2[2] <= 32'b0;
	end
	else begin
		if(counter==17) h2[0] <= data_out_w6;
		if(counter==18) h2[1] <= data_out_w6;
		if(counter==19) h2[2] <= data_out_w6;
	end
end

// h3
always@(posedge clk or negedge rst_n)begin
	if(!rst_n) begin
		h3[0] <= 32'b0;
		h3[1] <= 32'b0;
		h3[2] <= 32'b0;
	end
	else begin
		if(counter==23) h3[0] <= data_out_w6;
		if(counter==24) h3[1] <= data_out_w6;
		if(counter==25) h3[2] <= data_out_w6;
	end
end

//================================================================
//   INPUT
//================================================================
// weight_u
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		U[0][0] <= 0;
		U[0][1] <= 0;
		U[0][2] <= 0;
		U[1][0] <= 0;
		U[1][1] <= 0;
		U[1][2] <= 0;
		U[2][0] <= 0;
		U[2][1] <= 0;
		U[2][2] <= 0;
	end
	else begin
		if(in_valid_u)begin
			case(counter)
			0: U[0][0] <= weight_u;
			1: U[0][1] <= weight_u;
			2: U[0][2] <= weight_u;
			3: U[1][0] <= weight_u;
			4: U[1][1] <= weight_u;
			5: U[1][2] <= weight_u;
			6: U[2][0] <= weight_u;
			7: U[2][1] <= weight_u;
			8: U[2][2] <= weight_u;
			endcase
		end
	end
end

// weight_w
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		W[0][0] <= 0;
		W[0][1] <= 0;
		W[0][2] <= 0;
		W[1][0] <= 0;
		W[1][1] <= 0;
		W[1][2] <= 0;
		W[2][0] <= 0;
		W[2][1] <= 0;
		W[2][2] <= 0;
	end
	else begin
		if(in_valid_w)begin
			case(counter)
			0: W[0][0] <= weight_w;
			1: W[0][1] <= weight_w;
			2: W[0][2] <= weight_w;
			3: W[1][0] <= weight_w;
			4: W[1][1] <= weight_w;
			5: W[1][2] <= weight_w;
			6: W[2][0] <= weight_w;
			7: W[2][1] <= weight_w;
			8: W[2][2] <= weight_w;
			endcase
		end
	end
end

// weight_v
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		V[0][0] <= 0;
		V[0][1] <= 0;
		V[0][2] <= 0;
		V[1][0] <= 0;
		V[1][1] <= 0;
		V[1][2] <= 0;
		V[2][0] <= 0;
		V[2][1] <= 0;
		V[2][2] <= 0;
	end
	else begin
		if(in_valid_v)begin
			case(counter)
			0: V[0][0] <= weight_v;
			1: V[0][1] <= weight_v;
			2: V[0][2] <= weight_v;
			3: V[1][0] <= weight_v;
			4: V[1][1] <= weight_v;
			5: V[1][2] <= weight_v;
			6: V[2][0] <= weight_v;
			7: V[2][1] <= weight_v;
			8: V[2][2] <= weight_v;
			endcase
		end
	end
end

// data_x
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		x1[0] <= 0;
		x1[1] <= 0;
		x1[2] <= 0;
		x2[0] <= 0;
		x2[1] <= 0;
		x2[2] <= 0;
		x3[0] <= 0;
		x3[1] <= 0;
		x3[2] <= 0;
	end
	else begin
		if(in_valid_x)begin
			case(counter)
			0: x1[0] <= data_x;
			1: x1[1] <= data_x;
			2: x1[2] <= data_x;
			3: x2[0] <= data_x;
			4: x2[1] <= data_x;
			5: x2[2] <= data_x;
			6: x3[0] <= data_x;
			7: x3[1] <= data_x;
			8: x3[2] <= data_x;
			endcase
		end
	end
end

//================================================================
//   OUTPUT
//================================================================
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		out_valid <= 0;
	else if(counter>=20 && counter<=28)
		out_valid <= 1;
	else
		out_valid <= 0;
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		out <= 32'b0;
	else begin
		if(counter==20) out <= y1[0];
		else if(counter==21) out <= y1[1];
		else if(counter==22) out <= y1[2];
		else if(counter>=23 && counter<=28) begin
			if(data_out_w3[31] == 1'b1) out <= 32'b0;
		 	else out <= data_out_w3;
		end
		else out <= 32'b0;
	end
end

//================================================================
//   FSM
//================================================================
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle: if(in_valid_u) n_state = s_RNN;
	        else 	       n_state = s_idle;
    s_RNN:  if(counter==28)n_state = s_idle;
            else           n_state = s_RNN;
	default: n_state = c_state;
  endcase
end

//================================================================
//   COUNTER
//================================================================
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		counter <= 0;
	else begin
		if(n_state == s_RNN)
			counter <= counter + 1;
		else
			counter <= 0;
	end
end
endmodule

//================================================================
//  SUBMODULE : DesignWare
//================================================================
module fp_MULT_ADD(inst_a, inst_b, inst_c, z_inst);
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;

input  [inst_sig_width+inst_exp_width:0] inst_a, inst_b, inst_c;
output [inst_sig_width+inst_exp_width:0] z_inst;

wire [inst_sig_width+inst_exp_width:0] temp_ab;
wire [7:0] status_inst;

DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
	U1( .a(inst_a),
		.b(inst_b),
		.rnd(3'b000),
		.z(temp_ab),
		.status(status_inst));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
	U2(	.a(temp_ab),
		.b(inst_c),
		.rnd(3'b000),
		.z(z_inst),
		.status(status_inst));
endmodule