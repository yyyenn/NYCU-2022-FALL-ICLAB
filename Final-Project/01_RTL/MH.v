//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
//synopsys translate_on
//============================================================//
//                        TOP MODULE                          //
//============================================================//
module MH(
    // Input signals
    clk, clk2, rst_n, in_valid, op_valid, pic_data, se_data, op, out_valid, out_data,
);

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter DATA_WIDTH = 32;
//state
parameter s_idle      = 3'd0 ;
parameter s_input_se  = 3'd1 ;
parameter s_input_pic = 3'd2 ;
parameter s_cal       = 3'd3 ;
parameter s_w_sram    = 3'd4 ;
parameter s_output    = 3'd5 ;

genvar i,j;

//======================================
//      IN/OUTPUT DECLARATION
//======================================
input		      clk,clk2,rst_n;
input		      in_valid;
input		      op_valid;
input [31:0]      pic_data;
input [7:0]       se_data;
input [2:0]       op;
output reg        out_valid;
output reg [31:0] out_data;

//======================================
//      WIRE and REG
//======================================
reg [2:0]c_state,n_state;

reg [2:0] OP;
reg [127:0] se_r;
reg [DATA_WIDTH-1:0] line_buffer [25:0];   // 26 line buffer
wire[7:0] processed_pixel [3:0];          // write into SRAM
reg [127:0] se_window [3:0];  // 4 SE windows

reg [255:0] histogram_window [3:0];    // 0~255 histogram table
reg [7:0] min_index [3:0];
reg [7:0] final_min_index;
reg [10:0] cdf_table [255:0];           // cdf table
reg [9:0] cdf_Mm;
reg [9:0] cdf_m;
reg [7:0]cdf_table_index[3:0];

// counter for all
reg [8:0] input_cnt;  // 256
reg [6:0] cal_cnt;    // 64
reg [8:0] w_sram_cnt; // 256
reg [8:0] output_cnt; // 256
reg first_process;
reg second_process;
reg input_flag;

reg [15:0] overflow [3:0];    // check dilation add
wire [3:0] dw_idx;
wire min_max;

// SRAM in/out port control
reg [6:0] pic_addr_1; // max 127
reg [6:0] pic_addr_2; // max 127
reg [DATA_WIDTH-1:0]  pic_in;
wire [DATA_WIDTH-1:0] pic_out_1;
wire [DATA_WIDTH-1:0] pic_out_2;
reg wen_pic_1;
reg wen_pic_2;
reg cen;
reg oen;

//======================================
//      FSM
//======================================
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle:      if(in_valid || input_flag)
                    n_state = s_input_se;
	             else
                    n_state = s_idle;
    //include se and pic
    s_input_se:  if(input_cnt==16)  n_state = s_input_pic;
                 else               n_state = s_input_se;
    //include only pic
    s_input_pic: if(input_cnt==256) n_state = s_cal;
                 else               n_state = s_input_pic;
    s_cal:       if((OP == 'b110 || OP == 'b111) && input_cnt==284) n_state = s_idle;  // opening & closing
                 else if(OP == 'b000 && cal_cnt==30) n_state = s_output;
                 else if(OP != 'b000 && cal_cnt==26) n_state = s_w_sram;
                 else               n_state = s_cal;
    s_w_sram:    if(w_sram_cnt==27)begin
                    if((OP == 'b110 || OP== 'b111) && first_process==1)
                        n_state = s_idle;
                    else
                        n_state = s_output;
                 end
                 else
                    n_state = s_w_sram;
    s_output:    if(second_process==0 && output_cnt==229)
                    n_state = s_idle;
                 else
                    n_state = s_output;
    default: n_state = c_state;
    endcase
end
//======================================
//      COUNTER
//======================================
// input_cnt
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        input_cnt <= 0;
    else begin
        if(second_process == 0 && (n_state == s_input_se || n_state == s_input_pic))
            input_cnt <= input_cnt + 1;
        else if((first_process==1 && cal_cnt==25) || (second_process == 1))
            input_cnt <= input_cnt + 1;
        else
            input_cnt <= 0;
    end
end
// cal_cnt
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_cnt <= 0;
    else begin
        if(second_process==0 && n_state == s_cal)
            cal_cnt <= cal_cnt + 1;
        else
            cal_cnt <= 0;
    end
end
// w_sram_cnt
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        w_sram_cnt <= 0;
    else begin
        if(n_state == s_cal || n_state == s_w_sram)
            w_sram_cnt <= w_sram_cnt + 1;
        else
            w_sram_cnt <= 0;
    end
end
// output_cnt
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        output_cnt <= 0;
    else begin
        if(n_state == s_output)
            output_cnt <= output_cnt + 1;
        else
            output_cnt <= 0;
    end
end

// first_process (for opening or closing)
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        first_process <= 0;
    else begin
        if(n_state == s_input_pic && (OP =='b110 ||OP =='b111)) // opening or closing
            first_process <= 1;
        else if(n_state == w_sram_cnt && input_flag == 1)     // done twice process!
            first_process <= 0;
    end
end
// second_process (for opening or closing)
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        second_process <= 0;
    else begin
        if(cal_cnt == 25 && (first_process == 1))        // opening or closing
            second_process <= 1;
        else if(input_cnt == 283)                        // done twice process!
            second_process <= 0;
    end
end
// input_flag
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        input_flag <= 0;
    else if(first_process ==  1)
        input_flag <= second_process;
    else
        input_flag <= 0;
end
//======================================
//      INPUT
//======================================
//======== OP <= op ========//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        OP <= 0;
    else if(op_valid)begin
        OP <= op;
    end
    else if(n_state == s_idle && first_process == 0)
        OP <= 0;
end
//======== se_r <= se_data ========//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        se_r <= 0;
    else if(n_state == s_input_se && first_process == 0)begin
        se_r[127:120] <= se_data;
        se_r[119:112] <= se_r[127:120];
        se_r[111:104] <= se_r[119:112];
        se_r[103:96] <= se_r[111:104];
        se_r[95:88] <= se_r[103:96];
        se_r[87:80] <= se_r[95:88];
        se_r[79:72] <= se_r[87:80];
        se_r[71:64] <= se_r[79:72];
        se_r[63:56] <= se_r[71:64];
        se_r[55:48] <= se_r[63:56];
        se_r[47:40] <= se_r[55:48];
        se_r[39:32] <= se_r[47:40];
        se_r[31:24] <= se_r[39:32];
        se_r[23:16] <= se_r[31:24];
        se_r[15:8] <= se_r[23:16];
        se_r[7:0] <= se_r[15:8];
    end
    else if(second_process==0 && n_state == s_idle)
        se_r <= 0;
end
//======== line Buffer <= pic_data ========//
// Line Buffer[0]
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        line_buffer[0] <= 0;
    else if(second_process == 0 && (n_state == s_input_se || n_state == s_input_pic))
        line_buffer[0] <= pic_data;
    else if((first_process==1 && cal_cnt == 25) ||second_process == 1) begin
        if(input_cnt <= 127)
            line_buffer[0] <= pic_out_1;
        else if(input_cnt <= 255)
            line_buffer[0] <= pic_out_2;
        else
            line_buffer[0] <= 0;
    end
    else
        line_buffer[0] <= 0;
end

// Line Buffer[1]~[25]
generate
for(i = 1 ; i < 26 ; i = i + 1)begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            line_buffer[i] <= 0;
        else begin
            line_buffer[i]  <= line_buffer[i-1];
        end
    end
end
endgenerate

//======================================
//      OUTPUT
//======================================
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        out_valid <= 0;
    else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if(n_state == s_cal || n_state == s_w_sram || n_state == s_output)
                out_valid <= 1;
            else
                out_valid <= 0;
        end
        else if(OP == 'b110 || OP == 'b111) begin //opening & closing
            if(second_process == 1 && (input_cnt > 26 && input_cnt < 283))
                out_valid <= 1;
            else
                out_valid <= 0;
        end
        else if(OP == 'b000) begin
            if(cal_cnt > 2 || n_state == s_output)
                out_valid <= 1;
            else
                out_valid <= 0;
        end
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        out_data <= 0;
    else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if(n_state == s_cal || n_state == s_w_sram || (n_state == s_output && output_cnt <= 100))
                out_data <= pic_out_1;
            else if(n_state == s_output && output_cnt > 100)
                out_data <= pic_out_2;
            else
                out_data <= 0;
        end
        else if(OP == 'b110 || OP == 'b111) begin //opening & closing
            if(second_process == 1 && input_cnt > 26 && input_cnt < 283)
                out_data <= {processed_pixel[3],processed_pixel[2],processed_pixel[1],processed_pixel[0]};
            else
                out_data <= 0;
        end
        else if(OP == 'b000) begin
            if(cal_cnt > 2 || n_state == s_output) begin
                out_data[7:0]   <= (cdf_table[cdf_table_index[0]] -cdf_m) * 255 / cdf_Mm;
                out_data[15:8]  <= (cdf_table[cdf_table_index[1]] -cdf_m) * 255 / cdf_Mm;
                out_data[23:16] <= (cdf_table[cdf_table_index[2]] -cdf_m) * 255 / cdf_Mm;
                out_data[31:24] <= (cdf_table[cdf_table_index[3]] -cdf_m) * 255 / cdf_Mm;
            end
            else
                out_data <= 0;
        end
    end
end

// 4 SE windows
/****************************************************************************************************/
/*                                                                                                  */
/*  se_window_r[i][7:0]    se_window_r[i][15:8]    se_window_r[i][23:16]   se_window_r[i][31:24]    */
/*  se_window_r[i][39:32]  se_window_r[i][47:40]   se_window_r[i][55:48]   se_window_r[i][63:56]    */
/*  se_window_r[i][71:64]  se_window_r[i][79:72]   se_window_r[i][87:80]   se_window_r[i][95:88]    */
/*  se_window_r[i][103:96] se_window_r[i][111:104] se_window_r[i][119:112] se_window_r[i][127:120]  */
/*                                                                                                  */
/****************************************************************************************************/
// se_window 0
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[0] <= 0;
        se_window[0] <= 0;
    end
    else begin
        if(OP == 'b010 || (OP == 'b110 && second_process == 0) || (OP == 'b111 && second_process == 1))begin // erosion & first opening & second closing
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                se_window[0][7:0]   <= (line_buffer[25][7:0]   > se_r[7:0])   ? line_buffer[25][7:0] - se_r[7:0]   : 0;
                se_window[0][15:8]  <= (line_buffer[25][15:8]  > se_r[15:8])  ? line_buffer[25][15:8] - se_r[15:8]  : 0;
                se_window[0][23:16] <= (line_buffer[25][23:16] > se_r[23:16]) ? line_buffer[25][23:16] - se_r[23:16] : 0;
                se_window[0][31:24] <= (line_buffer[25][31:24] > se_r[31:24]) ? line_buffer[25][31:24] - se_r[31:24] : 0;

                se_window[0][39:32] <= (line_buffer[17][7:0]   > se_r[39:32])  ? line_buffer[17][7:0] - se_r[39:32] : 0;
                se_window[0][47:40] <= (line_buffer[17][15:8]  > se_r[47:40])  ? line_buffer[17][15:8] - se_r[47:40] : 0;
                se_window[0][55:48] <= (line_buffer[17][23:16] > se_r[55:48])  ? line_buffer[17][23:16] - se_r[55:48] : 0;
                se_window[0][63:56] <= (line_buffer[17][31:24] > se_r[63:56])  ? line_buffer[17][31:24] - se_r[63:56] : 0;

                se_window[0][71:64] <= (line_buffer[9][7:0]   > se_r[71:64])  ? line_buffer[9][7:0] - se_r[71:64] : 0;
                se_window[0][79:72] <= (line_buffer[9][15:8]  > se_r[79:72])  ? line_buffer[9][15:8] - se_r[79:72] : 0;
                se_window[0][87:80] <= (line_buffer[9][23:16] > se_r[87:80])  ? line_buffer[9][23:16] - se_r[87:80] : 0;
                se_window[0][95:88] <= (line_buffer[9][31:24] > se_r[95:88])  ? line_buffer[9][31:24] - se_r[95:88] : 0;

                se_window[0][103:96]  <= (line_buffer[1][7:0]   > se_r[103:96])  ? line_buffer[1][7:0] - se_r[103:96]  : 0;
                se_window[0][111:104] <= (line_buffer[1][15:8]  > se_r[111:104]) ? line_buffer[1][15:8] - se_r[111:104] : 0;
                se_window[0][119:112] <= (line_buffer[1][23:16] > se_r[119:112]) ? line_buffer[1][23:16] - se_r[119:112] : 0;
                se_window[0][127:120] <= (line_buffer[1][31:24] > se_r[127:120]) ? line_buffer[1][31:24] - se_r[127:120] : 0;
            end
        end
        else if(OP == 'b011 || (OP == 'b110 && second_process == 1 || (OP == 'b111 && second_process == 0)))begin // dilation & first closing & second opening
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                {overflow[0][0], se_window[0][7:0]  } <= line_buffer[25][7:0]   + se_r[127:120];
                {overflow[0][1], se_window[0][15:8] } <= line_buffer[25][15:8]  + se_r[119:112];
                {overflow[0][2], se_window[0][23:16]} <= line_buffer[25][23:16] + se_r[111:104];
                {overflow[0][3], se_window[0][31:24]} <= line_buffer[25][31:24] + se_r[103:96];

                {overflow[0][4], se_window[0][39:32]} <= line_buffer[17][7:0]   + se_r[95:88];
                {overflow[0][5], se_window[0][47:40]} <= line_buffer[17][15:8]  + se_r[87:80];
                {overflow[0][6], se_window[0][55:48]} <= line_buffer[17][23:16] + se_r[79:72];
                {overflow[0][7], se_window[0][63:56]} <= line_buffer[17][31:24] + se_r[71:64];

                {overflow[0][8], se_window[0][71:64]} <= line_buffer[9][7:0]   +  se_r[63:56];
                {overflow[0][9], se_window[0][79:72]} <= line_buffer[9][15:8]  +  se_r[55:48];
                {overflow[0][10], se_window[0][87:80]} <= line_buffer[9][23:16] + se_r[47:40];
                {overflow[0][11], se_window[0][95:88]} <= line_buffer[9][31:24] + se_r[39:32];

                {overflow[0][12], se_window[0][103:96]} <= line_buffer[1][7:0]   +  se_r[31:24];
                {overflow[0][13], se_window[0][111:104]} <= line_buffer[1][15:8]  + se_r[23:16];
                {overflow[0][14], se_window[0][119:112]} <= line_buffer[1][23:16] + se_r[15:8];
                {overflow[0][15], se_window[0][127:120]} <= line_buffer[1][31:24] + se_r[7:0];
            end
        end

    end
end
// SE window 1
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[1] <= 0;
        se_window[1] <= 0;
    end
    else begin
        if(OP=='b010 || (OP == 'b110 && second_process == 0) || (OP == 'b111 && second_process == 1)) begin // erosion
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                //normal pixel
                se_window[1][7:0]   <= (line_buffer[25][15:8]  > se_r[7:0])  ? line_buffer[25][15:8]  - se_r[7:0]   : 0;
                se_window[1][15:8]  <= (line_buffer[25][23:16] > se_r[15:8]) ? line_buffer[25][23:16] - se_r[15:8]  : 0;
                se_window[1][23:16] <= (line_buffer[25][31:24] > se_r[23:16])? line_buffer[25][31:24] - se_r[23:16] : 0;

                se_window[1][39:32] <= (line_buffer[17][15:8]  > se_r[39:32]) ? line_buffer[17][15:8]  - se_r[39:32] : 0;
                se_window[1][47:40] <= (line_buffer[17][23:16] > se_r[47:40]) ? line_buffer[17][23:16] - se_r[47:40] : 0;
                se_window[1][55:48] <= (line_buffer[17][31:24] > se_r[55:48]) ? line_buffer[17][31:24] - se_r[55:48] : 0;

                se_window[1][71:64] <= (line_buffer[9][15:8]  > se_r[71:64]) ? line_buffer[9][15:8]  - se_r[71:64] : 0;
                se_window[1][79:72] <= (line_buffer[9][23:16] > se_r[79:72]) ? line_buffer[9][23:16] - se_r[79:72] : 0;
                se_window[1][87:80] <= (line_buffer[9][31:24] > se_r[87:80]) ? line_buffer[9][31:24] - se_r[87:80] : 0;

                se_window[1][103:96]  <= (line_buffer[1][15:8]  > se_r[103:96])  ? line_buffer[1][15:8]  - se_r[103:96] : 0;
                se_window[1][111:104] <= (line_buffer[1][23:16] > se_r[111:104]) ? line_buffer[1][23:16] - se_r[111:104] : 0;
                se_window[1][119:112] <= (line_buffer[1][31:24] > se_r[119:112]) ? line_buffer[1][31:24] - se_r[119:112] : 0;
                //edge pixel
                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin // the rightest 3 pixels
                    se_window[1][31:24]   <= 0;
                    se_window[1][63:56]   <= 0;
                    se_window[1][95:88]   <= 0;
                    se_window[1][127:120] <= 0;
                end
                else begin
                    se_window[1][31:24]   <= (line_buffer[24][7:0]  > se_r[31:24])   ? line_buffer[24][7:0] - se_r[31:24] : 0;
                    se_window[1][63:56]   <= (line_buffer[16][7:0]  > se_r[63:56])   ? line_buffer[16][7:0] - se_r[63:56] : 0;
                    se_window[1][95:88]   <= (line_buffer[8][7:0]   > se_r[95:88])   ? line_buffer[8][7:0] - se_r[95:88] : 0;
                    se_window[1][127:120] <= (line_buffer[0][7:0]   > se_r[127:120]) ? line_buffer[0][7:0] - se_r[127:120] : 0;
                end
            end
        end
        else if(OP=='b011 || (OP == 'b110 && second_process == 1) || (OP == 'b111 && second_process == 0)) begin // dilation
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                {overflow[1][0], se_window[1][7:0]}   <= {{1'b0},line_buffer[25][15:8] } + se_r[127:120];
                {overflow[1][1], se_window[1][15:8]}  <= {{1'b0},line_buffer[25][23:16]} + se_r[119:112];
                {overflow[1][2], se_window[1][23:16]} <= {{1'b0},line_buffer[25][31:24]} + se_r[111:104];

                {overflow[1][3], se_window[1][39:32]} <= {{1'b0},line_buffer[17][15:8] } + se_r[95:88];
                {overflow[1][4], se_window[1][47:40]} <= {{1'b0},line_buffer[17][23:16]} + se_r[87:80];
                {overflow[1][5], se_window[1][55:48]} <= {{1'b0},line_buffer[17][31:24]} + se_r[79:72];

                {overflow[1][6], se_window[1][71:64]} <= {{1'b0},line_buffer[9][15:8] } + se_r[63:56];
                {overflow[1][7], se_window[1][79:72]} <= {{1'b0},line_buffer[9][23:16]} + se_r[55:48];
                {overflow[1][8], se_window[1][87:80]} <= {{1'b0},line_buffer[9][31:24]} + se_r[47:40];

                {overflow[1][9], se_window[1][103:96]}   <= {{1'b0},line_buffer[1][15:8] } + se_r[31:24];
                {overflow[1][10], se_window[1][111:104]} <= {{1'b0},line_buffer[1][23:16]} + se_r[23:16];
                {overflow[1][11], se_window[1][119:112]} <= {{1'b0},line_buffer[1][31:24]} + se_r[15:8];

                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin
                    {overflow[1][12],se_window[1][31:24]}   <=  {{1'b0},se_r[103:96]};
                    {overflow[1][13],se_window[1][63:56]}   <=  {{1'b0},se_r[71:64]};
                    {overflow[1][14],se_window[1][95:88]}   <=  {{1'b0},se_r[39:32]};
                    {overflow[1][15],se_window[1][127:120]} <= {{1'b0},se_r[7:0]};
                end
                else begin
                    {overflow[1][12], se_window[1][31:24]}   <= {{1'b0},line_buffer[24][7:0]} +  se_r[103:96];
                    {overflow[1][13], se_window[1][63:56]}   <= {{1'b0},line_buffer[16][7:0]} +  se_r[71:64];
                    {overflow[1][14], se_window[1][95:88]}   <= {{1'b0},line_buffer[8][7:0]}  +  se_r[39:32];
                    {overflow[1][15], se_window[1][127:120]} <= {{1'b0},line_buffer[0][7:0]} + se_r[7:0];
                end
            end
        end
    end
end
// SE window 2
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[2] <= 0;
        se_window[2] <= 0;
    end
    else begin
        if(OP=='b010 || (OP == 'b110 && second_process == 0) || (OP == 'b111 && second_process == 1)) begin // erosion
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                //normal pixel
                se_window[2][7:0]   <= (line_buffer[25][23:16] > se_r[7:0])  ? line_buffer[25][23:16] - se_r[7:0]   : 0;
                se_window[2][15:8]  <= (line_buffer[25][31:24] > se_r[15:8]) ? line_buffer[25][31:24] - se_r[15:8]  : 0;

                se_window[2][39:32] <= (line_buffer[17][23:16] > se_r[39:32]) ? line_buffer[17][23:16] - se_r[39:32] : 0;
                se_window[2][47:40] <= (line_buffer[17][31:24] > se_r[47:40]) ? line_buffer[17][31:24] - se_r[47:40] : 0;

                se_window[2][71:64] <= (line_buffer[9][23:16] > se_r[71:64]) ? line_buffer[9][23:16] - se_r[71:64] : 0;
                se_window[2][79:72] <= (line_buffer[9][31:24] > se_r[79:72]) ? line_buffer[9][31:24] - se_r[79:72] : 0;

                se_window[2][103:96]  <= (line_buffer[1][23:16] > se_r[103:96])  ? line_buffer[1][23:16] - se_r[103:96] : 0;
                se_window[2][111:104] <= (line_buffer[1][31:24] > se_r[111:104]) ? line_buffer[1][31:24] - se_r[111:104] : 0;

                //edge pixel
                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin//read_pixel_counter[1:0] == 2'b01) begin// the rightest 3 pixels
                    se_window[2][23:16] <= 0;
                    se_window[2][31:24] <= 0;

                    se_window[2][55:48] <= 0;
                    se_window[2][63:56] <= 0;

                    se_window[2][87:80] <= 0;
                    se_window[2][95:88] <= 0;

                    se_window[2][119:112] <= 0;
                    se_window[2][127:120] <= 0;
                end
                else begin
                    se_window[2][23:16] <= (line_buffer[24][7:0]  > se_r[23:16])? line_buffer[24][7:0] - se_r[23:16] : 0;
                    se_window[2][31:24] <= (line_buffer[24][15:8] > se_r[31:24])? line_buffer[24][15:8] - se_r[31:24] : 0;

                    se_window[2][55:48] <= (line_buffer[16][7:0]  > se_r[55:48]) ? line_buffer[16][7:0] - se_r[55:48] : 0;
                    se_window[2][63:56] <= (line_buffer[16][15:8] > se_r[63:56]) ? line_buffer[16][15:8] - se_r[63:56] : 0;

                    se_window[2][87:80] <= (line_buffer[8][7:0]  > se_r[87:80]) ? line_buffer[8][7:0] - se_r[87:80] : 0;
                    se_window[2][95:88] <= (line_buffer[8][15:8] > se_r[95:88]) ? line_buffer[8][15:8] - se_r[95:88] : 0;

                    se_window[2][119:112] <= (line_buffer[0][7:0]  > se_r[119:112]) ? line_buffer[0][7:0] - se_r[119:112] : 0;
                    se_window[2][127:120] <= (line_buffer[0][15:8] > se_r[127:120]) ? line_buffer[0][15:8] - se_r[127:120] : 0;
                end
            end
        end
        else if(OP=='b011 || (OP == 'b110 && second_process == 1) || (OP == 'b111 && second_process == 0)) begin // dilation
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                {overflow[2][0], se_window[2][7:0]} <=  {{1'b0},line_buffer[25][23:16]}  + se_r[127:120];
                {overflow[2][1], se_window[2][15:8]} <= {{1'b0},line_buffer[25][31:24]}  + se_r[119:112];

                {overflow[2][2], se_window[2][39:32]} <= {{1'b0},line_buffer[17][23:16]} + se_r[95:88];
                {overflow[2][3], se_window[2][47:40]} <= {{1'b0},line_buffer[17][31:24]} + se_r[87:80];

                {overflow[2][4], se_window[2][71:64]} <= {{1'b0},line_buffer[9][23:16]} + se_r[63:56];
                {overflow[2][5], se_window[2][79:72]} <= {{1'b0},line_buffer[9][31:24]} + se_r[55:48];

                {overflow[2][6], se_window[2][103:96]}  <= {{1'b0},line_buffer[1][23:16]} + se_r[31:24];
                {overflow[2][7], se_window[2][111:104]} <= {{1'b0},line_buffer[1][31:24]} + se_r[23:16];

                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin//read_pixel_counter[1:0] == 2'b01)begin
                    {overflow[2][8], se_window[2][23:16]} <= {{1'b0},se_r[111:104]};
                    {overflow[2][9], se_window[2][31:24]} <= {{1'b0},se_r[103:96]};

                    {overflow[2][10],se_window[2][55:48]} <= {{1'b0},se_r[79:72]};
                    {overflow[2][11],se_window[2][63:56]} <= {{1'b0},se_r[71:64]};

                    {overflow[2][12],se_window[2][87:80]} <= {{1'b0},se_r[47:40]};
                    {overflow[2][13],se_window[2][95:88]} <= {{1'b0},se_r[39:32]};

                    {overflow[2][14],se_window[2][119:112]} <= {{1'b0},se_r[15:8]};
                    {overflow[2][15],se_window[2][127:120]} <= {{1'b0},se_r[7:0]};
                end
                else begin
                    {overflow[2][8], se_window[2][23:16]} <= {{1'b0},line_buffer[24][7:0]}  + se_r[111:104];
                    {overflow[2][9], se_window[2][31:24]} <= {{1'b0},line_buffer[24][15:8]} + se_r[103:96];

                    {overflow[2][10], se_window[2][55:48]} <= {{1'b0},line_buffer[16][7:0]}  + se_r[79:72];
                    {overflow[2][11], se_window[2][63:56]} <= {{1'b0},line_buffer[16][15:8]} + se_r[71:64];

                    {overflow[2][12], se_window[2][87:80]} <= {{1'b0},line_buffer[8][7:0]}  + se_r[47:40];
                    {overflow[2][13], se_window[2][95:88]} <= {{1'b0},line_buffer[8][15:8]} + se_r[39:32];

                    {overflow[2][14], se_window[2][119:112]} <= {{1'b0},line_buffer[0][7:0]}  + se_r[15:8];
                    {overflow[2][15], se_window[2][127:120]} <= {{1'b0},line_buffer[0][15:8]} + se_r[7:0];
                end
            end
        end
    end
end
// SE window 3
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[3] <= 0;
        se_window[3] <= 0;
    end
    else begin
        if(OP == 'b010 || (OP == 'b110 && second_process == 0) || (OP == 'b111 && second_process == 1)) begin // erosion
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                //normal pixel
                se_window[3][7:0]     <= (line_buffer[25][31:24] > se_r[7:0])   ? line_buffer[25][31:24] - se_r[7:0]  : 0;
                se_window[3][39:32]   <= (line_buffer[17][31:24] > se_r[39:32]) ? line_buffer[17][31:24] - se_r[39:32] : 0;
                se_window[3][71:64]   <= (line_buffer[9][31:24] > se_r[71:64])  ? line_buffer[9][31:24]  - se_r[71:64] : 0;
                se_window[3][103:96]  <= (line_buffer[1][31:24] > se_r[103:96]) ? line_buffer[1][31:24]  - se_r[103:96] : 0;

                //edge pixel
                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin // the rightest 3 pixels
                    se_window[3][15:8] <= 0;
                    se_window[3][23:16] <= 0;
                    se_window[3][31:24] <= 0;

                    se_window[3][47:40] <= 0;
                    se_window[3][55:48] <= 0;
                    se_window[3][63:56] <= 0;

                    se_window[3][79:72] <= 0;
                    se_window[3][87:80] <= 0;
                    se_window[3][95:88] <= 0;

                    se_window[3][111:104] <= 0;
                    se_window[3][119:112] <= 0;
                    se_window[3][127:120] <= 0;
                end
                else begin
                    se_window[3][15:8]  <= (line_buffer[24][7:0]   > se_r[15:8])  ? line_buffer[24][7:0] - se_r[15:8]  : 0;
                    se_window[3][23:16] <= (line_buffer[24][15:8]  > se_r[23:16]) ? line_buffer[24][15:8] - se_r[23:16] : 0;
                    se_window[3][31:24] <= (line_buffer[24][23:16] > se_r[31:24]) ? line_buffer[24][23:16] - se_r[31:24] : 0;

                    se_window[3][47:40] <= (line_buffer[16][7:0]   > se_r[47:40]) ? line_buffer[16][7:0] - se_r[47:40] : 0;
                    se_window[3][55:48] <= (line_buffer[16][15:8]  > se_r[55:48]) ? line_buffer[16][15:8] - se_r[55:48] : 0;
                    se_window[3][63:56] <= (line_buffer[16][23:16] > se_r[63:56]) ? line_buffer[16][23:16] - se_r[63:56] : 0;

                    se_window[3][79:72] <= (line_buffer[8][7:0]   > se_r[79:72]) ? line_buffer[8][7:0] - se_r[79:72] : 0;
                    se_window[3][87:80] <= (line_buffer[8][15:8]  > se_r[87:80]) ? line_buffer[8][15:8] - se_r[87:80] : 0;
                    se_window[3][95:88] <= (line_buffer[8][23:16] > se_r[95:88]) ? line_buffer[8][23:16] - se_r[95:88] : 0;

                    se_window[3][111:104] <= (line_buffer[0][7:0]   > se_r[111:104]) ? line_buffer[0][7:0] - se_r[111:104] : 0;
                    se_window[3][119:112] <= (line_buffer[0][15:8]  > se_r[119:112])  ? line_buffer[0][15:8] - se_r[119:112] : 0;
                    se_window[3][127:120] <= (line_buffer[0][23:16] > se_r[127:120])  ? line_buffer[0][23:16]  - se_r[127:120] : 0;
                end
            end
        end
        else if(OP == 'b011 || (OP == 'b110 && second_process == 1) || (OP == 'b111 && second_process == 0)) begin // dilation
            if(input_cnt>25 || cal_cnt<26) begin // after fill 25 line buffer
                {overflow[3][12], se_window[3][7:0]}   <= {{1'b0},line_buffer[25][31:24]} + se_r[127:120];
                {overflow[3][13], se_window[3][39:32]} <= {{1'b0},line_buffer[17][31:24]} + se_r[95:88];
                {overflow[3][14], se_window[3][71:64]} <= {{1'b0},line_buffer[9][31:24]}  + se_r[63:56];
                {overflow[3][15], se_window[3][103:96]} <= {{1'b0},line_buffer[1][31:24]} + se_r[31:24];

                if(input_cnt[2:0] == 3'b001 || cal_cnt[2:0] == 3'b001)begin
                    {overflow[3][0], se_window[3][15:8]}  <= {{1'b0},se_r[119:112]};
                    {overflow[3][1], se_window[3][23:16]} <= {{1'b0},se_r[111:104]};
                    {overflow[3][2], se_window[3][31:24]} <= {{1'b0},se_r[103:96]};

                    {overflow[3][3], se_window[3][47:40]} <= {{1'b0},se_r[87:80]};
                    {overflow[3][4], se_window[3][55:48]} <= {{1'b0},se_r[79:72]};
                    {overflow[3][5], se_window[3][63:56]} <= {{1'b0},se_r[71:64]};

                    {overflow[3][6], se_window[3][79:72]} <= {{1'b0},se_r[55:48]};
                    {overflow[3][7], se_window[3][87:80]} <= {{1'b0},se_r[47:40]};
                    {overflow[3][8], se_window[3][95:88]} <= {{1'b0},se_r[39:32]};

                    {overflow[3][9], se_window[3][111:104]} <= {{1'b0},se_r[23:16]};
                    {overflow[3][10],se_window[3][119:112]} <= {{1'b0},se_r[15:8]};
                    {overflow[3][11],se_window[3][127:120]} <= {{1'b0},se_r[7:0]};

                end
                else begin
                    {overflow[3][0], se_window[3][15:8]}  <= {{1'b0},line_buffer[24][7:0]} + se_r[119:112];
                    {overflow[3][1], se_window[3][23:16]} <= {{1'b0},line_buffer[24][15:8]} + se_r[111:104];
                    {overflow[3][2], se_window[3][31:24]} <= {{1'b0},line_buffer[24][23:16]} + se_r[103:96];

                    {overflow[3][3], se_window[3][47:40]} <= {{1'b0},line_buffer[16][7:0]} + se_r[87:80];
                    {overflow[3][4], se_window[3][55:48]} <= {{1'b0},line_buffer[16][15:8]} + se_r[79:72];
                    {overflow[3][5], se_window[3][63:56]} <= {{1'b0},line_buffer[16][23:16]}  + se_r[71:64];

                    {overflow[3][6], se_window[3][79:72]} <= {{1'b0},line_buffer[8][7:0]} + se_r[55:48];
                    {overflow[3][7], se_window[3][87:80]} <= {{1'b0},line_buffer[8][15:8]} + se_r[47:40];
                    {overflow[3][8], se_window[3][95:88]} <= {{1'b0},line_buffer[8][23:16]} + se_r[39:32];

                    {overflow[3][9], se_window[3][111:104]} <= {{1'b0},line_buffer[0][7:0]} + se_r[23:16];
                    {overflow[3][10], se_window[3][119:112]} <= {{1'b0},line_buffer[0][15:8]} + se_r[15:8];
                    {overflow[3][11], se_window[3][127:120]} <= {{1'b0},line_buffer[0][23:16]} + se_r[7:0];
                end
            end
        end
        else if(OP == 'b000)
            se_window[3] <= {min_index[0],min_index[1],min_index[2],min_index[3],8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255,8'd255};
    end
end

//======================================
//   histogram
//======================================
// histogram window
generate
for(j = 0 ; j < 4 ; j=j +1 )begin
    for (i = 0; i < 256; i = i + 1) begin
        always @(*)begin
            if(i >= pic_data[j*8+7:j*8])
                histogram_window[j][i] = 'b1;
            else
                histogram_window[j][i] = 'b0;
        end
    end
end
endgenerate

// cdf_table
generate
for(j = 0 ; j < 256 ; j = j +1 )begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            cdf_table[j] <= 0;
        else begin
            if((n_state == s_input_se || n_state == s_input_pic) && input_cnt <= 256 )begin
                cdf_table[j] <= cdf_table[j] + histogram_window[0][j] + histogram_window[1][j] + histogram_window[2][j] + histogram_window[3][j];
            end
            else if(n_state == s_idle)
                cdf_table[j] <= 0;
        end
    end
end
endgenerate

// cdf_table_index
generate
for(i=0 ; i<4 ; i=i+1)begin
    always @(*)begin
        if(cal_cnt > 2 || (n_state == s_output && output_cnt <= 100))  begin
            cdf_table_index[i] <= pic_out_1[i*8+7:i*8];
        end
        else if(output_cnt <= 229)  begin
            cdf_table_index[i] <= pic_out_2[i*8+7:i*8];
        end
        else begin
            cdf_table_index[i] <= 0;
        end
    end
end
endgenerate

// min number index
generate
for(j = 0 ; j < 4 ; j=j +1 )begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) min_index[j] <= 255;
        else begin
            if(n_state == s_idle)
                min_index[j] <= 255;
            else if((n_state == s_input_se || n_state == s_input_pic) && input_cnt <= 256)
                if(pic_data[j*8+7:j*8] < min_index[j])
                    min_index[j] <= pic_data[j*8+7:j*8];
        end
    end
end
endgenerate

//final_min_index
always @(posedge clk or negedge rst_n)begin
    if(!rst_n) final_min_index <= 255;
    else begin
        if(input_cnt > 1 && input_cnt <=256 || cal_cnt == 1) begin
            if(processed_pixel[3] < final_min_index)
                final_min_index <= processed_pixel[3];
        end
        else if(n_state == s_idle)
            final_min_index <= 255;
    end
end

// cdf_Max - cdf_min
always @(posedge clk or negedge rst_n)begin
    if(!rst_n) cdf_Mm <= 0;
    else begin
        if(cal_cnt == 2)
            cdf_Mm <= cdf_table[255] - cdf_table[final_min_index];
        else if(n_state == s_idle)
            cdf_Mm <= 0;
    end
end

// cdf_min
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cdf_m <= 0;
    else begin
        if(n_state == s_cal)
            cdf_m <= cdf_table[final_min_index];
        else if(n_state == s_idle)
            cdf_m <= 0;
    end
end
//======================================
//      DisggnWare
//======================================
assign min_max = (OP=='b000) ? 1'b0: // histogram
                 (OP=='b010) ? 1'b0: // erosion
                 (OP=='b011) ? 1'b1: // dilation
                 (OP=='b110) ? ((second_process==0 || n_state == s_w_sram) ? 1'b0 : 1'b1): // opening
                 (OP=='b111) ? ((second_process==0 || n_state == s_w_sram) ? 1'b1 : 1'b0): //closing
                 1'b0;

DW_minmax #(8,16) MM0  (.a(se_window[0]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[0]), .index(dw_idx));
DW_minmax #(8,16) MM1  (.a(se_window[1]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[1]), .index(dw_idx));
DW_minmax #(8,16) MM2  (.a(se_window[2]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[2]), .index(dw_idx));
DW_minmax #(8,16) MM3  (.a(se_window[3]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[3]), .index(dw_idx));

//======================================
//   SRAM
//======================================
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
// wen_pic_1 //0:write 1:read
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_pic_1 <= 1; // read
	end
	else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if(n_state == s_input_pic && (input_cnt > 26 && input_cnt <155))
                wen_pic_1 <= 0; // write
            else
            wen_pic_1 <= 1;     // read
        end
        else if(OP == 'b110 || OP == 'b111) begin //erosion & dilation
            if(second_process == 0) begin
                if(n_state == s_input_pic && (input_cnt > 26 && input_cnt <155))
                    wen_pic_1 <= 0; // write
                else
                    wen_pic_1 <= 1; // read
            end
            else begin
                wen_pic_1 <= 1; // read
            end
        end
        else if(OP == 'b000) begin // histogran
            if(n_state == s_input_se || (n_state == s_input_pic && input_cnt <= 127))
                wen_pic_1 <= 0; // write
            else
                wen_pic_1 <= 1; // read
        end
	end
end
// wen_pic_2 //0:write 1:read
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_pic_2 <= 1; // read
	end
	else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if((n_state == s_input_pic && input_cnt >= 155) || n_state == s_cal || n_state == s_w_sram)
                wen_pic_2 <= 0; // write
            else
            wen_pic_2 <= 1;
        end
        else if(OP == 'b110 || OP == 'b111) begin //erosion & dilation
            if(second_process == 0) begin
                if((n_state == s_input_pic && input_cnt >= 155) || n_state == s_cal )
                    wen_pic_2 <= 0; // write
                else
                    wen_pic_2 <= 1;
            end
            else if(n_state == s_w_sram)
                wen_pic_2 <= 0;
            else
                wen_pic_2 <= 1;
        end
        else if(OP == 'b000) begin // histogran
            if(n_state == s_input_pic && input_cnt > 127)
                wen_pic_2 <= 0; // write
            else
                wen_pic_2 <= 1; // read
        end
	end
end
// pic_addr_1
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pic_addr_1 <= 0;
	end
	else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if(input_cnt > 27 && input_cnt < 156)
                pic_addr_1 <= pic_addr_1 + 1;
            else if(input_cnt ==255 || n_state == s_cal || n_state == s_w_sram || n_state == s_output)
                pic_addr_1 <= pic_addr_1 + 1;
            else
                pic_addr_1 <= 0;
        end
        else if(OP == 'b110 || OP == 'b111) begin // opening & closing
            if(second_process == 0) begin
                if(input_cnt > 27 && input_cnt < 156 || cal_cnt >= 24)
                    pic_addr_1 <= pic_addr_1 + 1;
                else
                    pic_addr_1 <= 0;
            end
            else if(second_process == 1)begin
                pic_addr_1 <= pic_addr_1 + 1;
            end
        end
        else if(OP == 'b000) begin // histogran
            if((n_state == s_input_se && input_cnt > 0)|| (n_state == s_input_pic && input_cnt <= 127))
                pic_addr_1 <= pic_addr_1 + 1;
            else if(cal_cnt > 1 || (n_state == s_output && output_cnt < 100))
                pic_addr_1 <= pic_addr_1 + 1;
            else
                pic_addr_1 <= 0;
        end
        else begin
            pic_addr_1 <= 0;
        end
    end
end
// pic_addr_2
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pic_addr_2 <= 0;
	end
	else begin
        if(OP == 'b010 || OP == 'b011) begin //erosion & dilation
            if(input_cnt > 155 || n_state == s_cal || n_state == s_w_sram)
                pic_addr_2 <= pic_addr_2 + 1;
            else if(output_cnt >= 100)
                pic_addr_2 <= pic_addr_2 + 1;
            else
                pic_addr_2 <= 0;
        end
        else if(OP == 'b110 || OP == 'b111) begin //erosion & dilation
            if(second_process == 0) begin
                if(input_cnt > 155 || n_state == s_cal )
                    pic_addr_2 <= pic_addr_2 + 1;
                else if(output_cnt >= 100)
                    pic_addr_2 <= pic_addr_2 + 1;
                else
                    pic_addr_2 <= 0;
            end
            else if(second_process == 1 && input_cnt>=127)
                pic_addr_2 <= pic_addr_2 + 1;
            else if(n_state == s_w_sram)
                pic_addr_2 <= pic_addr_2 + 1;
            else
                pic_addr_2 <= 0;
        end
        else if(OP == 'b000) begin // histogran
            if(n_state == s_input_pic && input_cnt > 128)
                pic_addr_2 <= pic_addr_2 + 1;
            else if(output_cnt >= 100)
                pic_addr_2 <= pic_addr_2 + 1;
            else
                pic_addr_2 <= 0;
        end
	end
end
// pic_in
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pic_in <= 0;
	end
	else begin
        if(OP == 'b010 || (OP == 'b110 && (n_state == s_w_sram || second_process == 0)) || (OP == 'b111 && (n_state != s_w_sram && second_process == 1)))begin
            pic_in[7:0] <= processed_pixel[0];
            pic_in[15:8] <= processed_pixel[1];
            pic_in[23:16] <= processed_pixel[2];
            pic_in[31:24] <= processed_pixel[3];
        end
        else if(OP == 'b011 || (OP == 'b110 && second_process == 1) || (OP == 'b111 && (n_state == s_w_sram || second_process == 0))) begin
            pic_in[7:0] <= (overflow[0]) ? 'd255 : processed_pixel[0];
            pic_in[15:8] <= (overflow[1]) ? 'd255 : processed_pixel[1];
            pic_in[23:16] <= (overflow[2]) ? 'd255 : processed_pixel[2];
            pic_in[31:24] <= (overflow[3]) ? 'd255 : processed_pixel[3];
        end
        else if(OP == 'b000) begin
            pic_in <= pic_data;
        end
    end
end


RA1SH SRAM_PIC_1 (.Q(pic_out_1), .CLK(clk),.CEN(cen),.WEN(wen_pic_1),.A(pic_addr_1), .D(pic_in), .OEN(oen));
RA1SH SRAM_PIC_2 (.Q(pic_out_2), .CLK(clk),.CEN(cen),.WEN(wen_pic_2),.A(pic_addr_2), .D(pic_in), .OEN(oen));

endmodule