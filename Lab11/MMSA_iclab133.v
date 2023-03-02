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
input 		 matrix;
input [1:0]  matrix_size;
input 		 i_mat_idx, w_mat_idx;

output reg   out_valid;
output reg	 out_value;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
/* FSM */
parameter s_idle        = 0;
parameter s_input       = 1;
parameter s_choose      = 2;
parameter s_cal_2       = 3;
parameter s_cal_4       = 4;
parameter s_cal_8       = 5;
parameter s_cal_leng    = 6;
parameter s_output_len  = 7;
parameter s_output_val  = 8;

parameter mult_A_width = 16;
parameter mult_B_width = 16;
parameter add_width = 40;

genvar i,j;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
//========== Lab 11 new reg ==========//
reg [15:0] tmp_matrix;
//reg [3:0]  tmp_i_mat_idx,tmp_w_mat_idx;
reg [15:0] counter_input;       // in_valid1 counter max 16384 input (max count 32768)
reg [1:0]  counter_input_idx;   // in_valid2 counter
reg [2:0]  counter_out_len;     // max 6
reg [5:0]  counter_out_val;     // max 40
reg [5:0]  counter_out_size;    // max 64
reg out_flag;
reg fsm_out_flag;

//========= FSM / counter ===========//
reg [3:0]  c_state, n_state;
reg [4:0]  size;          // max 16
reg [5:0]  counter_row;   // max 16 row
reg [5:0]  counter_col;   // max 16 col
reg [12:0] counter_sram ; // max 4096 input
reg [6:0]  counter_cal;   // max 127
reg [4:0]  counter_round; // max 256

//============= cal reg =============//
reg  [39:0] diagonal_reg [14:0]; //15 diagonal, max 8*8 //31 diagonal, max 16*16
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
reg [9:0]  addr_X;
reg [9:0]  addr_W;

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

//============== Lab 11 new ==============//
// tmp_matrix
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) tmp_matrix <= 'd0;
	else if (n_state == s_input) begin
		tmp_matrix[15] <= tmp_matrix[14];
		tmp_matrix[14] <= tmp_matrix[13];
		tmp_matrix[13] <= tmp_matrix[12];
		tmp_matrix[12] <= tmp_matrix[11];
		tmp_matrix[11] <= tmp_matrix[10];
		tmp_matrix[10] <= tmp_matrix[9];
		tmp_matrix[9]  <= tmp_matrix[8];
		tmp_matrix[8]  <= tmp_matrix[7];
		tmp_matrix[7]  <= tmp_matrix[6];
		tmp_matrix[6]  <= tmp_matrix[5];
		tmp_matrix[5]  <= tmp_matrix[4];
		tmp_matrix[4]  <= tmp_matrix[3];
		tmp_matrix[3]  <= tmp_matrix[2];
		tmp_matrix[2]  <= tmp_matrix[1];
		tmp_matrix[1]  <= tmp_matrix[0];
		tmp_matrix[0]  <= matrix;
	end
end

//===================================//

// size
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) size <= 5'd0 ;
	else begin
        //give matrix size in first input cycle
		if (n_state == s_input && counter_input == 0) begin
      case(matrix_size)
          2'b00: size <=  5'd2;
			    2'b01: size <=  5'd4;
			    2'b10: size <=  5'd8;
			endcase
		end
	end
end
// choose done
reg choose_flag;
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) choose_flag <= 'd0 ;
	else begin
		if (n_state == s_choose)
      choose_flag <= 1;
    else
      choose_flag <= 'd0 ;
	end
end

// X matrix index
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) X_idx <= 'd0 ;
	else begin
        //give matrix size in first input cycle
		if (in_valid2)begin//n_state == s_choose || n_state == s_idle) begin
      //X_idx <= tmp_i_mat_idx;//i_mat_idx;
      X_idx[3] <= X_idx[2];
		  X_idx[2] <= X_idx[1];
		  X_idx[1] <= X_idx[0];
		  X_idx[0] <= i_mat_idx;
		end
    else if(n_state == s_output_val)
      X_idx <= 'd0 ;
	end
end
// W matrix index
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) W_idx <= 'd0 ;
	else begin
        //give matrix size in first input cycle
		if (in_valid2)begin//(n_state == s_choose || n_state == s_idle) begin
      //W_idx <= tmp_w_mat_idx;//w_mat_idx;
      W_idx[3] <= W_idx[2];
		  W_idx[2] <= W_idx[1];
		  W_idx[1] <= W_idx[0];
		  W_idx[0] <= w_mat_idx;
		end
    else if(n_state == s_output_val)
      W_idx <= 'd0 ;
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
    if(n_state == s_input)begin
			if(counter_input!=0 && counter_input<=16384 && counter_input%16==0) wen_X <= 0; // write
			else wen_X <= 1;
    end
    else begin
      wen_X <= 1;
    end
	end
end
// wen_W
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_W <= 1; // read
	end
	else begin
    if(n_state == s_input)begin
		  if(counter_input!=0 && counter_input%16==0) wen_W <= 0; // write
			else wen_W <= 1;
    end
    else begin
      wen_W <= 1; // read
		end
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
			s_input:  addr_X <= counter_sram;
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
			s_cal_leng: addr_X <= counter_cal;
		endcase
	end
end
// addr_W
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) addr_W <= 0;
	else begin
        case(n_state)
			s_input: begin
        		if(counter_sram == 0) addr_W <= 0;
				else begin
					case(size)
						2: if(counter_sram >= 64)   addr_W <= counter_sram[5:0];
						4: if(counter_sram >= 256)  addr_W <= counter_sram[7:0];
						8: if(counter_sram >= 1024) addr_W <= counter_sram[9:0];
						default addr_W <= 0;
					endcase
				end
			end
			s_cal_2:  addr_W <= (W_idx << 2) + counter_cal;
			s_cal_4:  addr_W <= (W_idx << 4) + counter_cal;
			s_cal_8:  addr_W <= (W_idx << 6) + counter_cal;
			s_cal_leng: addr_W <= counter_cal;
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
            if(counter_sram == 0) in_mem_X <= tmp_matrix;
			else begin
				case(size)
					2: if(counter_sram < 64)   in_mem_X <= tmp_matrix;
					4: if(counter_sram < 256)  in_mem_X <= tmp_matrix;
					8: if(counter_sram < 1024) in_mem_X <= tmp_matrix;
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
            if(counter_sram == 1) in_mem_W <= 16'd0;
			else begin
				case(size)
					2: if(counter_sram >= 64)   in_mem_W <= tmp_matrix;
					4: if(counter_sram >= 256)  in_mem_W <= tmp_matrix;
					8: if(counter_sram >= 1024) in_mem_W <= tmp_matrix;
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
			x_reg[8] <= 16'd0;
		end
	end
end
// X_reg[9]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[9] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[9] <= 16'd0;
		end
	end
end
// X_reg[10]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[10] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[10] <= 16'd0;
		end
	end
end
// X_reg[11]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[11] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[11] <= 16'd0;
		end
	end
end
// X_reg[12]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[12] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[12] <= 16'd0;
		end
	end
end
// X_reg[13]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[13] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[13] <= 16'd0;
		end
	end
end
// X_reg[14]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[14] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[14] <= x_reg[13];

		end
	end
end
// X_reg[15]
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_reg[15] <= 16'd0;
	else begin
		if(counter_cal > 1) begin // Wait SRAM output delay
			x_reg[15] <= 16'd0;
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
			s_cal_2: if((counter_cal - 5) % 2 == 0 && counter_cal < 8) diagonal_reg[0] <= update_diagonal_wire1;
			s_cal_4: if((counter_cal - 5) % 4 == 0 && counter_cal < 18) diagonal_reg[0] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 0 && counter_cal < 62) diagonal_reg[0] <= update_diagonal_wire1;
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
			s_cal_4: if((counter_cal - 5) % 4 == 1 && counter_cal < 19) diagonal_reg[1] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 1 && counter_cal < 63) diagonal_reg[1] <= update_diagonal_wire1;
			s_cal_leng: if(size==2 && counter_cal < 9) diagonal_reg[1] <= update_diagonal_wire1;
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
			s_cal_2: if((counter_cal - 5) % 2 == 0 && counter_cal < 10) diagonal_reg[2] <= update_diagonal_wire2;
			s_cal_4: if((counter_cal - 5) % 4 == 2 && counter_cal < 20) diagonal_reg[2] <= update_diagonal_wire1;
			s_cal_8: if((counter_cal - 5) % 8 == 2 && counter_cal < 64) diagonal_reg[2] <= update_diagonal_wire1;
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
			s_cal_8: if((counter_cal - 5) % 8 == 3 && counter_cal < 65) diagonal_reg[3] <= update_diagonal_wire1;
			s_cal_leng: if(size==4 && counter_cal < 21) diagonal_reg[3] <= update_diagonal_wire1;
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
			s_cal_4: if((counter_cal - 5) % 4 == 0 && counter_cal < 22) diagonal_reg[4] <= update_diagonal_wire2;
			s_cal_8: if((counter_cal - 5) % 8 == 4 && counter_cal < 66) diagonal_reg[4] <= update_diagonal_wire1;
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
			s_cal_8: if((counter_cal - 5) % 8 == 5 && counter_cal < 67) diagonal_reg[5] <= update_diagonal_wire1;
			s_cal_leng:if(size==4  && counter_cal < 23) diagonal_reg[5] <= update_diagonal_wire2;
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
			s_cal_4: if((counter_cal - 5) % 4 == 2 && counter_cal < 24) diagonal_reg[6] <= update_diagonal_wire2;
			s_cal_8: if((counter_cal - 5) % 8 == 6  && counter_cal < 68) diagonal_reg[6] <= update_diagonal_wire1;
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
			s_cal_leng: if(size==8 && counter_cal < 69) diagonal_reg[7] <= update_diagonal_wire1;
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
			s_cal_8: if((counter_cal - 5) % 8 == 0 && counter_cal < 70) diagonal_reg[8] <= update_diagonal_wire2;
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
			s_cal_8: if((counter_cal - 5) % 8 == 1 && counter_cal < 71) diagonal_reg[9] <= update_diagonal_wire2;
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
			s_cal_8: if((counter_cal - 5) % 8 == 2 && counter_cal < 72) diagonal_reg[10] <= update_diagonal_wire2;
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
			s_cal_8: if((counter_cal - 5) % 8 == 3 && counter_cal < 73)  diagonal_reg[11] <= update_diagonal_wire2;
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
			s_cal_8: if((counter_cal - 5) % 8 == 4 && counter_cal < 74)  diagonal_reg[12] <= update_diagonal_wire2;
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
			s_cal_leng: if(size==8 && counter_cal < 75) diagonal_reg[13] <= update_diagonal_wire2;
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
			s_cal_8: if((counter_cal - 5) % 8 == 6 && counter_cal < 76)  diagonal_reg[14] <= update_diagonal_wire2;
		endcase
		end
	end
end

//===================================//
//   Lab 11 : count output length    //
//===================================//
reg [5:0] output_length [14:0]; // max 15

// output_length
generate
for(i=0 ; i<15 ; i=i+1)begin
    always @(posedge clk or negedge rst_n) begin
    	if(!rst_n)
        output_length[i] <= 0;
    	else begin
    		if(n_state == s_cal_leng) begin
          		if(diagonal_reg[i][39]==1) begin
          		  output_length[i] <= 40;
          		end
          		else begin
          		  if(diagonal_reg[i][38] == 1)
          		    output_length[i] <= 39;
          		  else if(diagonal_reg[i][37] == 1)
          		    output_length[i] <= 38;
          		  else if(diagonal_reg[i][36] == 1)
          		    output_length[i] <= 37;
          		  else if(diagonal_reg[i][35] == 1)
          		    output_length[i] <= 36;
          		  else if(diagonal_reg[i][34] == 1)
          		    output_length[i] <= 35;
          		  else if(diagonal_reg[i][33] == 1)
          		    output_length[i] <= 34;
          		  else if(diagonal_reg[i][32] == 1)
          		    output_length[i] <= 33;
          		  else if(diagonal_reg[i][31] == 1)
          		    output_length[i] <= 32;
          		  else if(diagonal_reg[i][30] == 1)
          		    output_length[i] <= 31;

          		  else if(diagonal_reg[i][29] == 1)
          		    output_length[i] <= 30;
          		  else if(diagonal_reg[i][28] == 1)
          		    output_length[i] <= 29;
          		  else if(diagonal_reg[i][27] == 1)
          		    output_length[i] <= 28;
          		  else if(diagonal_reg[i][26] == 1)
          		    output_length[i] <= 27;
          		  else if(diagonal_reg[i][25] == 1)
          		    output_length[i] <= 26;
          		  else if(diagonal_reg[i][24] == 1)
          		    output_length[i] <= 25;
          		  else if(diagonal_reg[i][23] == 1)
          		    output_length[i] <= 24;
          		  else if(diagonal_reg[i][22] == 1)
          		    output_length[i] <= 23;
          		  else if(diagonal_reg[i][21] == 1)
          		    output_length[i] <= 22;
          		  else if(diagonal_reg[i][20] == 1)
          		    output_length[i] <= 21;

          		  else if(diagonal_reg[i][19] == 1)
          		    output_length[i] <= 20;
          		  else if(diagonal_reg[i][18] == 1)
          		    output_length[i] <= 19;
          		  else if(diagonal_reg[i][17] == 1)
          		    output_length[i] <= 18;
          		  else if(diagonal_reg[i][16] == 1)
          		    output_length[i] <= 17;
          		  else if(diagonal_reg[i][15] == 1)
          		    output_length[i] <= 16;
          		  else if(diagonal_reg[i][14] == 1)
          		    output_length[i] <= 15;
          		  else if(diagonal_reg[i][13] == 1)
          		    output_length[i] <= 14;
          		  else if(diagonal_reg[i][12] == 1)
          		    output_length[i] <= 13;
          		  else if(diagonal_reg[i][11] == 1)
          		    output_length[i] <= 12;
          		  else if(diagonal_reg[i][10] == 1)
          		    output_length[i] <= 11;

          		  else if(diagonal_reg[i][9] == 1)
          		    output_length[i] <= 10;
          		  else if(diagonal_reg[i][8] == 1)
          		    output_length[i] <= 9;
          		  else if(diagonal_reg[i][7] == 1)
          		    output_length[i] <= 8;
          		  else if(diagonal_reg[i][6] == 1)
          		    output_length[i] <= 7;
          		  else if(diagonal_reg[i][5] == 1)
          		    output_length[i] <= 6;
          		  else if(diagonal_reg[i][4] == 1)
          		    output_length[i] <= 5;
          		  else if(diagonal_reg[i][3] == 1)
          		    output_length[i] <= 4;
          		  else if(diagonal_reg[i][2] == 1)
          		    output_length[i] <= 3;
          		  else if(diagonal_reg[i][1] == 1)
          		    output_length[i] <= 2;
          		  else if(diagonal_reg[i][0] == 1)
          		    output_length[i] <= 1;
          		  else
          		    output_length[i] <= 1;
          		end
        	end
        	else if(n_state == s_idle)
        	  output_length[i] <= 0;
    	end
    end
end
endgenerate

//---------------------------------------------------------------------
//   OUTPUT
//---------------------------------------------------------------------
always@(posedge clk or negedge rst_n) begin
  if(!rst_n)
    out_valid <= 1'd0;
  else begin
    if(n_state == s_output_len || n_state == s_output_val)begin
      if(counter_out_size == (size-1)<<1 && out_flag)
        out_valid <= 1'd0;
      else
        out_valid <= 1'd1;
    end
    else
      out_valid <= 1'd0;
  end
end

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)
		out_value <= 'd0;
	else begin
    if(n_state == s_output_len) begin
      if(counter_out_len==6) begin// revise output value
        if(diagonal_reg[counter_out_size]==0)
			out_value <= 0;
		else
			out_value <= 1;
	  end
      //================== post cycle ==================//
      //else begin
      //  case(size)
      //    2: out_value <= output_length[2-counter_out_size][5-counter_out_len];
      //    4: out_value <= output_length[6-counter_out_size][5-counter_out_len];
      //    8: out_value <= output_length[14-counter_out_size][5-counter_out_len];
      //  endcase
      //end
      //================================================//

      //================== pre cycle ==================//
      else out_value <= output_length[counter_out_size][5-counter_out_len];
      //===============================================//
    end
    else if(n_state == s_output_val) begin
      if(out_flag==1) begin// revise output length
        if(counter_out_size == (size-1)<<1)
          out_value <= 0;
        else begin
          //================== post cycle ==================//
          //case(size)
          //  2: out_value <= output_length[1-counter_out_size][5];
          //  4: out_value <= output_length[5-counter_out_size][5];
          //  8: out_value <= output_length[13-counter_out_size][5];
          //endcase
          //================================================//

          //================== pre cycle ==================//
          out_value <= output_length[counter_out_size+1][5];
          //===============================================//
        end
      end
      //================== post cycle ==================//
      //else begin
      //  case(size)
      //    2: out_value <= diagonal_reg[2-counter_out_size][output_length[2-counter_out_size]-counter_out_val];
      //    4: out_value <= diagonal_reg[6-counter_out_size][output_length[6-counter_out_size]-counter_out_val];
      //    8: out_value <= diagonal_reg[14-counter_out_size][output_length[14-counter_out_size]-counter_out_val];
      //  endcase
      //end
      //================================================//

      //================== pre cycle ==================//
      else out_value <= diagonal_reg[counter_out_size][output_length[counter_out_size]-counter_out_val];
      //===============================================//
    end
    else out_value <= 0;
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
			if(in_valid)  		  n_state = s_input;
			else if(in_valid2)  n_state = s_choose;
			else          		  n_state = s_idle;
		end
	  	s_input: begin
			if     ((matrix_size == 2 || size == 2) && counter_input<=2048)   n_state = s_input;
      		else if((matrix_size == 4 || size == 4) && counter_input<=8192)   n_state = s_input;
      		else if((matrix_size == 8 || size == 8) && counter_input<=32768)  n_state = s_input;
      		//if(counter_input<=32768)  n_state = s_input;
      		else if(in_valid2)	      n_state = s_choose;
			else 		                  n_state = s_idle;
			end
		s_choose:begin
			if(in_valid2)  n_state = s_choose;
			else begin
			case(size)
				2: 	n_state = s_cal_2;
				4: 	n_state = s_cal_4;
				8: 	n_state = s_cal_8;
				default: n_state = s_idle;
			endcase
			end
		end
    	s_cal_2: begin
			if(counter_cal==4+3+3)  n_state = s_cal_leng;
			else                    n_state = s_cal_2;
		end
		s_cal_4: begin
			if(counter_cal==16+8)   n_state = s_cal_leng;
			else          		      n_state = s_cal_4;
		end
		s_cal_8: begin
			if(counter_cal==64+12)  n_state = s_cal_leng;
			else            		    n_state = s_cal_8;
		end
		s_cal_leng: begin
			if(counter_cal==0)      n_state = s_output_len;
			else                    n_state = s_cal_leng;
		end
    	s_output_len: begin
    	  if(counter_out_len==0)  n_state = s_output_val;
				else                    n_state = s_output_len;
    	end
    	s_output_val: begin
    	  if(counter_out_size == size*2-1)
    	    n_state = s_idle;
    	  else if(fsm_out_flag==1)
    	    n_state = s_output_len;
		  else
    	    n_state = s_output_val;
    	end
		default: n_state = s_idle;
	endcase
end
//---------------------------------------------------------------------
//   counter
//---------------------------------------------------------------------
//================= Lab 11 new  counter : input==================//
// counter_input
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_input <= 0;
	else begin
    if(n_state == s_input)
		  counter_input <= counter_input + 1;
    else
      counter_input <= 0;
	end
end

// counter_input_idx
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_input_idx <= 0;
	else begin
    if(n_state == s_choose)
			counter_input_idx <= counter_input_idx + 1;
    else
      counter_input_idx <= 0;
	end
end

//input index (SRAM) counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		counter_sram <= 0;
	else begin
    case(n_state)
		  s_idle:   counter_sram <= 0;
		  s_input: if(counter_input!=0 && counter_input%16==0) counter_sram <= counter_sram + 1;
		  s_choose: begin
		  	if(counter_sram==0)counter_sram <= 0;
		  	else counter_sram <= counter_sram + 1;
		  end
		  default:  counter_sram <= 0;
    endcase
  end
end

//================= Lab 11 new  counter : output==================//
// number of output length (counter_out_len)
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
    counter_out_len <= 0;
	else begin
    if(n_state == s_output_len && counter_out_len < 6)
        counter_out_len <= counter_out_len + 1;
    else if(n_state == s_output_val)
        counter_out_len <= 1;
    else
        counter_out_len <= 0;
  end
end

// number of output bit (counter_out)
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
    counter_out_val <= 0;
	else begin
    if(n_state == s_output_val)
      counter_out_val <= counter_out_val + 1;
    else
      counter_out_val <= 2;
  end
end

// counter_out_size
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
    counter_out_size <= 0;
	else begin
    if(n_state == s_output_val && out_flag==1) begin
      case(size)
        2: begin
          if(counter_out_size < 4)
            counter_out_size <= counter_out_size + 1;
        end
        4: begin
          if(counter_out_size < 16)
            counter_out_size <= counter_out_size + 1;
        end
        8: begin
          if(counter_out_size < 64)
            counter_out_size <= counter_out_size + 1;
        end
      endcase
    end
    else if(n_state == s_idle)
      counter_out_size <= 0;
  end
end

// out flag
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
    	out_flag <= 0;
	else begin
		if(n_state == s_output_len)begin
			if(counter_out_len==6 && diagonal_reg[counter_out_size]==0)
				out_flag <= 1;
    	    else
    	      	out_flag <= 0;
		end
    	else if(n_state == s_output_val)begin
    	  	//================== post cycle ==================//
    	  	//case(size)
    	  	//  2: begin
    	  	//    if(output_length[2-counter_out_size] == counter_out_val)
    	  	//      out_flag <= 1;
    	  	//    else
    	  	//      out_flag <= 0;
    	  	//  end
    	  	//  4: begin
    	  	//    if(output_length[6-counter_out_size] == counter_out_val)
    	  	//      out_flag <= 1;
    	  	//    else
    	  	//      out_flag <= 0;
    	  	//  end
    	  	//  8: begin
    	  	//    if(output_length[14-counter_out_size] == counter_out_val)
    	  	//      out_flag <= 1;
    	  	//    else
    	  	//      out_flag <= 0;
    	  	//  end
    	  	//endcase
    	  	//================================================//

    	  	//================== pre cycle ==================//
    	  	if(output_length[counter_out_size] == counter_out_val)
    	    	out_flag <= 1;
    	  	else
    	    	out_flag <= 0;
    	  	//===============================================//
    	end
    	else
    	  	out_flag <= 0;
  	end
end

// fsm out flag
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
    fsm_out_flag <= 0;
	else begin
    fsm_out_flag <= out_flag;
  end
end

//===============================================//
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
		default : counter_col <= 0;
		endcase
	end
end
// calculate counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		counter_cal <= 0;
	else begin
      case(n_state)
			  s_idle:   counter_cal <= 0;
			  // Since SRAM output delay, counter + 2
			  s_cal_2:  begin
		  		if(counter_cal < 12/*4+8*/)counter_cal <= counter_cal + 1;
			   	else counter_cal <= 0;
			  end
			  s_cal_4:  begin
		  		if(counter_cal < 24/*16+8*/)counter_cal <= counter_cal + 1;
			   	else counter_cal <= 0;
			  end
			  s_cal_8:  begin
		  		if(counter_cal < 76/*64+12*/)counter_cal <= counter_cal + 1;
			   	else counter_cal <= 0;
			  end
			  s_cal_leng: counter_cal <=0;
              default:  counter_cal <= 0;
      endcase
    end
end

// number of round
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter_round <= 0;
	else begin
        case(n_state)
			s_idle:  counter_round <= 0;
			s_choose: if(counter_input_idx==1)counter_round <= counter_round + 1;
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

//adder A8 (.inst_A(y_reg[8]),  .inst_B(A_wire[6]),  .SUM_inst(A_wire[7]));
//adder A9 (.inst_A(y_reg[9]),  .inst_B(A_wire[7]),  .SUM_inst(A_wire[8]));
//adder A10(.inst_A(y_reg[10]), .inst_B(A_wire[8]),  .SUM_inst(A_wire[9]));
//adder A11(.inst_A(y_reg[11]), .inst_B(A_wire[9]),  .SUM_inst(A_wire[10]));
//adder A12(.inst_A(y_reg[12]), .inst_B(A_wire[10]), .SUM_inst(A_wire[11]));
//adder A13(.inst_A(y_reg[13]), .inst_B(A_wire[11]), .SUM_inst(A_wire[12]));
//adder A14(.inst_A(y_reg[14]), .inst_B(A_wire[12]), .SUM_inst(A_wire[13]));
//adder A15(.inst_A(y_reg[15]), .inst_B(A_wire[13]), .SUM_inst(A_wire[14]));
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