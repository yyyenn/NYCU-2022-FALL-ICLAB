
`ifdef RTL
    `timescale 1ns/10ps
    `include "BP.v"
    `define CYCLE_TIME 10.0
`endif
`ifdef GATE
    `timescale 1ns/10ps
    `include "BP_SYN.v"
    `define CYCLE_TIME 10.0
`endif

module PATTERN(
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

//================================================================//
//                  input and output declaration                  //
//================================================================//
/* Input to design */
output reg       clk, rst_n;
output reg       in_valid;
output reg [2:0] guy;
output reg [1:0] in0, in1, in2, in3, in4, in5, in6, in7;

/* Output to pattern */
input            out_valid;
input      [1:0] out;

//================================================================//
//                      parameters & integer                      //
//================================================================//
real CYCLE = `CYCLE_TIME;
integer i,j;
parameter NUM_PATTERN = 300;
parameter LEN = 64;
integer No_Obstacles = 1;

integer guy_pos;
integer empty_cnt;
integer empty_pos;
integer obstacle_type;
integer latency;
integer total_latency=0;
integer cycles;
integer gap;


//================================================================//
//                        wire & registers                        //
//================================================================//
reg [1:0] map [63:0][7:0];
reg [2:0] Stage;

//================================================================//
//                             clock                              //
//================================================================//
initial begin
	clk = 0;
end
always #(CYCLE/2.0) clk = ~clk;

//================================================================//
//                             initial                            //
//================================================================//
initial begin
    rst_n = 1'b1;
    in_valid = 1'b0;
    in0 = 2'bx;
    in1 = 2'bx;
    in2 = 2'bx;
    in3 = 2'bx;
    in4 = 2'bx;
    in5 = 2'bx;
    in6 = 2'bx;
    in7 = 2'bx;
    force clk = 0;
    reset_task;

    repeat(5) @(negedge clk);
	for( i = 1 ; i <= NUM_PATTERN; i = i + 1)begin
        input_task;
        wait_outvalid;
        check_ans;
        delay_task;
        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m  \033[0;32mexecution cycle : %3d\033[m",i ,latency);
        total_latency = total_latency + latency;
    end
    YOU_PASS_task;
end

//================================================================//
//                         reset task                             //
//================================================================//
task reset_task; begin
    #(0.5);  rst_n=0;
    #(2.0);
    // Spec.3: Output signal should be 0 after initial RESET
    check_SPEC_3_task;

    #(10);  rst_n=1;
    #(3);  release clk;
end endtask

//================================================================//
//                         input task                             //
//================================================================//
task input_task; begin
	in_valid = 1'b1;
    guy_pos = 4;
    Stage = 0;
    empty_pos = 4;
    empty_cnt = -1;
    cycles = 0;

    for(j=0 ; j<LEN; j=j+1)begin

        // Spec.4: The out should be reset whenever your out_valid isn’t high.
        check_SPEC_4_task;
        // Spec.5: The out_valid should not be high when in_valid is high
        check_SPEC_5_task;

        cycles = cycles +1;

        if(j==0)begin
            guy = $urandom_range(0,7);
            guy_pos = guy;
            Stage = 0;
            empty_pos = guy;
            empty_obstacles;
            @(negedge clk);
            guy = 'dx;
        end
        else begin
            if(No_Obstacles) begin //the previous one has no obstalces
                No_Obstacles = $urandom_range(0,1); //determine current row
                if(No_Obstacles) begin
                    empty_obstacles;
                end
                else begin
                    //the smallest position should be one
                    //the biggest position should be seven
                    obstacle_type = $urandom_range(1,2);
                    case(obstacle_type)
                    1:  begin
                        if(empty_pos - empty_cnt < 0 && empty_pos + empty_cnt <= 7)begin
                            empty_pos = $urandom_range(0,empty_pos+empty_cnt);
                        end
                        else if(empty_pos - empty_cnt >= 0 && empty_pos + empty_cnt > 7)begin
                            empty_pos = $urandom_range(empty_pos-empty_cnt,7);
                        end
                        else if(empty_pos - empty_cnt < 0 && empty_pos + empty_cnt > 7)begin
                            empty_pos = $urandom_range(0,7);
                        end
                        else begin
                            empty_pos = $urandom_range(empty_pos-empty_cnt,empty_pos+empty_cnt);
                        end
                    end
                    2:  begin
                        empty_cnt = empty_cnt + 1;
                        if(empty_pos - empty_cnt < 0 && empty_pos + empty_cnt <= 7)begin
                            empty_pos = $urandom_range(0,empty_pos+empty_cnt);
                        end
                        else if(empty_pos - empty_cnt >= 0 && empty_pos + empty_cnt > 7)begin
                            empty_pos = $urandom_range(empty_pos-empty_cnt,7);
                        end
                        else if(empty_pos - empty_cnt < 0 && empty_pos + empty_cnt > 7)begin
                            empty_pos = $urandom_range(0,7);
                        end
                        else begin
                            empty_pos = $urandom_range(empty_pos-empty_cnt,empty_pos+empty_cnt);
                        end
                    end
                    endcase
                    set_obstacles;
                    empty_cnt = 0;
                end
            end
            else begin //the previous one has obstalces
                empty_obstacles;
            end
            @(negedge clk);
        end

        map[j][0] = in0;
        map[j][1] = in1;
        map[j][2] = in2;
        map[j][3] = in3;
        map[j][4] = in4;
        map[j][5] = in5;
        map[j][6] = in6;
        map[j][7] = in7;

	end
	in_valid = 1'b0;
    cycles = 0;
    empty_cnt = 0;
    reset_input;
end endtask

task reset_input; begin
    in0 = 2'bx;
    in1 = 2'bx;
    in2 = 2'bx;
    in3 = 2'bx;
    in4 = 2'bx;
    in5 = 2'bx;
    in6 = 2'bx;
    in7 = 2'bx;
end endtask

task empty_obstacles; begin
    in0 = 2'b0;
    in1 = 2'b0;
    in2 = 2'b0;
    in3 = 2'b0;
    in4 = 2'b0;
    in5 = 2'b0;
    in6 = 2'b0;
    in7 = 2'b0;
    empty_cnt = empty_cnt + 1;
    No_Obstacles = 1;
end endtask

task set_obstacles; begin
    case(empty_pos)
        0:begin
            in0 = obstacle_type;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        1:begin
            in0 = 2'b11;
            in1 = obstacle_type;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        2:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = obstacle_type;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        3:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = obstacle_type;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        4:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = obstacle_type;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        5:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = obstacle_type;
            in6 = 2'b11;
            in7 = 2'b11;
        end
        6:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = obstacle_type;
            in7 = 2'b11;
        end
        7:begin
            in0 = 2'b11;
            in1 = 2'b11;
            in2 = 2'b11;
            in3 = 2'b11;
            in4 = 2'b11;
            in5 = 2'b11;
            in6 = 2'b11;
            in7 = obstacle_type;
        end
    endcase
end endtask

//================================================================//
//                        answer task                             //
//================================================================//
task wait_outvalid; begin
    latency = 0;
    while(out_valid!==1) begin
        latency = latency + 1;
        // Spec.4: The out should be reset whenever your out_valid isn’t high.
        check_SPEC_4_task;
        // Spec.6: The execution latency is limited in 3000 cycles.
        check_SPEC_6_task;
    end
end endtask

task check_ans; begin
    cycles = 0;
    while(out_valid === 1'b1)begin
        cycles = cycles + 1;
        if(cycles == 64)begin
            SPEC_7_FAIL;
        end
        set_current_state;
        @(negedge clk);
    end
    if(cycles != LEN-1) SPEC_7_FAIL;
    cycles = 0;
end endtask

task set_current_state; begin
    case(Stage)
    0:begin
        case(out)
        0: begin //stop
            Stage = 0;
            check_SPEC_8_1_task;
        end
        1: begin //right
            Stage = 0;
            guy_pos = guy_pos + 1;
            check_SPEC_8_1_task;
        end
        2: begin //left
            Stage = 0;
            guy_pos = guy_pos - 1;
            check_SPEC_8_1_task;
        end
        3: begin //jump
            if(map[cycles][guy_pos]==0) Stage = 4;
            else if(map[cycles][guy_pos]==1) Stage = 1;
        end
        endcase
    end
    1:begin
        case(out)
        0: begin //stop
            Stage = 0;
        end
        1: begin //right
            Stage = 0;
            guy_pos = guy_pos + 1;
            if(guy_pos < 0 || guy_pos > 7) SPEC_8_1_FAIL;
        end
        2: begin //left
            Stage = 0;
            guy_pos = guy_pos - 1;
            if(guy_pos < 0 || guy_pos > 7) SPEC_8_1_FAIL;
        end
        3: begin //jump
            Stage = 2;
        end
        endcase
    end
    2:begin
        case(out)
        0: begin //stop
            if(map[cycles][guy_pos]==0) Stage = 3;
            else if(map[cycles][guy_pos]==1) Stage = 1;
            else if(map[cycles][guy_pos]==2) SPEC_8_1_FAIL;
            else if(map[cycles][guy_pos]==3) SPEC_8_1_FAIL;
        end
        default: begin
            if(map[cycles][guy_pos]==1) SPEC_8_3_FAIL;
            else if(map[cycles][guy_pos]==2) SPEC_8_3_FAIL;
            else if(map[cycles][guy_pos]==3) SPEC_8_3_FAIL;
            else if(map[cycles][guy_pos]==0) SPEC_8_2_FAIL;
        end
        endcase
    end
    3:begin
        case(out)
        0: begin //stop
            Stage = 0;
            check_SPEC_8_1_task;
        end
        default: SPEC_8_2_FAIL;
        endcase
    end
    4:begin
        case(out)
        0: begin //stop
            Stage = 0;
            if(map[cycles][guy_pos]==1) SPEC_8_1_FAIL;
            else if(map[cycles][guy_pos]==2) SPEC_8_1_FAIL;
            else if(map[cycles][guy_pos]==3) SPEC_8_1_FAIL;
        end
        default: SPEC_8_3_FAIL;
        endcase
    end
    endcase
end endtask

task delay_task; begin
    while(out_valid===1'b1) @(negedge clk);
    gap = $urandom_range(2, 4);
    repeat(gap) @(negedge clk);
end endtask

//================================================================//
//                         check task                             //
//================================================================//
// Output signal should be 0 after initial RESET
task check_SPEC_3_task; begin
    if(out_valid !== 1'b0 || out !== 1'b0) begin
        $display ("---------------------------------------------");
        $display ("                                             ");
        $display ("SPEC 3 IS FAIL!");
        $display ("Output signal should be 0 after initial RESET");
        $display ("                                             ");
        $display ("---------------------------------------------");
        $finish;
    end
end endtask
// out should be reset when your out_valid is low
task check_SPEC_4_task; begin
    if(out_valid === 1'b0 && out !==1'b0) begin
        $display ("----------------------------------------------");
        $display ("                                              ");
        $display ("SPEC 4 IS FAIL!");
        $display ("out should be reset when your out_valid is low");
        $display ("                                              ");
        $display ("----------------------------------------------");
        $finish;
    end
end endtask

// The out_valid should not be high when in_valid is high
task check_SPEC_5_task; begin
    if (in_valid===1'b1 && out_valid===1'b1) begin
        $display ("--------------------------------------------------");
        $display ("                                                  ");
        $display ("SPEC 5 IS FAIL!");
        $display ("out_valid should not be high when in_valid is high");
        $display ("                                                  ");
        $display ("--------------------------------------------------");
        $finish;
    end
end endtask

// The execution latency are over 3000 cycles
task check_SPEC_6_task; begin
    if( latency == 3000) begin
        $display ("------------------------------------------");
        $display ("                                          ");
        $display ("SPEC 6 IS FAIL!");
        $display ("The execution latency are over 3000 cycles");
        $display ("                                          ");
        $display ("------------------------------------------");
	    $finish;
    end
    @(negedge clk);
end endtask

// out_valid and out must be asserted successively in 63 cycles.
task SPEC_7_FAIL; begin
    $display ("-------------------------------------------------------------");
    $display ("                                                             ");
    $display ("SPEC 7 IS FAIL!");
    $display ("out_valid and out must be asserted successively in 63 cycles.");
    $display ("                                                             ");
    $display ("-------------------------------------------------------------");
    $finish;
end endtask

task check_SPEC_8_1_task;begin
    if(guy_pos < 0 || guy_pos > 7) SPEC_8_1_FAIL;
    if(map[cycles][guy_pos] == 1)  SPEC_8_1_FAIL;
    if(map[cycles][guy_pos] == 3)  SPEC_8_1_FAIL;
end endtask

// the guy has to avoid all obstacles and cannot leave the platform
task SPEC_8_1_FAIL; begin
    $display ("--------------------------------------");
    $display ("                                      ");
    $display ("SPEC 8-1 IS FAIL!");
    $display ("the guy hit obstacles %1d, output: %1d",guy_pos,out);
    $display ("                                      ");
    $display ("--------------------------------------");
    $finish;
end endtask

// If the guy jumps from high to low place, out must be 00 for 2 cycles
task SPEC_8_2_FAIL; begin
    $display ("-----------------------------------------------------------------");
    $display ("                                                                 ");
    $display ("SPEC 8-2 IS FAIL!");
    $display ("the guy jumps from high to low place, out must be 00 for 2 cycles");
    $display ("                                                                 ");
    $display ("-----------------------------------------------------------------");
    $finish;
end endtask

// If the guy jumps to the same height, out must be 00 for 1 cycle
task SPEC_8_3_FAIL; begin
    $display ("---------------------------------------------------------------");
    $display ("                                                               ");
    $display ("SPEC 8-3 IS FAIL!");
    $display ("the guy jumps to the same height, out must be 00 for 1 cycle");
    $display ("                                                               ");
    $display ("---------------------------------------------------------------");
    $finish;
end endtask

task YOU_PASS_task; begin
    $display ("---------------------------------------------------------------------------------------");
    $display ("                             Congratulations!                                          ");
    $display ("                        You have passed all patterns!                                  ");
    $display ("                           Total latency: %3d",total_latency                            );
    $display ("---------------------------------------------------------------------------------------");
    repeat(2)@(negedge clk);
    $finish;
end endtask

endmodule