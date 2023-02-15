module TT(
    //Input Port
    clk,
    rst_n,
    in_valid,
    source,
    destination,

    //Output Port
    out_valid,
    cost
    );

input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

//==============================================//
//             Parameter and Integer            //
//==============================================//

integer  i, j;

//==============================================//
//            FSM State Declaration             //
//==============================================//

parameter s_idle = 2'd0;
parameter s_input = 2'd1;
parameter s_cal = 2'd2;
parameter s_output = 2'd3;

//==============================================//
//                 reg declaration              //
//==============================================//

reg cnt;
reg [3:0] level; 
reg trace_done, output_done;
reg [2:0] c_state, n_state;
reg [3:0] Source, Destination;
reg [4:0] station1,station2;
reg path_table [15:0][15:0];
reg path[15:0];

//==============================================//
//             Current State Block              //
//==============================================//

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        c_state <= s_idle; /* initial state */
    else       
        c_state <= n_state;
end

//==============================================//
//              Next State Block                //
//==============================================//

always@(*) begin
    case(c_state)
    s_idle:  if(in_valid)   n_state = s_input;
	         else 	        n_state = s_idle;
   	s_input: if(in_valid)   n_state = s_input;
             else if(trace_done) n_state = s_output;
             else 	        n_state = s_cal;
    s_cal: 	 if(trace_done) n_state = s_output;
          	 else           n_state = s_cal;
    s_output:if(output_done)n_state = s_idle;
         	 else           n_state = s_output;
	default: n_state = c_state;
   	endcase
end

//==============================================//
//                  Input Block                 //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Source <= 5'd16;
        Destination <= 5'd16; 
    end
    else begin
    case(c_state)
   	    s_idle: begin
            if(in_valid) begin
                Source <= source;
                Destination <= destination;
            end
        end
    endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        station1 <= 5'd16;
        station2 <= 5'd16;
    end
    else begin
   	case(c_state)
   	    s_input: begin
            if(in_valid) begin
                station1 <= source;
                station2 <= destination;
            end
        end
        default begin
            station1 <= 5'd16;
            station2 <= 5'd16;
        end
    endcase
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        for(i=0; i<16; i=i+1)
            for(j=0; j <16; j=j+1)
                path_table[i][j] <= 0;
    end
    else begin
        case(c_state)
        s_idle: begin
            for(i=0; i<16; i=i+1)
                for(j=0; j <16; j=j+1)
                    path_table[i][j] <= 0;
        end
        s_input: begin   
            path_table[station1][station2] <= 1'd1;
            path_table[station2][station1] <= 1'd1; 
        end
        s_cal: begin   
           for(i=0; i<16; i=i+1)
                for(j=0; j <16; j=j+1)
                    path_table[i][j] <= path_table[i][j];
        end
        s_output: begin   
            for(i=0; i<16; i=i+1)
                for(j=0; j <16; j=j+1)
                    path_table[i][j] <= 0;
        end
        endcase
    end
end

//==============================================//
//              Calculation Block               //
//==============================================//

integer row;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) for(i=0; i<16; i=i+1) path[i] <= 1'b0; 
    else begin
        case(c_state)
        s_idle: for(i=0; i<16; i=i+1) path[i] <= 1'b0; 
        s_input: begin
            if(station1==Source) path[station2] <= 1'b1;
            else if(station2==Source) path[station1] <= 1'b1;
        end
        s_cal: begin
            for(row=0 ; row<16; row=row+1) begin
                path[row] <= (path_table[row][15]&path[15])|(path_table[row][14]&path[14])|(path_table[row][13]&path[13])|(path_table[row][12]&path[12])|(path_table[row][11]&path[11])|(path_table[row][10]&path[10])|(path_table[row][9]&path[9])|(path_table[row][8]&path[8])|(path_table[row][7]&path[7])|(path_table[row][6]&path[6])|(path_table[row][5]&path[5])|(path_table[row][4]&path[4])|(path_table[row][3]&path[3])|(path_table[row][2]&path[2])|(path_table[row][1]&path[1])|(path_table[row][0]&path[0]);
            end
        end
        endcase
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) trace_done <= 1'd0;
    else begin
        case(c_state)
        s_idle: trace_done <= 1'd0;
        s_input: begin
            if(path[Destination]!=0) trace_done <= 1'd1;
            else if(level==15) trace_done <= 1'd1;
            else trace_done <= 1'd0;
        end
        s_cal: begin
            if(path[Destination]!=0) trace_done <= 1'd1;
            else if(level==15) trace_done <= 1'd1;
            else trace_done <= 1'd0;
        end
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) level <= 4'd0;
    else                
    case(c_state)
    s_input: level <= 4'd1;
	s_cal: if(!trace_done) level <= level + 4'd1; 
    default: level <= 4'd0;
    endcase
end

//==============================================//
//                Output Block                  //
//==============================================//
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_valid <= 1'd0; /* remember to reset */
    else
    case(c_state)
    s_output: begin
        if(cnt==0)begin 
            out_valid <= 1'd1;
        end
        else out_valid <= 1'd0;
    end
    default:  out_valid <= 1'd0;
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) cost <= 0; /* remember to reset */
    else begin
    case(c_state)
    s_output: begin
        if(path[Destination]==0) cost <= 0;
        else if(level == 1) cost <= 1;
        else cost <= level-1;
    end
    default: cost <= 0;
    endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)  output_done <= 1'd0;
    else begin
    case(c_state)
    s_output: begin
        if(cnt==0) output_done <= 1'd1;
        else output_done <= 1'd0;
    end
    default: output_done <= 1'd0;
    endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 1'd0;
    else begin
    case(c_state)
    s_output: cnt <= cnt + 1'd1;
    default:  cnt <= 1'd0;
    endcase
    end
end
endmodule
