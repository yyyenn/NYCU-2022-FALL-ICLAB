//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : UT_TOP.v
//   Module Name : UT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
//synopsys translate_on

module UT_TOP (
    // Input signals
    clk, rst_n, in_valid, in_time,
    // Output signals
    out_valid, out_display, out_day
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [30:0] in_time;
output reg out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
parameter s_idle   = 'd0;
parameter s_input  = 'd1;
parameter s_cal	   = 'd2;
parameter s_output = 'd3;

//================================================================
// Wire & Reg Declaration
//================================================================
reg [1:0]c_state, n_state;
reg [5:0] counter_cal;
reg [5:0] counter_out;

reg [30:0] _time;

//================== B2BCD IP ===============//
wire [5:0]  ans_r;
wire [7:0]  ans_w;

//============= year (stage:2) ==============//
wire [30:0] a1,b1;
wire [30:0] a2,b2;
wire [29:0] a3,b3;
wire [28:0] a4,b4;

wire y_op1,y_op2,y_op3,y_op4;

wire[30:0] y1_w;
wire[30:0] y2_w;
wire[29:0] y3_w;
wire[28:0] y4_w;

// stage reg
reg [30:0] cal_year_r;
reg [11:0] ans_year_r;

wire flag_64; // >64 or not

wire [6:0] year_t [3:0]; // max 2038
wire [11:0] year_i;
wire [15:0] year_w;
reg  [15:0] year_ans;  // BCD
reg   revise_day_r;
wire  revise_day_w;
reg  leap_year;

//============== month (stage:1) =============//
reg [28:0] year_rem;
wire [28:0] month_ini_w;
reg [28:0] month_ini_r;
reg [3:0]  month_ans_r; // Binary
reg [7:0]  month_ans;   // BCD

//================ day (stage:1) =============//
reg [22:0] day_ini_r;
reg [4:0]  day_ans_r; // Binary
reg [7:0]  day_ans;   // BCD

wire [21:0] c1,d1;
wire [20:0] c2,d2;
wire [19:0] c3,d3;
wire [18:0] c4,d4;
wire [17:0] c5,d5;

wire d_op1,d_op2,d_op3,d_op4,d_op5;

wire[21:0] day1_w;
wire[20:0] day2_w;
wire[19:0] day3_w;
wire[18:0] day4_w;
wire[17:0] day5_w;

wire [4:0] day_t;

//=========== hour (stage:1) ==========//
reg [16:0] hour_ini_r;
reg [7:0]  hour_ans;   //BCD

wire [16:0] e1,f1;
wire [15:0] e2,f2;
wire [14:0] e3,f3;
wire [13:0] e4,f4;
wire [12:0] e5,f5;

wire h_op1,h_op2,h_op3,h_op4,h_op5;

wire[16:0] hour1_w;
wire[15:0] hour2_w;
wire[14:0] hour3_w;
wire[13:0] hour4_w;
wire[12:0] hour5_w;

wire [4:0] hour_t;

//========== minute (stage:2) ==========//
reg [11:0] min_ini_r;
reg [7:0]  min_ans;   //BCD*/

wire [11:0] g1,h1;
wire [10:0] g2,h2;
wire [9:0]  g3,h3;

wire m_op1,m_op2,m_op3;

wire[11:0] min1_w;
wire[10:0] min2_w;
wire[9:0] min3_w;

// min reg
reg [9:0] min_r;
reg [5:0] min_ans_r;

wire [5:0] min_t[1:0];

//================ sec ================//
reg [5:0]  sec_ans_r; //Binary
reg [7:0]  sec_ans;   //BCD

//============ day of week ============//
reg [30:0] week_time;

wire [30:0] m1,n1;
wire [30:0] n2;
wire [29:0] n3;
wire [28:0] n4;

wire [19:0] i1;
wire [19:0] j1,j2,j3;

wire op;
wire w_op1, w_op2, w_op3;

wire[30:0] week1_w;
wire[30:0] week2_w;
wire[29:0] week3_w;
wire[28:0] week4_w;
wire[19:0] week5_w;
wire[19:0] week6_w;
wire[19:0] week7_w;

reg [28:0] week_r1,week_r2;
reg [19:0] week_r3; // smaller than a week
reg [2:0] dayOfweek_r;
wire [2:0] dayOfweek_w;

//================================================================
// DESIGN
//================================================================
//====== INPUT ======//
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) _time <= 31'd0;
    else begin
        if(n_state == s_input) _time <= in_time;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) week_time <= 31'd0;
    else begin
        if(n_state == s_input) week_time <= in_time;
    end
end
//============================//
//           Year             //
//============================//
assign flag_64 = (_time >= 'd2019686400) ? 1 : 0;
//64
assign a1 = _time ;
assign b1 = 'd2019686400;
//32 4
assign a2 = (counter_cal==0) ? _time :
            (counter_cal==1 && !flag_64) ? cal_year_r:
            (counter_cal==1 && flag_64) ? cal_year_r:
            'd0;
assign b2 = (counter_cal==0) ? 'd1009843200 : 'd126230400;
//16 2
assign a3 = y2_w;
assign b3 = (counter_cal==0) ? 'd504921600 : 'd63072000;
//8  1
assign a4 = y3_w;
assign b4 = (counter_cal==0) ? 'd252460800 :
            (counter_cal==1 && y_op3 && y3_w <= 'd31622400) ? 'd31622400:
            'd31536000;

assign year_t[0] = (y_op1) ? 'd64 : 'd0;
assign year_t[1] = (counter_cal==0) ? (y_op2<<5) : ans_year_r + (y_op2<<2);
assign year_t[2] = (counter_cal==0) ? year_t[1] + (y_op3<<4) : year_t[1] + (y_op3<<1);
assign year_t[3] = (counter_cal==0) ? year_t[2] + (y_op4<<3) : year_t[2] + y_op4;
assign year_i = year_t[3] + 'd1970;

assign revise_day_w = (y_op3 && y_op4) ? 'b1 : 'b0;


// year_rem
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) year_rem <= 'b0;
    else begin
        if(counter_cal==1) year_rem <= y4_w;
    end
end


// revise_day_r
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) revise_day_r <= 'b0;
    else begin
        if(counter_cal==1) revise_day_r <= revise_day_w;
    end
end

// leap_year
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) leap_year <= 'b0;
    else begin
        if(counter_cal==1) leap_year <= (y_op3 && !y_op4) ? 'b1 : 'b0;
    end
end

// REG cal_year
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) cal_year_r <= 'd0;
    else begin
        case(n_state)
        s_cal: if(flag_64) cal_year_r <= y1_w;
               else cal_year_r <= {{2'b00},y4_w};
        default: cal_year_r <= 'd0;
        endcase
    end
end

// REG ans_year
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) ans_year_r <= 'd0;
    else begin
        case(n_state)
        s_cal: if(flag_64) ans_year_r <= year_t[0];
               else ans_year_r <= year_t[3];
        default: ans_year_r <= 'd0;
        endcase
    end
end
////////////////////////////////////////////////////////////////////////
reg [11:0] year_binary;
// REG ans_year
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) year_binary <= 'd0;
    else begin
        if(counter_cal==1) year_binary <= year_i;
    end
end
////////////////////////////////////////////////////////////////////////
// ANS YEAR
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        year_ans <= 0;
    else begin
        if(counter_cal == 2) year_ans <= year_w;
    end
end

//============================//
//           Month            //
//============================//
// initial month
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        month_ini_r <= 0;
    else begin
        if(counter_cal == 2) month_ini_r <=  (revise_day_r) ? year_rem - 'd86400 : year_rem;// y4_w -'d86400 : y4_w;
    end
end
// month_ans_r
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        month_ans_r <= 0;
    else begin
        if(counter_cal==3)begin
            if(leap_year)begin
                month_ans_r <= (month_ini_r < 2678400)  ? 'd1 :
                               (month_ini_r < 5184000)  ? 'd2 :
                               (month_ini_r < 7862400)  ? 'd3 :
                               (month_ini_r < 10454400) ? 'd4 :
                               (month_ini_r < 13132800) ? 'd5 :
                               (month_ini_r < 15724800) ? 'd6 :
                               (month_ini_r < 18403200) ? 'd7 :
                               (month_ini_r < 21081600) ? 'd8 :
                               (month_ini_r < 23673600) ? 'd9 :
                               (month_ini_r < 26352000) ? 'd10:
                               (month_ini_r < 28944000) ? 'd11:
                               (month_ini_r < 31622400) ? 'd12:
                               'd12;
            end
            else begin
                month_ans_r <= (month_ini_r < 2678400)  ? 'd1 :
                               (month_ini_r < 5097600)  ? 'd2 :
                               (month_ini_r < 7776000)  ? 'd3 :
                               (month_ini_r < 10368000) ? 'd4 :
                               (month_ini_r < 13046400) ? 'd5 :
                               (month_ini_r < 15638400) ? 'd6 :
                               (month_ini_r < 18316800) ? 'd7 :
                               (month_ini_r < 20995200) ? 'd8 :
                               (month_ini_r < 23587200) ? 'd9 :
                               (month_ini_r < 26265600) ? 'd10:
                               (month_ini_r < 28857600) ? 'd11:
                               (month_ini_r < 31536000) ? 'd12:
                               'd12;
            end
        end
    end
end

// leap year (JAN/FEB)
wire leap_revise;
assign leap_revise = (month_ans_r<=2) ? 'd1 :'d0;

// month_ans
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        month_ans <= 0;
    else begin
        if(counter_cal == 4) month_ans <= ans_w;
    end
end

//============================//
//           Day              //
//============================//
//initial day
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        day_ini_r <= 0;
    else begin
        if(counter_cal==4)begin
            if(leap_year)begin
                case(month_ans_r)
                1 : day_ini_r  <=  month_ini_r;
                2 : day_ini_r  <= (month_ini_r - 2678400);
                3 : day_ini_r  <= (month_ini_r - 5184000);
                4 : day_ini_r  <= (month_ini_r - 7862400);
                5 : day_ini_r  <= (month_ini_r - 10454400);
                6 : day_ini_r  <= (month_ini_r - 13132800);
                7 : day_ini_r  <= (month_ini_r - 15724800);
                8 : day_ini_r  <= (month_ini_r - 18403200);
                9 : day_ini_r  <= (month_ini_r - 21081600);
                10: day_ini_r  <= (month_ini_r - 23673600);
                11: day_ini_r  <= (month_ini_r - 26352000);
                12: day_ini_r  <= (month_ini_r - 28944000);
                endcase
            end
            else begin
                case(month_ans_r)
                1 : day_ini_r  <=  month_ini_r;
                2 : day_ini_r  <= (month_ini_r -2678400);
                3 : day_ini_r  <= (month_ini_r -5097600);
                4 : day_ini_r  <= (month_ini_r -7776000);
                5 : day_ini_r  <= (month_ini_r -10368000);
                6 : day_ini_r  <= (month_ini_r -13046400);
                7 : day_ini_r  <= (month_ini_r -15638400);
                8 : day_ini_r  <= (month_ini_r -18316800);
                9 : day_ini_r  <= (month_ini_r -20995200);
                10: day_ini_r  <= (month_ini_r -23587200);
                11: day_ini_r  <= (month_ini_r -26265600);
                12: day_ini_r  <= (month_ini_r -28857600);
                endcase
            end
        end
    end
end

assign c1 = day_ini_r;
assign c2 = day1_w;
assign c3 = day2_w;
assign c4 = day3_w;
assign c5 = day4_w;

assign d1 = 'd1382400;
assign d2 = 'd691200;
assign d3 = 'd345600;
assign d4 = 'd172800;
assign d5 = 'd86400;

assign day_t = (d_op1<<4) + (d_op2<<3) + (d_op3<<2) + (d_op4<<1) + d_op5 + 1;

//day_ans
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        day_ans <= 0;
    else begin
        if(counter_cal == 5) day_ans <= ans_w;
    end
end

//============================//
//            Hour            //
//============================//
//initial hour
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        hour_ini_r <= 0;
    else begin
        if(counter_cal == 5) hour_ini_r <= day5_w;
    end
end

assign e1 = hour_ini_r;
assign e2 = hour1_w;
assign e3 = hour2_w;
assign e4 = hour3_w;
assign e5 = hour4_w;

assign f1 = 'd57600;
assign f2 = 'd28800;
assign f3 = 'd14400;
assign f4 = 'd7200;
assign f5 = 'd3600;
assign hour_t = (h_op1<<4) + (h_op2<<3) + (h_op3<<2) + (h_op4<<1) + h_op5;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        hour_ans <= 0;
    else begin
        if(counter_cal == 6) hour_ans <= ans_w;
    end
end
//============================//
//           Minute           //
//============================//
//initial minute
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        min_ini_r <= 0;
    else begin
        if(counter_cal == 6) min_ini_r <= hour5_w;
    end
end

assign g1 = (counter_cal == 7) ? min_ini_r: min_r;
assign g2 = min1_w ;
assign g3 = min2_w ;

assign h1 = (counter_cal == 7) ?'d1920: 'd240;
assign h2 = (counter_cal == 7) ?'d960 : 'd120;
assign h3 = (counter_cal == 7) ?'d480 : 'd60 ;


assign min_t[0] = (counter_cal == 7) ? (m_op1<<5) + (m_op2<<4) + (m_op3<<3) : 'd0 ;
assign min_t[1] = (counter_cal == 8) ? min_ans_r + (m_op1<<2) + (m_op2<<1) + m_op3 : 'd0 ;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) min_r <= 0;
    else begin
        //if(counter_cal == 6) min_r <= min3_w;
        if(counter_cal == 7) min_r <= min3_w;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n) min_ans_r <= 0;
    else begin
        //if(counter_cal == 6) min_ans_r <= min_t[0];
        if(counter_cal == 7) min_ans_r <= min_t[0];
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        min_ans <= 0;
    else begin
        //if(counter_cal == 7) min_ans <= ans_w;
        if(counter_cal == 8) min_ans <= ans_w;
    end
end
//============================//
//          Second            //
//============================//
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sec_ans_r <= 0;
    else begin
        //if(counter_cal == 8) sec_ans_r <= min3_w;
        if(counter_cal == 9) sec_ans_r <= min3_w;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sec_ans <= 0;
    else begin
        //if(counter_cal == 9) sec_ans <= ans_w;
        if(counter_cal == 10) sec_ans <= ans_w;
    end
end
//============================//
//       Day of Week          //
//============================//
assign m1 = (counter_cal==0) ? week_time:
            (counter_cal==1) ? week_r1:
            (counter_cal==2) ? week_r2:
            'd0;

assign n1 = (counter_cal==0) ? 'd1238630400: //2048 week
            (counter_cal==1) ? 'd77414400:   //128 week
            (counter_cal==2) ? 'd4838400:    //8 week
            'd0;

assign n2 = (counter_cal==0) ? 'd619315200:  //1024 week
            (counter_cal==1) ? 'd38707200:   //64 week
            (counter_cal==2) ? 'd2419200:    //4 week
            'd0;

assign n3 = (counter_cal==0) ? 'd309657600:  //512 week
            (counter_cal==1) ? 'd19353600:   //32 week
            (counter_cal==2) ? 'd1209600:    //2 week
            'd0;

assign n4 = (counter_cal==0) ? 'd154828800:  //256 week
            (counter_cal==1) ? 'd9676800:    //16 week
            (counter_cal==2) ? 'd604800:     //1 week
            'd0;

assign i1 = (counter_cal==3) ? week_r3:'d0;

assign j1 = (counter_cal==3) ? 'd345600: 'd0; //4 day

assign j2 = (counter_cal==3) ? 'd172800: 'd0; //2 day

assign j3 = (counter_cal==3) ? 'd86400: 'd0; //1 day

assign dayOfweek_w = (w_op1<<2) + (w_op2<<1) + w_op3;
//week_r1
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) week_r1 <= 0;
    else begin
        if(counter_cal==0) week_r1 <= week4_w;
    end
end

//week_r2
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) week_r2 <= 0;
    else begin
        if(counter_cal==1)week_r2 <= week4_w;
    end
end
//week_r3
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) week_r3  <= 0;
    else begin
        if(counter_cal==2) week_r3 <= week4_w;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) dayOfweek_r  <= 0;
    else begin
        if(counter_cal==3) dayOfweek_r <= (dayOfweek_w +'d4 >= 7) ? dayOfweek_w + 'd4 - 'd7 : dayOfweek_w + 'd4;
    end
end

//====== OUTPUT ======//
// out_valid
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 1'b0;
    else begin
        if(n_state == s_output) out_valid <= 1'b1;
        else out_valid <= 1'b0;
    end
end
//out_display
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_display <= 0;
    else begin
        if(n_state == s_output) begin
            case(counter_out)
            0: out_display <= year_ans[15:12];
            1: out_display <= year_ans[11:8];
            2: out_display <= year_ans[7:4];
            3: out_display <= year_ans[3:0];
            4: out_display <= month_ans[7:4];
            5: out_display <= month_ans[3:0];
            6: out_display <= day_ans[7:4];
            7: out_display <= day_ans[3:0];
            8: out_display <= hour_ans[7:4];
            9: out_display <= hour_ans[3:0];
            10:out_display <= min_ans[7:4];
            11:out_display <= min_ans[3:0];
            12:out_display <= sec_ans[7:4];
            13:out_display <= sec_ans[3:0];
            default: out_display <= 0;
            endcase
        end
        else out_display <= 0;
    end
end
//out_day
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) out_day <= 0;
    else begin
        if(n_state == s_output) begin
            out_day <= dayOfweek_r;
        end
        else out_day <= 0;
    end
end
//====== SUB ======//
// year
COMPARE_SUB #(31) SUB_1 (.A(a1), .B(b1), .DIFF(y1_w), .OP(y_op1)) ;
COMPARE_SUB #(31) SUB_2 (.A(a2), .B(b2), .DIFF(y2_w), .OP(y_op2)) ;
COMPARE_SUB #(30) SUB_3 (.A(a3), .B(b3), .DIFF(y3_w), .OP(y_op3)) ;
COMPARE_SUB #(29) SUB_4 (.A(a4), .B(b4), .DIFF(y4_w), .OP(y_op4)) ;
// month
COMPARE_SUB #(22) SUB_5 (.A(c1), .B(d1), .DIFF(day1_w), .OP(d_op1)) ;
COMPARE_SUB #(21) SUB_6 (.A(c2), .B(d2), .DIFF(day2_w), .OP(d_op2)) ;
COMPARE_SUB #(20) SUB_7 (.A(c3), .B(d3), .DIFF(day3_w), .OP(d_op3)) ;
COMPARE_SUB #(19) SUB_8 (.A(c4), .B(d4), .DIFF(day4_w), .OP(d_op4)) ;
COMPARE_SUB #(18) SUB_9 (.A(c5), .B(d5), .DIFF(day5_w), .OP(d_op5)) ;
// hour
COMPARE_SUB #(17) SUB_10 (.A(e1), .B(f1), .DIFF(hour1_w), .OP(h_op1)) ;
COMPARE_SUB #(16) SUB_11 (.A(e2), .B(f2), .DIFF(hour2_w), .OP(h_op2)) ;
COMPARE_SUB #(15) SUB_12 (.A(e3), .B(f3), .DIFF(hour3_w), .OP(h_op3)) ;
COMPARE_SUB #(14) SUB_13 (.A(e4), .B(f4), .DIFF(hour4_w), .OP(h_op4)) ;
COMPARE_SUB #(13) SUB_14 (.A(e5), .B(f5), .DIFF(hour5_w), .OP(h_op5)) ;
// min
COMPARE_SUB #(12) SUB_15 (.A(g1), .B(h1), .DIFF(min1_w), .OP(m_op1)) ;
COMPARE_SUB #(11) SUB_16 (.A(g2), .B(h2), .DIFF(min2_w), .OP(m_op2)) ;
COMPARE_SUB #(10) SUB_17 (.A(g3), .B(h3), .DIFF(min3_w), .OP(m_op3)) ;
// day of week
COMPARE_SUB #(31) week_1 (.A(m1),            .B(n1), .DIFF(week1_w), .OP(op)) ;
COMPARE_SUB #(31) week_2 (.A(week1_w),       .B(n2), .DIFF(week2_w), .OP(op)) ;
COMPARE_SUB #(30) week_3 (.A(week2_w[29:0]), .B(n3), .DIFF(week3_w), .OP(op)) ;
COMPARE_SUB #(29) week_4 (.A(week3_w[28:0]), .B(n4), .DIFF(week4_w), .OP(op)) ;

COMPARE_SUB #(20) week_5 (.A(i1),      .B(j1), .DIFF(week5_w), .OP(w_op1)) ;
COMPARE_SUB #(20) week_6 (.A(week5_w), .B(j2), .DIFF(week6_w), .OP(w_op2)) ;
COMPARE_SUB #(20) week_7 (.A(week6_w), .B(j3), .DIFF(week7_w), .OP(w_op3)) ;

//====== B2BCD_IP======//
assign ans_r = (counter_cal==4) ? {{2'b00},month_ans_r}:
               (counter_cal==5) ? {{1'b0} ,day_t}:
               (counter_cal==6) ? {{1'b0} ,hour_t}:
               (counter_cal==8) ? {{1'b0} ,min_t[1]}:
               (counter_cal==10) ? {{1'b0} ,sec_ans_r}:
                'd0;

//B2BCD_IP #(12,4) B2BCD_1 (.Binary_code(year_i),.BCD_code(year_w));
B2BCD_IP #(12,4) B2BCD_1 (.Binary_code(year_binary),.BCD_code(year_w));
B2BCD_IP #(6,2)  B2BCD_2 (.Binary_code(ans_r),.BCD_code(ans_w));

//====== FSM ======//
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle:  if(in_valid)        n_state = s_input;
	         else    	         n_state = s_idle;
    s_input: if(in_valid)        n_state = s_input;
             else                n_state = s_cal;
    s_cal:   if(counter_cal<4)   n_state = s_cal;
             else                n_state = s_output;
    s_output:if(counter_out<14)  n_state = s_output;
             else                n_state = s_idle;
    default: n_state = c_state;
    endcase
end

//====== counter cal & out ======//
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        counter_cal <= 0;
    else begin
        case(n_state)
        s_cal:   counter_cal <= counter_cal + 1;
        s_output:   counter_cal <= counter_cal + 1;
        default: counter_cal <= 0;
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        counter_out <= 0;
    else begin
        case(n_state)
        s_output:  counter_out <= counter_out + 1;
        default:   counter_out <= 0;
        endcase
    end
end

endmodule

module COMPARE_SUB #(parameter WIDTH = 31) (A,B,DIFF,OP);

input [WIDTH-1:0] A;
input [WIDTH-1:0] B;
output reg[WIDTH-1:0] DIFF;
output reg OP;

generate
always@(*)begin
    if(A >= B) DIFF = A - B;
    else DIFF = A;
end
always@(*)begin
    if(A >= B) OP = 1'b1;
    else OP = 1'b0;
end
endgenerate

endmodule