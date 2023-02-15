module BP(
  clk,
  rst_n,
  in_valid,
  guy,
  in0,
  in1,
  in2,
  in3,
  in4,
  in5,
  in6,
  in7,

  out_valid,
  out
);

//---------------------------------------------------------------------
//   Port Declaration
//---------------------------------------------------------------------
input             clk, rst_n;
input             in_valid;
input       [2:0] guy;
input       [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
output reg        out_valid;
output reg  [1:0] out;

//---------------------------------------------------------------------
//  Parameter and Integer
//---------------------------------------------------------------------
integer j;

//---------------------------------------------------------------------
//   FSM State Declaration
//---------------------------------------------------------------------
parameter s_idle   = 2'd0;
parameter s_input  = 2'd1;
parameter s_output = 2'd2;

//---------------------------------------------------------------------
//  Reg declaration
//---------------------------------------------------------------------
reg trace_done, output_done;
reg [5:0] cnt;
reg No_Obstacles;
reg [2:0] c_state, n_state;
reg [2:0] guy_pos;
reg [3:0] obstacle_pos;
reg [1:0] obstacle_type;
reg [1:0] now_row [7:0];
reg [125:0] ans;

//---------------------------------------------------------------------
//  Current State Block
//---------------------------------------------------------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

//---------------------------------------------------------------------
//  Next State Block
//---------------------------------------------------------------------
always@(*) begin
  case(c_state)
  s_idle:  if(in_valid)   n_state = s_input;
	         else 	        n_state = s_idle;
  s_input: if(in_valid)   n_state = s_input;
           else           n_state = s_output;
  s_output:if(output_done)n_state = s_idle;
        	 else           n_state = s_output;
	default: n_state = c_state;
  endcase
end

//---------------------------------------------------------------------
//   Input Logic
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        now_row[0] <= 2'd0;
        now_row[1] <= 2'd0;
        now_row[2] <= 2'd0;
        now_row[3] <= 2'd0;
        now_row[4] <= 2'd0;
        now_row[5] <= 2'd0;
        now_row[6] <= 2'd0;
        now_row[7] <= 2'd0;
    end
    else begin
   	case(n_state)
        s_input: begin
            if(in_valid) begin
                now_row[0] <= in0;
                now_row[1] <= in1;
                now_row[2] <= in2;
                now_row[3] <= in3;
                now_row[4] <= in4;
                now_row[5] <= in5;
                now_row[6] <= in6;
                now_row[7] <= in7;
            end
        end
        default begin
            now_row[0] <= 2'd0;
            now_row[1] <= 2'd0;
            now_row[2] <= 2'd0;
            now_row[3] <= 2'd0;
            now_row[4] <= 2'd0;
            now_row[5] <= 2'd0;
            now_row[6] <= 2'd0;
            now_row[7] <= 2'd0;
        end
    endcase
    end
end

//---------------------------------------------------------------------
//   Calculation Block
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n)begin
  if(!rst_n) guy_pos <= 3'd0;
  else begin
    case(c_state)
   	s_idle: if(in_valid) guy_pos <= guy;
    s_input: if(!No_Obstacles) guy_pos <= obstacle_pos;
    endcase
  end
end

always @(posedge clk or negedge rst_n)begin
  if(!rst_n) begin
    ans <= 126'd0;
  end
  else begin
    case(n_state)
    s_input: begin
      ans <= ans >> 2;
      if(!No_Obstacles)begin
        case(obstacle_type)
          1: begin
            if(obstacle_pos < guy_pos)begin
              case(guy_pos - obstacle_pos)
                1: ans <= {2'b11, 2'b10, ans[123:2]};
                2: ans <= {2'b11, {2{2'b10}}, ans[121:2]};
                3: ans <= {2'b11, {3{2'b10}}, ans[119:2]};
                4: ans <= {2'b11, {4{2'b10}}, ans[117:2]};
                5: ans <= {2'b11, {5{2'b10}}, ans[115:2]};
                6: ans <= {2'b11, {6{2'b10}}, ans[113:2]};
                7: ans <= {2'b11, {7{2'b10}}, ans[111:2]};
              endcase
            end
            else if(obstacle_pos > guy_pos)begin
              case(obstacle_pos - guy_pos)
                1: ans <= {2'b11, 2'b01, ans[123:2]};
                2: ans <= {2'b11, {2{2'b01}}, ans[121:2]};
                3: ans <= {2'b11, {3{2'b01}}, ans[119:2]};
                4: ans <= {2'b11, {4{2'b01}}, ans[117:2]};
                5: ans <= {2'b11, {5{2'b01}}, ans[115:2]};
                6: ans <= {2'b11, {6{2'b01}}, ans[113:2]};
                7: ans <= {2'b11, {7{2'b01}}, ans[111:2]};
              endcase
            end
            else if(obstacle_pos == guy_pos) begin
              ans <= {2'b11, ans[125:2]};
            end
          end
          2: begin
            if(obstacle_pos < guy_pos)begin
              case(guy_pos - obstacle_pos)
                1: ans <= {2'b10, ans[125:2]};
                2: ans <= {{2{2'b10}}, ans[123:2]};
                3: ans <= {{3{2'b10}}, ans[121:2]};
                4: ans <= {{4{2'b10}}, ans[119:2]};
                5: ans <= {{5{2'b10}}, ans[117:2]};
                6: ans <= {{6{2'b10}}, ans[115:2]};
                7: ans <= {{7{2'b10}}, ans[113:2]};
              endcase
            end
            else if(obstacle_pos > guy_pos)begin
              case(obstacle_pos - guy_pos)
                1: ans <= {2'b01, ans[125:2]};
                2: ans <= {{2{2'b01}}, ans[123:2]};
                3: ans <= {{3{2'b01}}, ans[121:2]};
                4: ans <= {{4{2'b01}}, ans[119:2]};
                5: ans <= {{5{2'b01}}, ans[117:2]};
                6: ans <= {{6{2'b01}}, ans[115:2]};
                7: ans <= {{7{2'b01}}, ans[113:2]};
              endcase
            end
          end
        endcase
      end
    end
    s_output: begin
      ans <= ans >> 2;
      if(cnt==63)begin
        if(!No_Obstacles)begin
        case(obstacle_type)
          1: begin
            if(obstacle_pos < guy_pos)begin
              case(guy_pos - obstacle_pos)
                1: ans <= {2'b11, 2'b10, ans[123:2]};
                2: ans <= {2'b11, {2{2'b10}}, ans[121:2]};
                3: ans <= {2'b11, {3{2'b10}}, ans[119:2]};
                4: ans <= {2'b11, {4{2'b10}}, ans[117:2]};
                5: ans <= {2'b11, {5{2'b10}}, ans[115:2]};
                6: ans <= {2'b11, {6{2'b10}}, ans[113:2]};
                7: ans <= {2'b11, {7{2'b10}}, ans[111:2]};
              endcase
            end
            else if(obstacle_pos > guy_pos)begin
              case(obstacle_pos - guy_pos)
                1: ans <= {2'b11, 2'b01, ans[123:2]};
                2: ans <= {2'b11, {2{2'b01}}, ans[121:2]};
                3: ans <= {2'b11, {3{2'b01}}, ans[119:2]};
                4: ans <= {2'b11, {4{2'b01}}, ans[117:2]};
                5: ans <= {2'b11, {5{2'b01}}, ans[115:2]};
                6: ans <= {2'b11, {6{2'b01}}, ans[113:2]};
                7: ans <= {2'b11, {7{2'b01}}, ans[111:2]};
              endcase
            end
            else if(obstacle_pos == guy_pos) begin
              ans <= {2'b11, ans[125:2]};
            end
          end
          2: begin
            if(obstacle_pos < guy_pos)begin
              case(guy_pos - obstacle_pos)
                1: ans <= {2'b10, ans[125:2]};
                2: ans <= {{2{2'b10}}, ans[123:2]};
                3: ans <= {{3{2'b10}}, ans[121:2]};
                4: ans <= {{4{2'b10}}, ans[119:2]};
                5: ans <= {{5{2'b10}}, ans[117:2]};
                6: ans <= {{6{2'b10}}, ans[115:2]};
                7: ans <= {{7{2'b10}}, ans[113:2]};
              endcase
            end
            else if(obstacle_pos > guy_pos)begin
              case(obstacle_pos - guy_pos)
                1: ans <= {2'b01, ans[125:2]};
                2: ans <= {{2{2'b01}}, ans[123:2]};
                3: ans <= {{3{2'b01}}, ans[121:2]};
                4: ans <= {{4{2'b01}}, ans[119:2]};
                5: ans <= {{5{2'b01}}, ans[117:2]};
                6: ans <= {{6{2'b01}}, ans[115:2]};
                7: ans <= {{7{2'b01}}, ans[113:2]};
              endcase
            end
          end
        endcase
      end
      end
    end
    endcase
  end
end

always @(negedge clk or negedge rst_n)begin
    if(!rst_n) begin
      obstacle_pos <= 0;
      obstacle_type <= 0;
    end
    else begin
    case(c_state)
      s_input: begin
          if(now_row[0]!=3 && now_row[0]!=0 )begin
            obstacle_pos <= 0;
            obstacle_type <= now_row[0];
          end
          else if(now_row[1]!=3 && now_row[1]!=0 )begin
            obstacle_pos <= 1;
            obstacle_type <= now_row[1];
          end
          else if(now_row[2]!=3 && now_row[2]!=0 )begin
            obstacle_pos <= 2;
            obstacle_type <= now_row[2];
          end
          else if(now_row[3]!=3 && now_row[3]!=0 )begin
            obstacle_pos <= 3;
            obstacle_type <= now_row[3];
          end
          else if(now_row[4]!=3 && now_row[4]!=0 )begin
            obstacle_pos <= 4;
            obstacle_type <= now_row[4];
          end
          else if(now_row[5]!=3 && now_row[5]!=0 )begin
            obstacle_pos <= 5;
            obstacle_type <= now_row[5];
          end
          else if(now_row[6]!=3 && now_row[6]!=0 )begin
            obstacle_pos <= 6;
            obstacle_type <= now_row[6];
          end
          else if(now_row[7]!=3 && now_row[7]!=0 )begin
            obstacle_pos <= 7;
            obstacle_type <= now_row[7];
          end
      end
      default: begin
        obstacle_pos <= 0;
        obstacle_type <= 0;
      end
    endcase
  end
end

always @(posedge clk or negedge rst_n)begin
  if(!rst_n) No_Obstacles <= 0;
  else begin
    case(n_state)
   	s_input: begin
      if(in_valid)begin
        if(in0==2'b0) No_Obstacles <= 1;
        else No_Obstacles <= 0;
      end
    end
    endcase
  end
end

//---------------------------------------------------------------------
//   Output Logic
//---------------------------------------------------------------------
always@(posedge clk or negedge rst_n) begin
  if(!rst_n)
      out_valid <= 1'd0;
  else begin
  case(n_state)
  s_output: out_valid <= 1'd1;
  default:  out_valid <= 1'd0;
  endcase
  end
end

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)
		out <= 2'd0;
	else begin
		case(c_state)
    s_input: if(cnt==63) out <= ans[3:2];
    s_output: begin
        out <= ans[3:2];
    end
    default: out <= 2'd0;
    endcase
  end
end

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)
		output_done <= 1'b0;
	else begin
		case(n_state)
    s_output: if (cnt==61) output_done <= 1'b1;
    default output_done <= 1'b0;
    endcase
  end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 1'd0;
    else begin
    case(c_state)
    s_input: cnt <= cnt + 1'd1;
    s_output: cnt <= cnt + 1'd1;
    default:  cnt <= 1'd0;
    endcase
    end
end

endmodule
