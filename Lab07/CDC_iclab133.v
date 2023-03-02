`include "synchronizer.v"
`include "syn_XOR.v"
module CDC(
	//Input Port
	clk1,
    clk2,
    clk3,
	rst_n,
	in_valid1,
	in_valid2,
	user1,
	user2,

    //Output Port
    out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input 		clk1, clk2, clk3, rst_n;
input 		in_valid1, in_valid2;
input [3:0]	user1, user2;

output reg	out_valid1, out_valid2;
output reg	equal, exceed, winner;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
//----clk1----
reg flag_tx1,flag_tx2,flag_tx3;

reg [5:0] remain_table_1;
reg [5:0] remain_table [9:0];

reg restart;
reg [2:0] epoch_counter; //max 5
reg [3:0] card_counter;  //max 10

reg [1:0] c_state,n_state;

reg [5:0] total_1, total_2; //max 49
reg [5:0] total_1_tmp;

reg [6:0] equal_r, exceed_r;
reg [6:0] equal_ans1, equal_ans2;
reg [6:0] exceed_ans1, exceed_ans2;

reg [1:0] winner_r;
//----clk2----

//----clk3----
wire flag_rx1,flag_rx2,flag_rx3;
reg finish;
//wire flag_rx1_r,flag_rx2_r;
reg [2:0] out_counter;
reg [2:0] c_state_3, n_state_3;

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
// clk 1
parameter s_idle  = 'd0;
parameter s_user1 = 'd1;
parameter s_user2 = 'd2;

// clk 3
parameter s_wait  = 'd0;
parameter s_output1 = 'd1;
parameter s_output2 = 'd2;
parameter s_result = 'd3;
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
//============================================
//   clk1 domain
//============================================
//================ FSM ================//
always @(posedge clk1 or negedge rst_n)begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle:  if(in_valid1)      n_state = s_user1;
	      	 else    	        n_state = s_idle;
    s_user1: if(in_valid1) 		n_state = s_user1;
             else if(in_valid2) n_state = s_user2;
			 else  			    n_state = s_idle;
    s_user2: if(in_valid1) 		n_state = s_user1;
             else if(in_valid2) n_state = s_user2;
			 else  			    n_state = s_idle;
    default: n_state = c_state;
    endcase
end
//================ reset setting ================//
// restart
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		restart <= 0;
	else begin
		if(card_counter==8 && epoch_counter==5)
			restart <= 1;
		else
			restart <= 0;
	end
end

// epoch counter
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		epoch_counter <= 1;
	else begin
		if(n_state==s_idle)
			epoch_counter <= 1;
		else if(card_counter==10 && epoch_counter < 5)
			epoch_counter <= epoch_counter + 1;
		else if(card_counter==10 && epoch_counter == 5)
			epoch_counter <= 1;
	end
end

// card counter
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		card_counter <= 0;
	else begin
		if(n_state==s_idle)
			card_counter <= 0;
		else if((in_valid1 || in_valid2) && card_counter<10)
			card_counter <= card_counter + 1;
		else
			card_counter <= 1;
	end
end

//================ calculate number of card ================//
// user 1
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		total_1 <= 0;
	else begin
		case(n_state)
		s_idle:  total_1 <= 0;
		s_user1: total_1 <= (user1>10) ? total_1 + 1 :total_1 + user1;
		s_user2: if(card_counter==9)
				 	total_1 <= 0;
		endcase
	end
end
// user 1 tmp (to compare with user 2)
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		total_1_tmp <= 0;
	else begin
		total_1_tmp <= total_1;
	end
end
// user 2
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		total_2 <= 0;
	else begin
		case(n_state)
		s_idle:  total_2 <= 0;
		s_user1: if(card_counter==4)
				 	total_2 <= 0;
		s_user2: total_2 <= (user2>10) ? total_2 + 1 : total_2 + user2;
		endcase
	end
end
//================ calculate probability ================//
//equal
always @(*)begin
	if(in_valid1)begin
		if(total_1 >= 21 || total_1 < 11) equal_r = 0;
		else if(total_1 == 11 ) equal_r = remain_table['d20-total_1] * 100 / remain_table[0];
		else equal_r = (remain_table['d20-total_1] - remain_table['d21-total_1]) * 100 / remain_table[0];
	end
	else if(in_valid2)begin
		if(total_2 >= 21 || total_2 < 11) equal_r = 0;
		else if(total_2 == 11) equal_r = remain_table['d20-total_2] * 100 / remain_table[0];
		else equal_r = (remain_table['d20-total_2] - remain_table['d21-total_2]) * 100 / remain_table[0];
	end
	else equal_r = 0;
end

// the fourth card equal 21
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		equal_ans1 <= 0;
	else begin
		if(card_counter==3 || card_counter==8)
			equal_ans1 <= equal_r;
	end
end
// the fifth card equal 21
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		equal_ans2 <= 0;
	else begin
		if(card_counter==4 || card_counter==9)
			equal_ans2 <= equal_r;
	end
end

//exceed
always @(*)begin
	if(in_valid1)begin
		if(total_1 >= 21) exceed_r = 'd100;
		else if(total_1 <= 11) exceed_r = 'd0;
		else exceed_r = (remain_table['d21-total_1]) * 100 / remain_table[0];
	end
	else if(in_valid2)begin
		if(total_2 >= 21) exceed_r = 'd100;
		else if(total_2 <= 11) exceed_r = 'd0;
		else exceed_r = (remain_table['d21-total_2]) * 100 / remain_table[0];
	end
	else exceed_r = 0;
end
// the fourth card exceed 21
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		exceed_ans1 <= 0;
	else begin
		if(card_counter==3 || card_counter==8)
			exceed_ans1 <= exceed_r;
	end
end
// the fifth card exceed 21
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		exceed_ans2 <= 0;
	else begin
		if(card_counter==4 || card_counter==9)
			exceed_ans2 <= exceed_r;
	end
end

// winner
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		winner_r <= 0;
	else begin
		if(card_counter==10)begin
			if(total_1_tmp >21)begin
				if(total_2 > 21) winner_r <= 0;
				else winner_r <= 3;
			end
			else if(total_2 > 21)begin
				if(total_1 > 21) winner_r <= 0;
				else winner_r <= 2;
			end
			else if(total_1_tmp == total_2) winner_r <= 0;
			else if (total_1_tmp > total_2) winner_r <= 2;
			else if(total_1_tmp < total_2)winner_r <= 3;
		end
	end
end
//================ remain table ================//
// remain_table_10
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[9] <= 4;
	else if(restart)
		remain_table[9] <= 4;
	else begin
		case(n_state)
			s_idle: remain_table[9] <= 4;
			default: begin
				if((user1==10 && in_valid1)||(user2==10&& in_valid2))
					remain_table[9] <= remain_table[9] - 1;
			end
		endcase
	end
end
// remain_table_9
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[8] <= 8;
	else if(restart)
		remain_table[8] <= 8;
	else begin
		case(n_state)
			s_idle: remain_table[8] <= 8;
			default: begin
				if((user1<11 && user1>=9 && in_valid1) || (user2<11 && user2>=9 && in_valid2))
					remain_table[8] <= remain_table[8] - 1;
			end
		endcase
	end
end
// remain_table_8
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[7] <= 12;
	else if(restart)
		remain_table[7] <= 12;
	else begin
		case(n_state)
			s_idle: remain_table[7] <= 12;
			default: begin
				if((user1<11 && user1>=8 && in_valid1 ) || (user2<11 && user2>=8 && in_valid2 ))
					remain_table[7] <= remain_table[7] - 1;
			end
		endcase
	end
end
// remain_table_7
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[6] <= 16;
	else if(restart)
		remain_table[6] <= 16;
	else begin
		case(n_state)
			s_idle: remain_table[6] <= 16;
			default: begin
				if((user1<11 && user1>=7 && in_valid1 ) || (user2<11 && user2>=7 && in_valid2))
					remain_table[6] <= remain_table[6] - 1;
			end
		endcase
	end
end
// remain_table_6
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[5] <= 20;
	else if(restart)
		remain_table[5] <= 20;
	else begin
		case(n_state)
			s_idle: remain_table[5] <= 20;
			default: begin
				if((user1<11 && user1>=6 && in_valid1) || (user2<11 && user2>=6 && in_valid2))
					remain_table[5] <= remain_table[5] - 1;
			end
		endcase
	end
end
// remain_table_5
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[4] <= 24;
	else if(restart)
		remain_table[4] <= 24;
	else begin
		case(n_state)
			s_idle: remain_table[4] <= 24;
			default: begin
				if((user1<11 && user1>=5 && in_valid1)  || (user2<11 &&user2>=5 && in_valid2))
					remain_table[4] <= remain_table[4] - 1;
			end
		endcase
	end
end
// remain_table_4
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[3] <= 28;
	else if(restart)
		remain_table[3] <= 28;
	else begin
		case(n_state)
			s_idle: remain_table[3] <= 28;
			default: begin
				if((user1<11 && user1>=4 && in_valid1) || (user2<11 && user2>=4 && in_valid2))
					remain_table[3] <= remain_table[3] - 1;
			end
		endcase
	end
end
// remain_table_3
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[2] <= 32;
	else if(restart)
		remain_table[2] <= 32;
	else begin
		case(n_state)
			s_idle: remain_table[2] <= 32;
			default: begin
				if((user1<11 && user1>=3 && in_valid1) || (user2<11 && user2>=3 && in_valid2))
					remain_table[2] <= remain_table[2] - 1;
			end
		endcase
	end
end
// remain_table_2
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[1] <= 36;
	else if(restart)
		remain_table[1] <= 36;
	else begin
		case(n_state)
			s_idle: remain_table[1] <= 36;
			default: begin
				if((user1<11 && user1>=2 && in_valid1) || (user2<11 && user2>=2 && in_valid2))
					remain_table[1] <= remain_table[1] - 1;
			end
		endcase
	end
end
// remain_table_1 (total cards)
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		remain_table[0] <= 52;
	else if(restart)
		remain_table[0] <= 52;
	else begin
		case(n_state)
			s_idle: remain_table[0] <= 52;
			default:remain_table[0] <= remain_table[0]- 1;
		endcase
	end
end

//============================================
//   clk3 domain
//============================================
// FSM
always @(posedge clk3 or negedge rst_n)begin
    if(!rst_n)
        c_state_3 <= s_wait;
    else
        c_state_3 <= n_state_3;
end

always@(*) begin
    case(c_state_3)
    s_wait:    if(flag_rx1)        n_state_3 = s_output1;
			   else if(flag_rx2)   n_state_3 = s_output2;
			   else if(flag_rx3)   n_state_3 = s_result;
	      	   else    	           n_state_3 = s_wait;
    s_output1: if(out_counter==7)  n_state_3 = s_wait;
               else                n_state_3 = s_output1;
	s_output2: if(out_counter==7)  n_state_3 = s_wait;
               else                n_state_3 = s_output2;
	s_result:  if(winner_r[1]==0||out_counter==2)
							       n_state_3 = s_wait;
               else                n_state_3 = s_result;
    default: n_state_3 = c_state_3;
    endcase
end
// out_counter
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
    	out_counter <= 0;
	end
	else begin
		case(n_state_3)
		s_wait    : out_counter <= 0;
		s_output1 : out_counter <= out_counter + 1;
		s_output2 : out_counter <= out_counter + 1;
		s_result  : out_counter <= out_counter + 1;
		endcase
	end
end
//finish
/*always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
    	finish <= 0;
	end
	else begin
		if(winner_r[1]==0) finish <= 1;
		else finish <= 0;
	end
end*/
//out_valid1 //equal & exceed
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
    	out_valid1 <= 0;
	end
	else begin
		case(n_state_3)
			s_output1 : out_valid1 <= 1;
			s_output2 : out_valid1 <= 1;
			default   : out_valid1 <= 0;
		endcase
	end
end
//out_valid2 //result
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
       out_valid2 <= 0;
	end
	else begin
		case(n_state_3)
			s_result : out_valid2 <= 1;
			default  : out_valid2 <= 0;
		endcase
	end
end
//equal
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
       equal <= 0;
	end
	else begin
		case(n_state_3)
			s_output1:begin
				case(out_counter)
				0: equal <= equal_ans1[6];
				1: equal <= equal_ans1[5];
				2: equal <= equal_ans1[4];
				3: equal <= equal_ans1[3];
				4: equal <= equal_ans1[2];
				5: equal <= equal_ans1[1];
				6: equal <= equal_ans1[0];
				endcase
			end
			s_output2: begin
				case(out_counter)
				0: equal <= equal_ans2[6];
				1: equal <= equal_ans2[5];
				2: equal <= equal_ans2[4];
				3: equal <= equal_ans2[3];
				4: equal <= equal_ans2[2];
				5: equal <= equal_ans2[1];
				6: equal <= equal_ans2[0];
				endcase
			end
			default: equal <= 0;
		endcase
	end
end
//exceed
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
       exceed <= 0;
	end
	else begin
		case(n_state_3)
			s_output1:begin
				case(out_counter)
				0: exceed <= exceed_ans1[6];
				1: exceed <= exceed_ans1[5];
				2: exceed <= exceed_ans1[4];
				3: exceed <= exceed_ans1[3];
				4: exceed <= exceed_ans1[2];
				5: exceed <= exceed_ans1[1];
				6: exceed <= exceed_ans1[0];
				endcase
			end
			s_output2: begin
				case(out_counter)
				0: exceed <= exceed_ans2[6];
				1: exceed <= exceed_ans2[5];
				2: exceed <= exceed_ans2[4];
				3: exceed <= exceed_ans2[3];
				4: exceed <= exceed_ans2[2];
				5: exceed <= exceed_ans2[1];
				6: exceed <= exceed_ans2[0];
				endcase
			end
			default: exceed <= 0;
		endcase
	end
end
//winner
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
       winner <= 0;
	end
	else begin
		if(n_state_3==s_result)begin
			case(out_counter)
			0: winner <= winner_r[1];
			1: winner <= winner_r[0];
			endcase
		end
		else
			winner <= 0;
	end
end

//---------------------------------------------------------------------
//   syn_XOR
//---------------------------------------------------------------------
// flag_tx1
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		flag_tx1 <= 0;
	else begin
		case(n_state)
			s_user1: if(card_counter==3) flag_tx1 <= 1;
					 else flag_tx1 <= 0;
			s_user2: if(card_counter==7) flag_tx1 <= 1;
					 else flag_tx1 <= 0;
			default: flag_tx1 <= 0;

		endcase
	end
end
// flag_tx2
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		flag_tx2 <= 0;
	else begin
		case(n_state)
			s_user1: if(card_counter==4) flag_tx2 <= 1;
					 else flag_tx2 <= 0;
			s_user2: if(card_counter==8) flag_tx2 <= 1;
					 else flag_tx2 <= 0;
		endcase
	end
end
// flag_tx3
always @(posedge clk1 or negedge rst_n)begin
	if(!rst_n)
		flag_tx3 <= 0;
	else begin
		if(card_counter==9)flag_tx3 <= 1;
		else flag_tx3 <= 0;
	end
end

syn_XOR u_syn_XOR1(.IN(flag_tx1),.OUT(flag_rx1),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_syn_XOR2(.IN(flag_tx2),.OUT(flag_rx2),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_syn_XOR3(.IN(flag_tx3),.OUT(flag_rx3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));

endmodule