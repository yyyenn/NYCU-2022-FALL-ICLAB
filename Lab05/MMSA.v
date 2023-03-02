//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW02_mult.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW01_add.v"
//synopsys translate_on

module MMSA(
// input signals
    clk,
    rst_n,
    in_valid,
	in_valid2,
    matrix,
	matrix_size,
    i_mat_idx,
    w_mat_idx,

// output signals
    out_valid,
    out_value
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input        clk, rst_n, in_valid, in_valid2;
input [15:0] matrix;
input [1:0]  matrix_size;
input [3:0]  i_mat_idx, w_mat_idx;

output reg       	     out_valid;
output reg signed [39:0] out_value;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
/* FSM */
parameter s_idle   = 0;
parameter s_input  = 1;
parameter s_choose = 2;
parameter s_cal_2  = 3;
parameter s_cal_4  = 4;
parameter s_cal_8  = 5;
parameter s_cal_16 = 6;
parameter s_output = 7;

parameter mult_A_width = 16;
parameter mult_B_width = 16;
parameter add_width = 40;

genvar i,j;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [2:0]  c_state, n_state;
reg [4:0]  size;          // max 16
reg [5:0]  counter_row;   // max 16 row
reg [5:0]  counter_col;   // max 16 col
reg [12:0] counter_cal;   // max 4096 input
reg [8:0]  counter_out;   // max 256
reg [4:0]  counter_round;   // max 256

//============= cal reg =============//
reg  [39:0] diagonal_reg [30:0];  //31 diagonal, max 16*16
reg  [11:0] X_idx, W_idx;
reg  [15:0] w_reg [15:0]; // max 16
reg  [15:0] x_reg [15:0]; // max 16

reg  [39:0] y_reg    [15:0]; // max 16
wire [31:0] y_wire   [15:0]; // max 16

/* For first and second 16-adder */
wire [39:0] A_wire [14:0]; // max 16
wire [39:0] B_wire [13:0]; // max 15

reg  [39:0] Y1_reg;
reg  [39:0] Y2_reg;
reg  [39:0] current_diagonal_reg1, current_diagonal_reg2;
wire [39:0] update_diagonal_wire1, update_diagonal_wire2;

//=========== Adder & Mult ==========//
reg  [mult_A_width-1 : 0] mult_X_r [15:0];
reg  [mult_B_width-1 : 0] mult_W_r [15:0];
wire [mult_A_width+mult_B_width-1 : 0] product_w[15:0];

//==== SRAM in/out port control =====//
reg [11:0]  addr_X;
reg [11:0]  addr_W;

reg [15:0] 	in_mem_X;
reg [15:0] 	in_mem_W;

wire [15:0] mem_out_X;
wire [15:0] mem_out_W;

reg cen;
reg wen_X;
reg wen_W;
reg oen;

//---------------------------------------------------------------------
//   INPUT
//---------------------------------------------------------------------
// size
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) size <= 5'd0 ;
	else begin
        //give matrix size in first input cycle
		if (n_state == s_input && counter_cal == 0) begin
            case(matrix_size)
                2'b00: size <=  5'd2;
			    2'b01: size <=  5'd4;
			    2'b10: size <=  5'd8;
			    2'b11: size <=  5'd16;
			endcase
		end
	end
end
// X matrix index
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) X_idx <= 3'd0 ;
	else begin
        //give matrix size in first input cycle
		if (n_state == s_choose) begin
            X_idx <= i_mat_idx;
		end
	end
end
// W matrix index
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) W_idx <= 3'd0 ;
	else begin
        //give matrix size in first input cycle
		if (n_state == s_choose) begin
            W_idx <= w_mat_idx;
		end
	end
end
// cen/oen
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cen <= 0;
		oen <= 0;
	end
	else begin
        cen <= 0;
		oen <= 0;
	end
end
// wen_X
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_X <= 1; // read
	end
	else begin
        case(n_state)
			s_input: if(counter_cal<4096)wen_X <= 0; // write
					 else wen_X <= 1;
			default: wen_X <= 1; // read
		endcase
	end
end
// wen_W
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_W <= 1; // read
	end
	else begin
        case(n_state)
			s_input: wen_W <= 0; // write
			default: wen_W <= 1; // read
		endcase
	end
end
//============================//
//       SRAM Address         //
//============================//
// addr_X
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) addr_X <= 0;
	else begin
        case(n_state)
			s_input:  addr_X <= counter_cal;
			s_cal_2:  begin
				if(counter_cal < 1) addr_X <= (X_idx << 2);
				else begin
					case(counter_row-1)
					0: addr_X <= addr_X + 2;
					1: addr_X <= (X_idx << 2) + counter_col;
					endcase
				end
			end
			s_cal_4:  begin
				if(counter_cal < 1) addr_X <= (X_idx << 4);
				else begin
					case(counter_row-1)
					0: addr_X <= addr_X + 4;
					1: addr_X <= addr_X + 4;
					2: addr_X <= addr_X + 4;
					3: addr_X <= (X_idx << 4) + counter_col;
					endcase
				end
			end
			s_cal_8: begin
				if(counter_cal < 1) addr_X <= (X_idx << 6);
				else begin
					case(counter_row-1)
					0: addr_X <= addr_X + 8;
					1: addr_X <= addr_X + 8;
					2: addr_X <= addr_X + 8;
					3: addr_X <= addr_X + 8;
					4: addr_X <= addr_X + 8;
					5: addr_X <= addr_X + 8;
					6: addr_X <= addr_X + 8;
					7: addr_X <= (X_idx << 6) + counter_col;
					endcase
				end
			end
			s_cal_16:  begin
				if(counter_cal < 1) addr_X <= (X_idx << 8);
				else begin
					case(counter_row-1)
					0:  addr_X <= addr_X + 16;
					1:  addr_X <= addr_X + 16;
					2:  addr_X <= addr_X + 16;
					3:  addr_X <= addr_X + 16;
					4:  addr_X <= addr_X + 16;
					5:  addr_X <= addr_X + 16;
					6:  addr_X <= addr_X + 16;
					7:  addr_X <= addr_X + 16;
					8:  addr_X <= addr_X + 16;
					9:  addr_X <= addr_X + 16;
					10: addr_X <= addr_X + 16;
					11: addr_X <= addr_X + 16;
					12: addr_X <= addr_X + 16;
					13: addr_X <= addr_X + 16;
					14: addr_X <= addr_X + 16;
					15: addr_X <= (X_idx << 8) + counter_col;
					endcase
				end
			end
			s_output: addr_X <= counter_cal;
		endcase
	end
end
// addr_W
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) addr_W <= 0;
	else begin
        case(n_state)
			s_input: begin
        		if(counter_cal == 0) addr_W <= 0;
				else begin
					case(size)
						2: if(counter_cal >= 64)   addr_W <= counter_cal[5:0];
						4: if(counter_cal >= 256)  addr_W <= counter_cal[7:0];
						8: if(counter_cal >= 1024) addr_W <= counter_cal[9:0];
						16:if(counter_cal >= 4096) addr_W <= counter_cal[11:0];
						default addr_W <= 0;
					endcase
				end
			end
			s_cal_2:  addr_W <= (W_idx << 2) + counter_cal;
			s_cal_4:  addr_W <= (W_idx << 4) + counter_cal;
			s_cal_8:  addr_W <= (W_idx << 6) + counter_cal;
			s_cal_16: addr_W <= (W_idx << 8) + counter_cal;
			s_output: addr_W <= counter_cal;
		endcase
	end
end
//============================//
//          SRAM Read         //
//============================//
// X read
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)  in_mem_X <= 16'd0 ;
	else begin
		if (n_state == s_input) begin
            if(counter_cal == 0) in_mem_X <= matrix;
			else begin
				case(size)
					2: if(counter_cal < 64)   in_mem_X <= matrix;
					4: if(counter_cal < 256)  in_mem_X <= matrix;
					8: if(counter_cal < 1024) in_mem_X <= matrix;
					16:if(counter_cal < 4096) in_mem_X <= matrix;
					default in_mem_X <= 16'd0;
				endcase
			end
		end
	end
end
// W read
always @(posedge clk or negedge rst_n) begin
	if (!rst_n)  in_mem_W <= 16'd0 ;
	else begin
		if (n_state == s_input) begin
            if(counter_cal == 1) in_mem_W <= 16'd0;
			else begin
				case(size)
					2: if(counter_cal >= 64)   in_mem_W <= matrix;
					4: if(counter_cal >= 256)  in_mem_W <= matrix;
					8: if(counter_cal >= 1024) in_mem_W <= matrix;
					16:if(counter_cal >= 4096) in_mem_W <= matrix;
					default in_mem_W <= 16'd0;
				endcase
			end
		end
	end
end
//============================//
//    SRAM and reg control    //
//============================//
// X_reg[0]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[0] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
	        s_cal_2:  x_reg[0] <= mem_out_X;
			s_cal_4:  x_reg[0] <= mem_out_X;
			s_cal_8:  x_reg[0] <= mem_out_X;
			s_cal_16: x_reg[0] <= mem_out_X;
			default:  x_reg[0] <= 16'd0;
		endcase
		end
	end
end
// X_reg[1]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[1] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
	        s_cal_2:  x_reg[1] <= x_reg[0];
			s_cal_4:  x_reg[1] <= x_reg[0];
			s_cal_8:  x_reg[1] <= x_reg[0];
			s_cal_16: x_reg[1] <= x_reg[0];
			default:  x_reg[1] <= 16'd0;
		endcase
		end
	end
end
// X_reg[2]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[2] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_4:  x_reg[2] <= x_reg[1];
			s_cal_8:  x_reg[2] <= x_reg[1];
			s_cal_16: x_reg[2] <= x_reg[1];
			default:  x_reg[2] <= 16'd0;
		endcase
		end
	end
end
// X_reg[3]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[3] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_4:  x_reg[3] <= x_reg[2];
			s_cal_8:  x_reg[3] <= x_reg[2];
			s_cal_16: x_reg[3] <= x_reg[2];
			default:  x_reg[3] <= 16'd0;
		endcase
		end
	end
end
// X_reg[4]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[4] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_8:  x_reg[4] <= x_reg[3];
			s_cal_16: x_reg[4] <= x_reg[3];
			default:  x_reg[4] <= 16'd0;
		endcase
		end
	end
end
// X_reg[5]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[5] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_8:  x_reg[5] <= x_reg[4];
			s_cal_16: x_reg[5] <= x_reg[4];
			default:  x_reg[5] <= 16'd0;
		endcase
		end
	end
end
// X_reg[6]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[6] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_8:  x_reg[6] <= x_reg[5];
			s_cal_16: x_reg[6] <= x_reg[5];
			default:  x_reg[6] <= 16'd0;
		endcase
		end
	end
end
// X_reg[7]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[7] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_8:  x_reg[7] <= x_reg[6];
			s_cal_16: x_reg[7] <= x_reg[6];
			default:  x_reg[7] <= 16'd0;
		endcase
		end
	end
end
// X_reg[8]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[8] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[8] <= x_reg[7];
			default:  x_reg[8] <= 16'd0;
		endcase
		end
	end
end
// X_reg[9]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[9] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[9] <= x_reg[8];
			default:  x_reg[9] <= 16'd0;
		endcase
		end
	end
end
// X_reg[10]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[10] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[10] <= x_reg[9];
			default:  x_reg[10] <= 16'd0;
		endcase
		end
	end
end
// X_reg[11]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[11] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[11] <= x_reg[10];
			default:  x_reg[11] <= 16'd0;
		endcase
		end
	end
end
// X_reg[12]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[12] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[12] <= x_reg[11];
			default:  x_reg[12] <= 16'd0;
		endcase
		end
	end
end
// X_reg[13]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[13] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[13] <= x_reg[12];
			default:  x_reg[13] <= 16'd0;
		endcase
		end
	end
end
// X_reg[14]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[14] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[14] <= x_reg[13];
			default:  x_reg[14] <= 16'd0;
		endcase
		end
	end
end
// X_reg[15]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[15] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
		case(n_state)
			s_cal_16: x_reg[15] <= x_reg[14];
			default:  x_reg[15] <= 16'd0;
		endcase
		end
	end
end

// W Write
generate
for(i=0 ; i<16 ; i=i+1) begin
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) w_reg[i] <= 16'd0;
		else begin
			if(counter_cal > 1) begin // Wait SRAM output delay
			case(n_state)
	            s_cal_2: if((counter_cal-2) % 2  == i) w_reg[i%2] <= mem_out_W;
				s_cal_4: if((counter_cal-2) % 4  == i) w_reg[i%4] <= mem_out_W;
				s_cal_8: if((counter_cal-2) % 8  == i) w_reg[i%8] <= mem_out_W;
				s_cal_16:if((counter_cal-2) % 16 == i) w_reg[i]   <= mem_out_W;
				default w_reg[i] <= 16'd0;
			endcase
			end
		end
	end
end
endgenerate
//---------------------------------------------------------------------
//   Calculate
//---------------------------------------------------------------------
generate
for(i=0 ; i<16 ; i=i+1) begin
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) y_reg[i] <= 40'd0;
		else begin
			case(n_state)
	            s_cal_2: if(y_wire[i][31] == 1'b0) y_reg[i] <= {{8{1'b0}},y_wire[i]};
						 else y_reg[i] <= {{8{1'b1}},y_wire[i]};
				s_cal_4: if(y_wire[i][31] == 1'b0) y_reg[i] <= {{8{1'b0}},y_wire[i]};
						 else y_reg[i] <= {{8{1'b1}},y_wire[i]};
				s_cal_8: if(y_wire[i][31] == 1'b0) y_reg[i] <= {{8{1'b0}},y_wire[i]};
						 else y_reg[i] <= {{8{1'b1}},y_wire[i]};
				s_cal_16:if(y_wire[i][31] == 1'b0) y_reg[i] <= {{8{1'b0}},y_wire[i]};
						 else y_reg[i] <= {{8{1'b1}},y_wire[i]};
				default: y_reg[i] <= 40'd0;
			endcase
		end
	end
end
endgenerate
//============================//
//     upper-left diagonal    //
//============================//
// A: Y1_reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) Y1_reg <= 40'd0;
	else begin
		if(counter_cal > 3) begin // Wait SRAM output and 1-level adder delay
			case(n_state)
			s_cal_2:begin
				case((counter_cal - 4) % 2)
				0: Y1_reg <= y_reg[0];
				1: Y1_reg <= A_wire[0];
				default: Y1_reg <= 0;
				endcase
			end
			s_cal_4:
				case((counter_cal - 4) % 4)
				0: Y1_reg <= y_reg[0];
				1: Y1_reg <= A_wire[0];
				2: Y1_reg <= A_wire[1];
				3: Y1_reg <= A_wire[2];
				default: Y1_reg <= 0;
				endcase
			s_cal_8:
				case((counter_cal - 4) % 8)
				0: Y1_reg <= y_reg[0];
				1: Y1_reg <= A_wire[0];
				2: Y1_reg <= A_wire[1];
				3: Y1_reg <= A_wire[2];
				4: Y1_reg <= A_wire[3];
				5: Y1_reg <= A_wire[4];
				6: Y1_reg <= A_wire[5];
				7: Y1_reg <= A_wire[6];
				default: Y1_reg <= 0;
				endcase
			s_cal_16:
				case((counter_cal -4) % 16)
				0:  Y1_reg <= y_reg[0];
				1:  Y1_reg <= A_wire[0];
				2:  Y1_reg <= A_wire[1];
				3:  Y1_reg <= A_wire[2];
				4:  Y1_reg <= A_wire[3];
				5:  Y1_reg <= A_wire[4];
				6:  Y1_reg <= A_wire[5];
				7:  Y1_reg <= A_wire[6];
				8:  Y1_reg <= A_wire[7];
				9:  Y1_reg <= A_wire[8];
				10: Y1_reg <= A_wire[9];
				11: Y1_reg <= A_wire[10];
				12: Y1_reg <= A_wire[11];
				13: Y1_reg <= A_wire[12];
				14: Y1_reg <= A_wire[13];
				15: Y1_reg <= A_wire[14];
				default: Y1_reg <= 0;
				endcase
			default:Y1_reg <= 0;
			endcase
		end
	end
end
// B: current_diagonal_reg1
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) current_diagonal_reg1 <= 40'd0;
	else begin
		if(counter_cal > 3) begin // Wait SRAM output and 1-level adder delay
		case(n_state)
			s_cal_2:begin
				case((counter_cal - 4) % 2)
				0: current_diagonal_reg1 <= diagonal_reg[0];
				1: current_diagonal_reg1 <= diagonal_reg[1];
				endcase
			end
			s_cal_4:begin
				case((counter_cal - 4) % 4)
				0: current_diagonal_reg1 <= diagonal_reg[0];
				1: current_diagonal_reg1 <= diagonal_reg[1];
				2: current_diagonal_reg1 <= diagonal_reg[2];
				3: current_diagonal_reg1 <= diagonal_reg[3];
				endcase
			end
			s_cal_8:begin
				case((counter_cal - 4) % 8)
				0: current_diagonal_reg1 <= diagonal_reg[0];
				1: current_diagonal_reg1 <= diagonal_reg[1];
				2: current_diagonal_reg1 <= diagonal_reg[2];
				3: current_diagonal_reg1 <= diagonal_reg[3];
				4: current_diagonal_reg1 <= diagonal_reg[4];
				5: current_diagonal_reg1 <= diagonal_reg[5];
				6: current_diagonal_reg1 <= diagonal_reg[6];
				7: current_diagonal_reg1 <= diagonal_reg[7];
				endcase
			end
			s_cal_16:begin
				case((counter_cal - 4) % 16)
				0:  current_diagonal_reg1 <= diagonal_reg[0];
				1:  current_diagonal_reg1 <= diagonal_reg[1];
				2:  current_diagonal_reg1 <= diagonal_reg[2];
				3:  current_diagonal_reg1 <= diagonal_reg[3];
				4:  current_diagonal_reg1 <= diagonal_reg[4];
				5:  current_diagonal_reg1 <= diagonal_reg[5];
				6:  current_diagonal_reg1 <= diagonal_reg[6];
				7:  current_diagonal_reg1 <= diagonal_reg[7];
				8:  current_diagonal_reg1 <= diagonal_reg[8];
				9:  current_diagonal_reg1 <= diagonal_reg[9];
				10: current_diagonal_reg1 <= diagonal_reg[10];
				11: current_diagonal_reg1 <= diagonal_reg[11];
				12: current_diagonal_reg1 <= diagonal_reg[12];
				13: current_diagonal_reg1 <= diagonal_reg[13];
				14: current_diagonal_reg1 <= diagonal_reg[14];
				15: current_diagonal_reg1 <= diagonal_reg[15];
				endcase
			end
			default:current_diagonal_reg1 <= 40'b0;
		endcase
		end
	end
end
//============================//
//    lower-right diagonal    //
//============================//
// A: Y2_reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) Y2_reg <= 40'd0;
	else begin
		if(counter_cal > 3) begin // Wait SRAM output and 1-level adder delay
		case(n_state)
			s_cal_2:begin
				case((counter_cal - 4) % 2)
				0: Y2_reg <= y_reg[1];
				default: Y2_reg <= 0;
				endcase
			end
			s_cal_4:begin
				case((counter_cal - 4) % 4)
				0: Y2_reg <= B_wire[0];
				1: Y2_reg <= B_wire[1];
				2: Y2_reg <= y_reg[3];
				default: Y2_reg <= 0;
				endcase
			end
			s_cal_8:begin
				case((counter_cal - 4) % 8)
				0: Y2_reg <= B_wire[0];
				1: Y2_reg <= B_wire[1];
				2: Y2_reg <= B_wire[2];
				3: Y2_reg <= B_wire[3];
				4: Y2_reg <= B_wire[4];
				5: Y2_reg <= B_wire[5];
				6: Y2_reg <= y_reg[7];
				default: Y2_reg <= 0;
				endcase
			end
			s_cal_16: begin
				case((counter_cal - 4) % 16)
				0:  Y2_reg <= B_wire[0];
				1:  Y2_reg <= B_wire[1];
				2:  Y2_reg <= B_wire[2];
				3:  Y2_reg <= B_wire[3];
				4:  Y2_reg <= B_wire[4];
				5:  Y2_reg <= B_wire[5];
				6:  Y2_reg <= B_wire[6];
				7:  Y2_reg <= B_wire[7];
				8:  Y2_reg <= B_wire[8];
				9:  Y2_reg <= B_wire[9];
				10: Y2_reg <= B_wire[10];
				11: Y2_reg <= B_wire[11];
				12: Y2_reg <= B_wire[12];
				13: Y2_reg <= B_wire[13];
				14: Y2_reg <= y_reg[15];
				default: Y2_reg <= 0;
				endcase
			end
		default: Y2_reg <= 40'b0;
		endcase
		end
	end
end

// B: current_diagonal_reg2
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) current_diagonal_reg2 <= 40'd0;
	else begin
		if(counter_cal > 3) begin // Wait SRAM output and 1-level adder delay
		case(n_state)
			s_cal_2:begin
				case((counter_cal - 4) % 2)
				0: current_diagonal_reg2 <= diagonal_reg[2];
				default: current_diagonal_reg2 <= 0;
				endcase
			end
			s_cal_4:begin
				case((counter_cal - 4) % 4)
				0: current_diagonal_reg2 <= diagonal_reg[4];
				1: current_diagonal_reg2 <= diagonal_reg[5];
				2: current_diagonal_reg2 <= diagonal_reg[6];
				default: current_diagonal_reg2 <= 0;
				endcase
			end
			s_cal_8:begin
				case((counter_cal - 4) % 8)
				0: current_diagonal_reg2 <= diagonal_reg[8];
				1: current_diagonal_reg2 <= diagonal_reg[9];
				2: current_diagonal_reg2 <= diagonal_reg[10];
				3: current_diagonal_reg2 <= diagonal_reg[11];
				4: current_diagonal_reg2 <= diagonal_reg[12];
				5: current_diagonal_reg2 <= diagonal_reg[13];
				6: current_diagonal_reg2 <= diagonal_reg[14];
				default: current_diagonal_reg2 <= 0;
				endcase
			end
			s_cal_16:begin
				case((counter_cal - 4) % 16)
				0:  current_diagonal_reg2 <= diagonal_reg[16];
				1:  current_diagonal_reg2 <= diagonal_reg[17];
				2:  current_diagonal_reg2 <= diagonal_reg[18];
				3:  current_diagonal_reg2 <= diagonal_reg[19];
				4:  current_diagonal_reg2 <= diagonal_reg[20];
				5:  current_diagonal_reg2 <= diagonal_reg[21];
				6:  current_diagonal_reg2 <= diagonal_reg[22];
				7:  current_diagonal_reg2 <= diagonal_reg[23];
				8:  current_diagonal_reg2 <= diagonal_reg[24];
				9:  current_diagonal_reg2 <= diagonal_reg[25];
				10: current_diagonal_reg2 <= diagonal_reg[26];
				11: current_diagonal_reg2 <= diagonal_reg[27];
				12: current_diagonal_reg2 <= diagonal_reg[28];
				13: current_diagonal_reg2 <= diagonal_reg[29];
				14: current_diagonal_reg2 <= diagonal_reg[30];
				default: current_diagonal_reg2 <= 0;
				endcase
			end
			default: current_diagonal_reg2 <= 40'b0;
		endcase
		end
	end
end

//============================//
//       SUM of diagonal      //
//============================//
//diagonal_reg[0]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[0] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[0] <= 0;
		if(counter_cal > 4) begin // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_2: if((counter_cal - 5) % 2 == 0) diagonal_reg[0] <= update_diagonal_wire1;
			s_cal_4: if((counter_cal - 5) % 4 == 0) diagonal_reg[0] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 0) diagonal_reg[0] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 0) diagonal_reg[0] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[1]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[1] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[1] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_2: if((counter_cal - 5) % 2 == 1) diagonal_reg[1] <= update_diagonal_wire1;
			s_cal_4: if((counter_cal - 5) % 4 == 1) diagonal_reg[1] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 1) diagonal_reg[1] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 1) diagonal_reg[1] <= update_diagonal_wire1;
			s_output: if(size==2) diagonal_reg[1] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[2]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[2] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[2] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_2: if((counter_cal - 5) % 2 == 0) diagonal_reg[2] <= update_diagonal_wire2;
			s_cal_4: if((counter_cal - 5) % 4 == 2) diagonal_reg[2] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 2) diagonal_reg[2] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 2) diagonal_reg[2] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[3]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[3] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[3] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_4: if((counter_cal - 5) % 4 == 3) diagonal_reg[3] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 3) diagonal_reg[3] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 3) diagonal_reg[3] <= update_diagonal_wire1;
			s_output: if(size==4) diagonal_reg[3] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[4]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[4] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[4] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_4: if((counter_cal - 5) % 4 == 0) diagonal_reg[4] <= update_diagonal_wire2;
			s_cal_8: if((counter_cal - 5) % 8 == 4) diagonal_reg[4] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 4) diagonal_reg[4] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[5]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[5] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[5] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_4: if((counter_cal - 5) % 4 == 1) diagonal_reg[5] <= update_diagonal_wire2;
			s_cal_8: if((counter_cal - 5) % 8 == 5) diagonal_reg[5] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 5) diagonal_reg[5] <= update_diagonal_wire1;
			s_output:if(size==4) diagonal_reg[5] <= update_diagonal_wire2;
		endcase
		end
	end
end
//diagonal_reg[6]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[6] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[6] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_4: if((counter_cal - 5) % 4 == 2) diagonal_reg[6] <= update_diagonal_wire2;
			s_cal_8: if((counter_cal - 5) % 8 == 6) diagonal_reg[6] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 6) diagonal_reg[6] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[7]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[7] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[7] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 7) diagonal_reg[7] <= update_diagonal_wire1;
			s_cal_16:if((counter_cal - 5) % 16== 7) diagonal_reg[7] <= update_diagonal_wire1;
			s_output: if(size==8) diagonal_reg[7] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[8]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[8] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[8] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 0) diagonal_reg[8] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 8) diagonal_reg[8] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[9]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[9] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[9] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 1) diagonal_reg[9] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 9) diagonal_reg[9] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[10]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[10] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[10] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 2) diagonal_reg[10] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 10) diagonal_reg[10] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[11]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[11] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[11] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 3)  diagonal_reg[11] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 11) diagonal_reg[11] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[12]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[12] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[12] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 4)  diagonal_reg[12] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 12) diagonal_reg[12] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[13]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[13] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[13] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 5)  diagonal_reg[13] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 13) diagonal_reg[13] <= update_diagonal_wire1;
			s_output: if(size==8) diagonal_reg[13] <= update_diagonal_wire2;
		endcase
		end
	end
end
//diagonal_reg[14]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[14] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[14] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_8: if((counter_cal - 5) % 8 == 6)  diagonal_reg[14] <= update_diagonal_wire2;
			s_cal_16:if((counter_cal - 5) % 16== 14) diagonal_reg[14] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[15]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[15] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[15] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_16:if((counter_cal - 5) % 16== 15) diagonal_reg[15] <= update_diagonal_wire1;
			s_output: if(size==16) diagonal_reg[15] <= update_diagonal_wire1;
		endcase
		end
	end
end
//diagonal_reg[16~29]
generate
for(j = 0 ; j < 14 ; j = j + 1)begin
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[j+16] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[j+16] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_16:if((counter_cal - 5) % 16 == j) diagonal_reg[j+16] <= update_diagonal_wire2;
		endcase
		end
	end
end
end
endgenerate
//diagonal_reg[30]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) diagonal_reg[30] <= 0;
	else begin
		if(n_state == s_choose)  diagonal_reg[30] <= 0;
		if(counter_cal > 4) begin  // Wait SRAM output and 2-level adder delay
		case(n_state)
			s_cal_16:if((counter_cal - 5) % 16 == 14) diagonal_reg[30] <= update_diagonal_wire2;
			s_output:if(size==16) diagonal_reg[30] <= update_diagonal_wire2;
		endcase
		end
	end
end
//---------------------------------------------------------------------
//   OUTPUT
//---------------------------------------------------------------------
always@(posedge clk or negedge rst_n) begin
  if(!rst_n)
      out_valid <= 1'd0;
  else begin
	case(n_state)
	s_cal_2: if(counter_cal >   7) out_valid <= 1;
	s_cal_4: if(counter_cal >  17) out_valid <= 1;
	s_cal_8: if(counter_cal >  61) out_valid <= 1;
	s_cal_16:if(counter_cal > 245) out_valid <= 1;
	s_output: begin

		case(size)
		2: if(counter_out == 0) out_valid <= 1;
		   else out_valid <= 0 ;
		4: if(counter_out == 0) out_valid <= 1 ;
		   else out_valid <= 0 ;
		8: if(counter_out < 1) out_valid <= 1;
		   else out_valid <= 0 ;
		16:if(counter_out < 2) out_valid <= 1 ;
		   else out_valid <= 0 ;
		endcase
	end
	default: out_valid <= 1'd0;
	endcase
  end
end

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)
		out_value <= 40'd0;
	else begin
		case(n_state)
		s_cal_2:begin
			case(counter_cal)
			8: out_value <= diagonal_reg[0];
			9: out_value <= diagonal_reg[1];
			10:out_value <= diagonal_reg[2];
			endcase
		end
		s_cal_4:begin
			case(counter_cal)
			18: out_value <= diagonal_reg[0];
			19: out_value <= diagonal_reg[1];
			20: out_value <= diagonal_reg[2];
			21: out_value <= diagonal_reg[3];
			22: out_value <= diagonal_reg[4];
			23: out_value <= diagonal_reg[5];
			endcase
		end
		s_cal_8: begin
			case(counter_cal)
			62: out_value <= diagonal_reg[0];
			63: out_value <= diagonal_reg[1];
			64: out_value <= diagonal_reg[2];
			65: out_value <= diagonal_reg[3];
			66: out_value <= diagonal_reg[4];
			67: out_value <= diagonal_reg[5];
			68: out_value <= diagonal_reg[6];
			69: out_value <= diagonal_reg[7];
			70: out_value <= diagonal_reg[8];
			71: out_value <= diagonal_reg[9];
			72: out_value <= diagonal_reg[10];
			73: out_value <= diagonal_reg[11];
			74: out_value <= diagonal_reg[12];
			75: out_value <= diagonal_reg[13];
			endcase
		end
		s_cal_16:begin
			case(counter_cal)
			246: out_value <= diagonal_reg[0];
			247: out_value <= diagonal_reg[1];
			248: out_value <= diagonal_reg[2];
			249: out_value <= diagonal_reg[3];
			250: out_value <= diagonal_reg[4];

			251: out_value <= diagonal_reg[5];
			252: out_value <= diagonal_reg[6];
			253: out_value <= diagonal_reg[7];
			254: out_value <= diagonal_reg[8];
			255: out_value <= diagonal_reg[9];

			256: out_value <= diagonal_reg[10];
			257: out_value <= diagonal_reg[11];
			258: out_value <= diagonal_reg[12];
			259: out_value <= diagonal_reg[13];
			260: out_value <= diagonal_reg[14];

			261: out_value <= diagonal_reg[15];
			262: out_value <= diagonal_reg[16];
			263: out_value <= diagonal_reg[17];
			264: out_value <= diagonal_reg[18];
			265: out_value <= diagonal_reg[19];

			266: out_value <= diagonal_reg[20];
			267: out_value <= diagonal_reg[21];
			268: out_value <= diagonal_reg[22];
			269: out_value <= diagonal_reg[23];
			270: out_value <= diagonal_reg[24];

			271: out_value <= diagonal_reg[25];
			272: out_value <= diagonal_reg[26];
			273: out_value <= diagonal_reg[27];
			274: out_value <= diagonal_reg[28];
			endcase
		end
	 	s_output: begin
			if(counter_out==0)begin
				case(size)
		 		2: out_value <= diagonal_reg[2];
		 		4: out_value <= diagonal_reg[6];
		 		8: out_value <= diagonal_reg[14];
		 		16:if(counter_cal == 275) out_value <= diagonal_reg[29];
				   else out_value <= diagonal_reg[30];
		 		endcase
			end
			else if(counter_out==1)
				case(size)
		 		2: out_value <= 0;
		 		4: out_value <= 0;
		 		8: out_value <= 0;
		 		16:out_value <= diagonal_reg[30];
		 		endcase
			else out_value<= 40'd0;
		end
		default: out_value<= 40'd0;
		endcase
    end
end
//---------------------------------------------------------------------
//   FSM
//---------------------------------------------------------------------
always@(posedge	clk or negedge rst_n)	begin
	if(!rst_n) c_state <= s_idle;
	else c_state <= n_state;
end

always@(*)	begin
	case(c_state)
		s_idle:  begin
			if(in_valid)  		n_state = s_input;
			else if(in_valid2)  n_state = s_choose;
			else          		n_state = s_idle;
		end
	    s_input: begin
			if(in_valid)  n_state = s_input;
			else 		  n_state = s_idle;
		end
		s_choose:begin
			if(in_valid2)  n_state = s_choose;
			else begin
			case(size)
				2: 	n_state = s_cal_2;
				4: 	n_state = s_cal_4;
				8: 	n_state = s_cal_8;
				16:	n_state = s_cal_16;
				default: n_state = s_idle;
			endcase
			end
		end
        s_cal_2: begin
			if(counter_cal==4+3+3)  n_state = s_output;
			else                    n_state = s_cal_2;
		end
		s_cal_4: begin
			if(counter_cal==16+8) n_state = s_output;
			else          		    n_state = s_cal_4;
		end
		s_cal_8: begin
			if(counter_cal==64+12) n_state = s_output;
			else            		  n_state = s_cal_8;
		end
		s_cal_16:begin
			if(counter_cal==256+19) n_state = s_output;
			else            		   n_state = s_cal_16;
		end
		s_output:begin
			if(!out_valid) n_state = s_choose;
			else if (counter_round == 16)begin
				case(size)
				2: n_state = s_idle;
				4: n_state = s_idle;
				8: n_state = s_idle;
				16:begin
					if(counter_out > 1)n_state = s_idle;
				    else n_state = s_output;
				end
				default: n_state = s_idle;
				endcase
			end
			else n_state = s_output;
		end
		default: n_state = s_idle;
	endcase
end
//---------------------------------------------------------------------
//   counter
//---------------------------------------------------------------------
// row counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_row <= 0;
	else begin
		case(n_state)
		s_cal_2:  if(counter_cal % 2 == 0) counter_row <= 1;
				  else counter_row <= counter_row + 1;
		s_cal_4:  if(counter_cal % 4 == 0) counter_row <= 1;
				  else counter_row <= counter_row + 1;
		s_cal_8:  if(counter_cal % 8 == 0) counter_row <= 1;
				  else counter_row <= counter_row + 1;
		s_cal_16: if(counter_cal % 16 ==0) counter_row <= 1;
				  else counter_row <= counter_row + 1;
		default:  counter_row <= 0;
		endcase
	end
end
// column counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_col <= 0;
	else begin
		case(n_state)
		s_cal_2: if(counter_cal % 2 == 0) counter_col <= counter_col +1;
		s_cal_4: if(counter_cal % 4 == 0) counter_col <= counter_col +1;
		s_cal_8: if(counter_cal % 8 == 0) counter_col <= counter_col +1;
		s_cal_16:if(counter_cal % 16 == 0)counter_col <= counter_col +1;
		default : counter_col <= 0;
		endcase
	end
end
//input index  & calculate counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		counter_cal <= 0;
	else begin
        case(n_state)
			s_idle:   counter_cal <= 0;
			s_input:  counter_cal <= counter_cal + 1;
			s_choose: begin
				if(counter_cal==0)counter_cal <= 0;
				else counter_cal <= counter_cal + 1;
			end
			// Since SRAM output delay, counter + 2
			s_cal_2:  begin
				if(counter_cal < 4+8)counter_cal <= counter_cal + 1;
			 	else counter_cal <= 0;
			end
			s_cal_4:  begin
				if(counter_cal < 16+8)counter_cal <= counter_cal + 1;
			 	else counter_cal <= 0;
			end
			s_cal_8:  begin
				if(counter_cal < 64+12)counter_cal <= counter_cal + 1;
			 	else counter_cal <= 0;
			end
			s_cal_16:begin
				if(counter_cal < 256+19)counter_cal <= counter_cal + 1;
			 	else counter_cal <= 0;
			end
			s_output: counter_cal <=0;
            default:  counter_cal <= 0;
        endcase
    end
end
// number of output
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_out <= 0;
	else begin
        case(n_state)
			s_output: counter_out <= counter_out + 1;
			default:  counter_out <= 0;
        endcase
    end
end

// number of round
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_round <= 0;
	else begin
        case(n_state)
			s_idle:  counter_round <= 0;
			s_choose: counter_round <= counter_round + 1;
			default: counter_round <= counter_round;
        endcase
    end
end

//---------------------------------------------------------------------
//   Adder & Multiplier
//---------------------------------------------------------------------
// Multiplier
mult M1 (.inst_A(x_reg[0]),  .inst_B(w_reg[0]),  .PRODUCT_inst(y_wire[0]));
mult M2 (.inst_A(x_reg[1]),  .inst_B(w_reg[1]),  .PRODUCT_inst(y_wire[1]));
mult M3 (.inst_A(x_reg[2]),  .inst_B(w_reg[2]),  .PRODUCT_inst(y_wire[2]));
mult M4 (.inst_A(x_reg[3]),  .inst_B(w_reg[3]),  .PRODUCT_inst(y_wire[3]));
mult M5 (.inst_A(x_reg[4]),  .inst_B(w_reg[4]),  .PRODUCT_inst(y_wire[4]));
mult M6 (.inst_A(x_reg[5]),  .inst_B(w_reg[5]),  .PRODUCT_inst(y_wire[5]));
mult M7 (.inst_A(x_reg[6]),  .inst_B(w_reg[6]),  .PRODUCT_inst(y_wire[6]));
mult M8 (.inst_A(x_reg[7]),  .inst_B(w_reg[7]),  .PRODUCT_inst(y_wire[7]));
mult M9 (.inst_A(x_reg[8]),  .inst_B(w_reg[8]),  .PRODUCT_inst(y_wire[8]));
mult M10(.inst_A(x_reg[9]),  .inst_B(w_reg[9]),  .PRODUCT_inst(y_wire[9]));
mult M11(.inst_A(x_reg[10]), .inst_B(w_reg[10]), .PRODUCT_inst(y_wire[10]));
mult M12(.inst_A(x_reg[11]), .inst_B(w_reg[11]), .PRODUCT_inst(y_wire[11]));
mult M13(.inst_A(x_reg[12]), .inst_B(w_reg[12]), .PRODUCT_inst(y_wire[12]));
mult M14(.inst_A(x_reg[13]), .inst_B(w_reg[13]), .PRODUCT_inst(y_wire[13]));
mult M15(.inst_A(x_reg[14]), .inst_B(w_reg[14]), .PRODUCT_inst(y_wire[14]));
mult M16(.inst_A(x_reg[15]), .inst_B(w_reg[15]), .PRODUCT_inst(y_wire[15]));

// 16-Adder upper-left
adder A1 (.inst_A(y_reg[0]),  .inst_B(y_reg[1]),   .SUM_inst(A_wire[0]));
adder A2 (.inst_A(y_reg[2]),  .inst_B(A_wire[0]),  .SUM_inst(A_wire[1]));
adder A3 (.inst_A(y_reg[3]),  .inst_B(A_wire[1]),  .SUM_inst(A_wire[2]));
adder A4 (.inst_A(y_reg[4]),  .inst_B(A_wire[2]),  .SUM_inst(A_wire[3]));
adder A5 (.inst_A(y_reg[5]),  .inst_B(A_wire[3]),  .SUM_inst(A_wire[4]));
adder A6 (.inst_A(y_reg[6]),  .inst_B(A_wire[4]),  .SUM_inst(A_wire[5]));
adder A7 (.inst_A(y_reg[7]),  .inst_B(A_wire[5]),  .SUM_inst(A_wire[6]));

adder A8 (.inst_A(y_reg[8]),  .inst_B(A_wire[6]),  .SUM_inst(A_wire[7]));
adder A9 (.inst_A(y_reg[9]),  .inst_B(A_wire[7]),  .SUM_inst(A_wire[8]));
adder A10(.inst_A(y_reg[10]), .inst_B(A_wire[8]),  .SUM_inst(A_wire[9]));
adder A11(.inst_A(y_reg[11]), .inst_B(A_wire[9]),  .SUM_inst(A_wire[10]));
adder A12(.inst_A(y_reg[12]), .inst_B(A_wire[10]), .SUM_inst(A_wire[11]));
adder A13(.inst_A(y_reg[13]), .inst_B(A_wire[11]), .SUM_inst(A_wire[12]));
adder A14(.inst_A(y_reg[14]), .inst_B(A_wire[12]), .SUM_inst(A_wire[13]));
adder A15(.inst_A(y_reg[15]), .inst_B(A_wire[13]), .SUM_inst(A_wire[14]));

// 15-Adder lower right
adder B1 (.inst_A(y_reg[1]),  .inst_B(B_wire[1]),  .SUM_inst(B_wire[0]));
adder B2 (.inst_A(y_reg[2]),  .inst_B(B_wire[2]),  .SUM_inst(B_wire[1]));
adder B3 (.inst_A(y_reg[3]),  .inst_B(B_wire[3]),  .SUM_inst(B_wire[2]));
adder B4 (.inst_A(y_reg[4]),  .inst_B(B_wire[4]),  .SUM_inst(B_wire[3]));
adder B5 (.inst_A(y_reg[5]),  .inst_B(B_wire[5]),  .SUM_inst(B_wire[4]));
adder B6 (.inst_A(y_reg[6]),  .inst_B(B_wire[6]),  .SUM_inst(B_wire[5]));
adder B7 (.inst_A(y_reg[7]),  .inst_B(B_wire[7]),  .SUM_inst(B_wire[6]));

adder B8 (.inst_A(y_reg[8]),  .inst_B(B_wire[8]),  .SUM_inst(B_wire[7]));
adder B9 (.inst_A(y_reg[9]),  .inst_B(B_wire[9]),  .SUM_inst(B_wire[8]));
adder B10(.inst_A(y_reg[10]), .inst_B(B_wire[10]), .SUM_inst(B_wire[9]));
adder B11(.inst_A(y_reg[11]), .inst_B(B_wire[11]), .SUM_inst(B_wire[10]));
adder B12(.inst_A(y_reg[12]), .inst_B(B_wire[12]), .SUM_inst(B_wire[11]));
adder B13(.inst_A(y_reg[13]), .inst_B(B_wire[13]), .SUM_inst(B_wire[12]));
adder B14(.inst_A(y_reg[14]), .inst_B(y_reg[15]),  .SUM_inst(B_wire[13]));


// diagonal adder
adder Y1(.inst_A(Y1_reg), .inst_B(current_diagonal_reg1), .SUM_inst(update_diagonal_wire1));
adder Y2(.inst_A(Y2_reg), .inst_B(current_diagonal_reg2), .SUM_inst(update_diagonal_wire2));

//---------------------------------------------------------------------
//   SRAM
//---------------------------------------------------------------------
RA1SH SRAM_X (.Q(mem_out_X), .CLK(clk),.CEN(cen),.WEN(wen_X),.A(addr_X), .D(in_mem_X), .OEN(oen));
RA1SH SRAM_W (.Q(mem_out_W), .CLK(clk),.CEN(cen),.WEN(wen_W),.A(addr_W), .D(in_mem_W), .OEN(oen));

endmodule

module mult(inst_A, inst_B, PRODUCT_inst);

parameter mult_A_width = 16;
parameter mult_B_width = 16;

input  [mult_A_width-1 : 0] inst_A;
input  [mult_B_width-1 : 0] inst_B;
output [mult_A_width+mult_B_width-1 : 0] PRODUCT_inst;

DW02_mult #(mult_A_width, mult_B_width)
	U1( .A(inst_A),
		.B(inst_B),
		.TC(1'b1),
		.PRODUCT(PRODUCT_inst));
endmodule

module adder(inst_A, inst_B, SUM_inst);

parameter add_width = 40;

input [add_width-1 : 0] inst_A;
input [add_width-1 : 0] inst_B;
output[add_width-1 : 0] SUM_inst;

wire CO_inst;

DW01_add #(add_width)
	U1 (.A(inst_A),
		.B(inst_B),
		.CI(1'b0),
		.SUM(SUM_inst),
		.CO(CO_inst));
endmodule