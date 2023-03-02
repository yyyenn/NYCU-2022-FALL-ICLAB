//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
//synopsys translate_on
//============================================================//
//                        TOP MODULE                          //
//============================================================//
module EDH(
    // Input signals
    clk, rst_n, in_valid, op, pic_no, se_no, busy,

    // axi write address channel
    awid_m_inf   ,
    awaddr_m_inf ,
    awsize_m_inf ,
    awburst_m_inf,
    awlen_m_inf  ,
    awvalid_m_inf,
    awready_m_inf,

    // axi write data channel
    wdata_m_inf  ,
    wlast_m_inf  ,
    wvalid_m_inf ,
    wready_m_inf ,

    // axi write response channel
    bid_m_inf    ,
    bresp_m_inf  ,
    bvalid_m_inf ,
    bready_m_inf ,

    // axi read address channel
    arid_m_inf   ,
    araddr_m_inf ,
    arlen_m_inf  ,
    arsize_m_inf ,
    arburst_m_inf,
    arvalid_m_inf,

    // axi read data channel
    arready_m_inf,
    rid_m_inf    ,
    rdata_m_inf  ,
    rresp_m_inf  ,
    rlast_m_inf  ,
    rvalid_m_inf ,
    rready_m_inf
);

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter ID_WIDTH = 4;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 128;
//state
parameter s_idle  = 3'd0 ;
parameter s_input = 3'd1 ;
parameter s_read  = 3'd2 ;
parameter s_cal  = 3'd3 ;
parameter s_write = 3'd4 ;

genvar i,j;

//======================================
//      INPUT DECLARATION
//======================================
input clk,rst_n;
input in_valid;
input [1:0] op;
input [3:0] pic_no;
input [5:0] se_no;
output reg busy;

// ------ axi write addr channel ------
// master
output [ID_WIDTH-1:0]    awid_m_inf;
output [ADDR_WIDTH-1:0]  awaddr_m_inf;
output [2:0]             awsize_m_inf;
output [1:0]             awburst_m_inf;
output [7:0]             awlen_m_inf;
output                   awvalid_m_inf;
// slave
input                    awready_m_inf;

// ------ axi write data channel ------
// master
output  [DATA_WIDTH-1:0]   wdata_m_inf;
output                     wlast_m_inf;
output                     wvalid_m_inf;
// slave
input                      wready_m_inf;

// ------ axi write resp channel ------
// slave
input [ID_WIDTH-1:0]    bid_m_inf;
input [1:0]             bresp_m_inf;
input                   bvalid_m_inf;
// master
output                  bready_m_inf;

// ------ axi read addr channel ------
// master
output [ID_WIDTH-1:0]    arid_m_inf;
output [ADDR_WIDTH-1:0]  araddr_m_inf;
output [7:0]             arlen_m_inf;
output [2:0]             arsize_m_inf;
output [1:0]             arburst_m_inf;
output                   arvalid_m_inf;
// slave
input                    arready_m_inf;

// ------ axi read data channel ------
// slave
input [ID_WIDTH-1:0]    rid_m_inf;
input [DATA_WIDTH-1:0]  rdata_m_inf;
input [1:0]             rresp_m_inf;
input                   rlast_m_inf;
input                   rvalid_m_inf;
// master
output                  rready_m_inf;

//======================================
//      WIRE and REG
//======================================
reg [2:0]c_state,n_state;

reg [1:0] OP;
reg [3:0] PIC_NO;
reg [5:0] SE_NO;

wire MODE;      //control Axi channel
wire READ;      //control Axi channel
wire WRITE_PIC; //control Axi channel
wire WRITE_SE;  //control Axi channel

reg [DATA_WIDTH-1:0] se_r;
reg [DATA_WIDTH-1:0] se_window [15:0];  // 16 SE windows
reg [255:0] histogram_window [15:0];    // 0~255 histogram table
reg [20:0] cdf_table [255:0];           // cdf table
reg [12:0] cdf_Mm;
reg [12:0] cdf_m;
reg revise_sram_delay;

reg [DATA_WIDTH-1:0] line_buffer [13:0];    // 14 line buffer
wire [7:0] processed_pixel [15:0];          // write into SRAM

// counter for all
reg [7:0] read_pixel_counter;
reg [7:0] cal_pixel_counter;
reg [7:0] write_pixel_counter;
reg [2:0] revise_counter;
// counter for histogram
reg [2:0] min_index_counter;
reg [7:0] new_value_counter;
// histogram min index
reg [7:0] min_index [15:0];

// finish flag
reg read_picture_done;
reg cal_number_done;
reg set_histo_done;
reg set_cdf_done;
reg cal_pixel_done;
reg write_pixel_done;

reg [15:0] overflow [15:0];                  // check dilation add

wire [3:0] dw_idx;
wire min_max;

// connect into Write channel
reg [DATA_WIDTH-1:0] wdata_m_inf_r;
reg [DATA_WIDTH-1:0] sram_delay_wdata_r;
reg [DATA_WIDTH-1:0] sram_delay_wdata_r1;
reg [DATA_WIDTH-1:0] sram_delay_wdata_r2;
reg [DATA_WIDTH-1:0] sram_delay_wdata_r3;

// SRAM in/out port control
reg [7:0] pic_addr;
reg [127:0] pic_in;
wire [127:0] pic_out;
reg cen;
reg wen_pic;
reg wen_se;
reg oen;

//======================================
//      INPUT
//======================================
// op
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        OP <= 0;
    else begin
        case(n_state)
        s_input: OP <= op;
        endcase
    end
end

// pic_no
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        PIC_NO <= 0;
    else begin
        case(n_state)
        s_input: PIC_NO <= pic_no;
        endcase
    end
end

// se_no
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        SE_NO <= 0;
    else begin
        case(n_state)
        s_input: SE_NO <= se_no;
        endcase
    end
end

//======================================
//      READ DATA
//======================================
assign arid_m_inf = 4'b0;
assign arsize_m_inf = 3'b100;
assign arburst_m_inf = 2'b01;

assign READ = (c_state == s_read) ? 1'b1:// && n_state==s_idle) ? 1'b1:
              (c_state == s_cal && !read_picture_done) ? 1'b1:// && n_state==s_read)  ? 1'b1:
              1'b0;
assign MODE = (c_state == s_read) ? 1'b1:
              (c_state == s_cal)  ? 1'b0:
              1'b0;

DRAM_read DRAM_READ(
    // global siignal
    .clk(clk),
    .rst_n(rst_n),

    // image index
    .pic_no(PIC_NO),
    .se_no(SE_NO),

    // state control
    .read(READ),
    .mode(MODE),

    // axi read address channel
    .arid_m_inf(arid_m_inf),
    .araddr_m_inf(araddr_m_inf),
    .arlen_m_inf(arlen_m_inf),
    .arsize_m_inf(arsize_m_inf),
    .arburst_m_inf(arburst_m_inf),
    .arvalid_m_inf(arvalid_m_inf),
    .arready_m_inf(arready_m_inf),

    // axi read data channel
    .rid_m_inf(rid_m_inf),
    .rdata_m_inf(rdata_m_inf),
    .rresp_m_inf(rresp_m_inf),
    .rlast_m_inf(rlast_m_inf),
    .rvalid_m_inf(rvalid_m_inf),
    .rready_m_inf(rready_m_inf)
);

//======================================
//      WRITE DATA
//======================================
reg WRITE_PIC_R;
assign awid_m_inf = 4'b0;
assign awsize_m_inf = 3'b100;
assign awburst_m_inf = 2'b01;

assign WRITE_SE = (c_state == s_read) ? 1'b1 : 1'b0;
assign WRITE_PIC = WRITE_PIC_R;//(n_state == s_write ) ? 1'b1 : 1'b0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) WRITE_PIC_R <= 0;
    else begin
        case(n_state)
        s_write: begin
            case(OP)
                2: WRITE_PIC_R <= (revise_counter<2) ? 'b1 : 'b0;
                default: WRITE_PIC_R <= (revise_counter<1) ? 'b1 : 'b0;
            endcase
        end
        default: WRITE_PIC_R <= 0;
        endcase
    end
end

DRAM_write DRAM_WRITE(
    // global siignal
    .clk(clk),
    .rst_n(rst_n),

    // image index
    .pic_no(PIC_NO),
    .se_no(SE_NO),

    // state control
    .write_se(WRITE_SE),
    .write_pic(WRITE_PIC),

    // axi write address channel
    .awid_m_inf(awid_m_inf),
    .awaddr_m_inf(awaddr_m_inf),
    .awsize_m_inf(awsize_m_inf),
    .awburst_m_inf(awburst_m_inf),
    .awlen_m_inf(awlen_m_inf),
    .awvalid_m_inf(awvalid_m_inf),
    .awready_m_inf(awready_m_inf),

    // axi write data channel
    .wdata_m_inf(wdata_m_inf),
    //.wdata_m_inf(pic_out),
    .wlast_m_inf(wlast_m_inf),
    .wvalid_m_inf(wvalid_m_inf),
    .wready_m_inf(wready_m_inf),

    // axi write response channel
    .bid_m_inf(bid_m_inf),
    .bresp_m_inf(bresp_m_inf),
    .bvalid_m_inf(bvalid_m_inf),
    .bready_m_inf(bready_m_inf)
);
//======================================
//      SETTING REGISTER
//======================================
//output busy
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        busy <= 0;
    else begin
        case(n_state)
        s_read:  busy <= 1;
        s_cal:   busy <= 1;
        s_write: busy <= 1;
        default: busy <= 0;
        endcase
    end
end

// SE info.
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        se_r <= 0;
    else begin
        if(MODE==1 && rready_m_inf && rvalid_m_inf)
            se_r <= rdata_m_inf;
    end
end

// Line Buffer[0]
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        line_buffer[0] <= 0;
    else begin
        if(MODE==0 && rready_m_inf && rvalid_m_inf && ~read_picture_done)
            line_buffer[0] <= rdata_m_inf;
        else
            line_buffer[0] <= 0 ;
    end
end

// Line Buffer[1]~[13]
generate
for(i = 1 ; i < 14 ; i = i + 1)begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            line_buffer[i] <= 0;
        else begin
            line_buffer[i]  <= line_buffer[i-1];
        end
    end
end
endgenerate

// read_pixel_counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_pixel_counter <= 0;
    else begin
        case(n_state)
            // MODE 0: read picture
            // MODE 1: read se
            s_cal: if(MODE==0 && rready_m_inf && rvalid_m_inf && read_pixel_counter<255)begin
                        read_pixel_counter <= read_pixel_counter + 1;
                   end
            default: read_pixel_counter <= 0;
        endcase
    end
end

// read_picture_done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_picture_done <= 0;
    else begin
        case(n_state)
            s_cal:begin
                if(read_pixel_counter==255)begin
                    read_picture_done <= 1;
                end
            end
            default read_picture_done <= 0;
        endcase
    end
end

// cal_pixel_counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_pixel_counter <= 0;
    else begin
        case(n_state)
            s_cal: if(read_pixel_counter<=13)begin
                        cal_pixel_counter <= 0;
                   end
                   else if(read_pixel_counter>13 && read_pixel_counter<255)begin
                        cal_pixel_counter <= read_pixel_counter - 14;
                   end
                   else if(cal_pixel_counter<255) begin
                        cal_pixel_counter <= cal_pixel_counter + 1;
                   end
            default: cal_pixel_counter <= 0;
        endcase
    end
end

// cal_pixel_done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_pixel_done <= 0;
    else begin
        case(n_state)
            s_cal:begin
                case(OP)
                    2: if(new_value_counter==1)begin
                            cal_pixel_done<= 1;
                        end
                    default:begin
                        if(cal_pixel_counter==255)begin
                            cal_pixel_done<= 1;
                        end
                    end
                endcase
            end
            default:cal_pixel_done <= 0;
        endcase
    end
end

// write_pixel_counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        write_pixel_counter <= 0;
    else begin
        case(n_state)
            s_cal: begin
                case(OP)
                2:  write_pixel_counter <= 4;
                default: write_pixel_counter <= 3;
                endcase
            end
            s_write: begin
                if(wready_m_inf && wvalid_m_inf)begin
                    write_pixel_counter <= write_pixel_counter + 1;
                    end
            end
            default: write_pixel_counter <= 0;
        endcase
    end
end

// write_pixel_done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        write_pixel_done <= 0;
    else begin
        case(n_state)
            s_write:begin
                if(write_pixel_counter==255)begin
                    write_pixel_done <= 1;
                end
            end
            default: write_pixel_done <= 0;
        endcase
    end
end

// revise_counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        revise_counter <= 0;
    else begin
        case(n_state)
            s_cal:begin
                case(OP)
                2: revise_counter <= 4;
                default: revise_counter <= 3;
                endcase
            end
            s_write:begin
                if(revise_counter>0)
                     revise_counter <=  revise_counter -1;
            end
            default: revise_counter <= 0;
        endcase
    end
end
//============= for histogram =============//
// cal_number_done (for histogram)
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_number_done <= 0;
    else begin
        case(n_state)
            s_cal:begin
                case(OP)
                    2: if(read_pixel_counter==255)begin
                            cal_number_done<= 1;
                        end
                    default:cal_number_done <= 0;
                endcase
            end
            default:cal_number_done <= 0;
        endcase
    end
end

// set_histo_done (for histogram)
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        set_histo_done <= 0;
    else begin
        case(n_state)
            s_cal:begin
                set_histo_done <= cal_number_done;
            end
            default:set_histo_done <= 0;
        endcase
    end
end

// min_index_counter (for histogram)
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        min_index_counter <= 0;
    else begin
        case(n_state)
            s_cal:begin
                if(set_histo_done)
                    min_index_counter <= min_index_counter + 1;
            end
            default:min_index_counter <= 0;
        endcase
    end
end

// set_cdf_done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        set_cdf_done<= 0;
    else begin
        case(n_state)
            s_cal:begin
                if(min_index_counter==2)
                    set_cdf_done <= 1;
            end
            default:set_cdf_done <= 0;
        endcase
    end
end

// new_value_counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        new_value_counter <= 0;
    else begin
        case(n_state)
            s_cal:begin
                if(set_cdf_done)
                    new_value_counter <= new_value_counter + 1;
            end
            default:new_value_counter <= 0;
        endcase
    end
end
// 16 SE windows
/****************************************************************************************************/
/*                                                                                                  */
/*  se_window_r[i][7:0]    se_window_r[i][15:8]    se_window_r[i][23:16]   se_window_r[i][31:24]    */
/*  se_window_r[i][39:32]  se_window_r[i][47:40]   se_window_r[i][55:48]   se_window_r[i][63:56]    */
/*  se_window_r[i][71:64]  se_window_r[i][79:72]   se_window_r[i][87:80]   se_window_r[i][95:88]    */
/*  se_window_r[i][103:96] se_window_r[i][111:104] se_window_r[i][119:112] se_window_r[i][127:120]  */
/*                                                                                                  */
/****************************************************************************************************/
// SE window 0~12
generate
for(j = 0 ; j < 13 ; j = j +1 )begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            overflow[j] <= 0;
            se_window[j] <= 0;
        end
        else begin
            case(OP)
            // erosion
            0: begin
                if(read_pixel_counter>13) begin // after fill 14 line buffer
                    se_window[j][7:0]   <= (line_buffer[13][7+8*j:0+8*j]   > se_r[7:0])  ? line_buffer[13][7+8*j:0+8*j]   - se_r[7:0]   : 0;
                    se_window[j][15:8]  <= (line_buffer[13][15+8*j:8+8*j]  > se_r[15:8]) ? line_buffer[13][15+8*j:8+8*j]  - se_r[15:8]  : 0;
                    se_window[j][23:16] <= (line_buffer[13][23+8*j:16+8*j] > se_r[23:16])? line_buffer[13][23+8*j:16+8*j] - se_r[23:16] : 0;
                    se_window[j][31:24] <= (line_buffer[13][31+8*j:24+8*j] > se_r[31:24])? line_buffer[13][31+8*j:24+8*j] - se_r[31:24] : 0;

                    se_window[j][39:32] <= (line_buffer[9][7+8*j:0+8*j]   > se_r[39:32]) ? line_buffer[9][7+8*j:0+8*j]   - se_r[39:32] : 0;
                    se_window[j][47:40] <= (line_buffer[9][15+8*j:8+8*j]  > se_r[47:40]) ? line_buffer[9][15+8*j:8+8*j]  - se_r[47:40] : 0;
                    se_window[j][55:48] <= (line_buffer[9][23+8*j:16+8*j] > se_r[55:48]) ? line_buffer[9][23+8*j:16+8*j] - se_r[55:48] : 0;
                    se_window[j][63:56] <= (line_buffer[9][31+8*j:24+8*j] > se_r[63:56]) ? line_buffer[9][31+8*j:24+8*j] - se_r[63:56] : 0;

                    se_window[j][71:64] <= (line_buffer[5][7+8*j:0+8*j]   > se_r[71:64]) ? line_buffer[5][7+8*j:0+8*j]   - se_r[71:64] : 0;
                    se_window[j][79:72] <= (line_buffer[5][15+8*j:8+8*j]  > se_r[79:72]) ? line_buffer[5][15+8*j:8+8*j]  - se_r[79:72] : 0;
                    se_window[j][87:80] <= (line_buffer[5][23+8*j:16+8*j] > se_r[87:80]) ? line_buffer[5][23+8*j:16+8*j] - se_r[87:80] : 0;
                    se_window[j][95:88] <= (line_buffer[5][31+8*j:24+8*j] > se_r[95:88]) ? line_buffer[5][31+8*j:24+8*j] - se_r[95:88] : 0;

                    se_window[j][103:96]  <= (line_buffer[1][7+8*j:0+8*j]   > se_r[103:96])  ? line_buffer[1][7+8*j:0+8*j]   - se_r[103:96]  : 0;
                    se_window[j][111:104] <= (line_buffer[1][15+8*j:8+8*j]  > se_r[111:104]) ? line_buffer[1][15+8*j:8+8*j]  - se_r[111:104] : 0;
                    se_window[j][119:112] <= (line_buffer[1][23+8*j:16+8*j] > se_r[119:112]) ? line_buffer[1][23+8*j:16+8*j] - se_r[119:112] : 0;
                    se_window[j][127:120] <= (line_buffer[1][31+8*j:24+8*j] > se_r[127:120]) ? line_buffer[1][31+8*j:24+8*j] - se_r[127:120] : 0;
                end
            end
            // dilation
            1: begin
                if(read_pixel_counter>13) begin // after fill 14 line buffer
                    {overflow[j][0], se_window[j][7:0]  } <= line_buffer[13][7+8*j:0+8*j]   + se_r[127:120];
                    {overflow[j][1], se_window[j][15:8] } <= line_buffer[13][15+8*j:8+8*j]  + se_r[119:112];
                    {overflow[j][2], se_window[j][23:16]} <= line_buffer[13][23+8*j:16+8*j] + se_r[111:104];
                    {overflow[j][3], se_window[j][31:24]} <= line_buffer[13][31+8*j:24+8*j] + se_r[103:96];

                    {overflow[j][4], se_window[j][39:32]} <= line_buffer[9][7+8*j:0+8*j]   + se_r[95:88];
                    {overflow[j][5], se_window[j][47:40]} <= line_buffer[9][15+8*j:8+8*j]  + se_r[87:80];
                    {overflow[j][6], se_window[j][55:48]} <= line_buffer[9][23+8*j:16+8*j] + se_r[79:72];
                    {overflow[j][7], se_window[j][63:56]} <= line_buffer[9][31+8*j:24+8*j] + se_r[71:64];

                    {overflow[j][8], se_window[j][71:64]} <= line_buffer[5][7+8*j:0+8*j]   +  se_r[63:56];
                    {overflow[j][9], se_window[j][79:72]} <= line_buffer[5][15+8*j:8+8*j]  +  se_r[55:48];
                    {overflow[j][10], se_window[j][87:80]} <= line_buffer[5][23+8*j:16+8*j] + se_r[47:40];
                    {overflow[j][11], se_window[j][95:88]} <= line_buffer[5][31+8*j:24+8*j] + se_r[39:32];

                    {overflow[j][12], se_window[j][103:96]} <= line_buffer[1][7+8*j:0+8*j]   +  se_r[31:24];
                    {overflow[j][13], se_window[j][111:104]} <= line_buffer[1][15+8*j:8+8*j]  + se_r[23:16];
                    {overflow[j][14], se_window[j][119:112]} <= line_buffer[1][23+8*j:16+8*j] + se_r[15:8];
                    {overflow[j][15], se_window[j][127:120]} <= line_buffer[1][31+8*j:24+8*j] + se_r[7:0];
                end
            end
            endcase
        end
    end
end
endgenerate

// SE window 13
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[13] <= 0;
        se_window[13] <= 0;
    end
    else begin
        //if(read_pixel_counter>13) begin // after fill 14 line buffer
        case(OP)
        // erosion
        0: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                //normal pixel
                se_window[13][7:0]   <= (line_buffer[13][111:104] > se_r[7:0])  ? line_buffer[13][111:104] - se_r[7:0]   : 0;
                se_window[13][15:8]  <= (line_buffer[13][119:112] > se_r[15:8]) ? line_buffer[13][119:112] - se_r[15:8]  : 0;
                se_window[13][23:16] <= (line_buffer[13][127:120] > se_r[23:16])? line_buffer[13][127:120] - se_r[23:16] : 0;

                se_window[13][39:32] <= (line_buffer[9][111:104] > se_r[39:32]) ? line_buffer[9][111:104] - se_r[39:32] : 0;
                se_window[13][47:40] <= (line_buffer[9][119:112] > se_r[47:40]) ? line_buffer[9][119:112] - se_r[47:40] : 0;
                se_window[13][55:48] <= (line_buffer[9][127:120] > se_r[55:48]) ? line_buffer[9][127:120] - se_r[55:48] : 0;

                se_window[13][71:64] <= (line_buffer[5][111:104] > se_r[71:64]) ? line_buffer[5][111:104] - se_r[71:64] : 0;
                se_window[13][79:72] <= (line_buffer[5][119:112] > se_r[79:72]) ? line_buffer[5][119:112] - se_r[79:72] : 0;
                se_window[13][87:80] <= (line_buffer[5][127:120] > se_r[87:80]) ? line_buffer[5][127:120] - se_r[87:80] : 0;

                se_window[13][103:96]  <= (line_buffer[1][111:104] > se_r[103:96])  ? line_buffer[1][111:104] - se_r[103:96] : 0;
                se_window[13][111:104] <= (line_buffer[1][119:112] > se_r[111:104]) ? line_buffer[1][119:112] - se_r[111:104] : 0;
                se_window[13][119:112] <= (line_buffer[1][127:120] > se_r[119:112]) ? line_buffer[1][127:120] - se_r[119:112] : 0;
                //edge pixel
                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01) begin// the rightest 3 pixels
                    se_window[13][31:24]   <= 0;
                    se_window[13][63:56]   <= 0;
                    se_window[13][95:88]   <= 0;
                    se_window[13][127:120] <= 0;
                end
                else begin
                    se_window[13][31:24] <= (line_buffer[12][7:0] > se_r[31:24])? line_buffer[12][7:0] - se_r[31:24] : 0;
                    se_window[13][63:56] <= (line_buffer[8][7:0]  > se_r[63:56]) ? line_buffer[8][7:0] - se_r[63:56] : 0;
                    se_window[13][95:88] <= (line_buffer[4][7:0]  > se_r[95:88]) ? line_buffer[4][7:0] - se_r[95:88] : 0;
                    se_window[13][127:120] <= (line_buffer[0][7:0]  > se_r[127:120]) ? line_buffer[0][7:0] - se_r[127:120] : 0;
                end
            end
        end
        // dilation
        1: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                {overflow[13][0], se_window[13][7:0]} <= {{1'b0},line_buffer[13][111:104]} + se_r[127:120];
                {overflow[13][1], se_window[13][15:8]} <= {{1'b0},line_buffer[13][119:112]} + se_r[119:112];
                {overflow[13][2], se_window[13][23:16]} <= {{1'b0},line_buffer[13][127:120]} + se_r[111:104];

                {overflow[13][3], se_window[13][39:32]} <= {{1'b0},line_buffer[9][111:104]} + se_r[95:88];
                {overflow[13][4], se_window[13][47:40]} <= {{1'b0},line_buffer[9][119:112]} + se_r[87:80];
                {overflow[13][5], se_window[13][55:48]} <= {{1'b0},line_buffer[9][127:120]} + se_r[79:72];

                {overflow[13][6], se_window[13][71:64]} <= {{1'b0},line_buffer[5][111:104]} + se_r[63:56];
                {overflow[13][7], se_window[13][79:72]} <= {{1'b0},line_buffer[5][119:112]} + se_r[55:48];
                {overflow[13][8], se_window[13][87:80]} <= {{1'b0},line_buffer[5][127:120]} + se_r[47:40];

                {overflow[13][9], se_window[13][103:96]}  <= {{1'b0},line_buffer[1][111:104]}  + se_r[31:24];
                {overflow[13][10], se_window[13][111:104]} <= {{1'b0},line_buffer[1][119:112]} + se_r[23:16];
                {overflow[13][11], se_window[13][119:112]} <= {{1'b0},line_buffer[1][127:120]} + se_r[15:8];

                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01)begin
                    {overflow[13][12],se_window[13][31:24]}  <=  {{1'b0},se_r[103:96]};
                    {overflow[13][13],se_window[13][63:56]}  <=  {{1'b0},se_r[71:64]};
                    {overflow[13][14],se_window[13][95:88]}  <=  {{1'b0},se_r[39:32]};
                    {overflow[13][15],se_window[13][127:120]} <= {{1'b0},se_r[7:0]};
                end
                else begin
                    {overflow[13][12], se_window[13][31:24]} <= {{1'b0},line_buffer[12][7:0]} +  se_r[103:96];
                    {overflow[13][13], se_window[13][63:56]} <= {{1'b0},line_buffer[8][7:0]}  +  se_r[71:64];
                    {overflow[13][14], se_window[13][95:88]} <= {{1'b0},line_buffer[4][7:0]}  +  se_r[39:32];
                    {overflow[13][15], se_window[13][127:120]} <= {{1'b0},line_buffer[0][7:0]} + se_r[7:0];
                end
            end
        end
        endcase
    end
end
// SE window 14
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[14] <= 0;
        se_window[14] <= 0;
    end
    else begin
        case(OP)
        // erosion
        0: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                //normal pixel
                se_window[14][7:0]   <= (line_buffer[13][119:112] > se_r[7:0])  ? line_buffer[13][119:112] - se_r[7:0]   : 0;
                se_window[14][15:8]  <= (line_buffer[13][127:120] > se_r[15:8]) ? line_buffer[13][127:120] - se_r[15:8]  : 0;

                se_window[14][39:32] <= (line_buffer[9][119:112] > se_r[39:32]) ? line_buffer[9][119:112] - se_r[39:32] : 0;
                se_window[14][47:40] <= (line_buffer[9][127:120] > se_r[47:40]) ? line_buffer[9][127:120] - se_r[47:40] : 0;

                se_window[14][71:64] <= (line_buffer[5][119:112] > se_r[71:64]) ? line_buffer[5][119:112] - se_r[71:64] : 0;
                se_window[14][79:72] <= (line_buffer[5][127:120] > se_r[79:72]) ? line_buffer[5][127:120] - se_r[79:72] : 0;

                se_window[14][103:96]  <= (line_buffer[1][119:112] > se_r[103:96])  ? line_buffer[1][119:112] - se_r[103:96] : 0;
                se_window[14][111:104] <= (line_buffer[1][127:120] > se_r[111:104]) ? line_buffer[1][127:120] - se_r[111:104] : 0;

                //edge pixel
                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01) begin// the rightest 3 pixels
                    se_window[14][23:16] <= 0;
                    se_window[14][31:24] <= 0;

                    se_window[14][55:48] <= 0;
                    se_window[14][63:56] <= 0;

                    se_window[14][87:80] <= 0;
                    se_window[14][95:88] <= 0;

                    se_window[14][119:112] <= 0;
                    se_window[14][127:120] <= 0;
                end
                else begin
                    se_window[14][23:16] <= (line_buffer[12][7:0]  > se_r[23:16])? line_buffer[12][7:0] - se_r[23:16] : 0;
                    se_window[14][31:24] <= (line_buffer[12][15:8] > se_r[31:24])? line_buffer[12][15:8] - se_r[31:24] : 0;

                    se_window[14][55:48] <= (line_buffer[8][7:0]  > se_r[55:48]) ? line_buffer[8][7:0] - se_r[55:48] : 0;
                    se_window[14][63:56] <= (line_buffer[8][15:8] > se_r[63:56]) ? line_buffer[8][15:8] - se_r[63:56] : 0;

                    se_window[14][87:80] <= (line_buffer[4][7:0]  > se_r[87:80]) ? line_buffer[4][7:0] - se_r[87:80] : 0;
                    se_window[14][95:88] <= (line_buffer[4][15:8] > se_r[95:88]) ? line_buffer[4][15:8] - se_r[95:88] : 0;

                    se_window[14][119:112] <= (line_buffer[0][7:0]  > se_r[119:112]) ? line_buffer[0][7:0] - se_r[119:112] : 0;
                    se_window[14][127:120] <= (line_buffer[0][15:8] > se_r[127:120]) ? line_buffer[0][15:8] - se_r[127:120] : 0;
                end
            end
        end
        // dilation
        1: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                {overflow[14][0], se_window[14][7:0]} <=  {{1'b0},line_buffer[13][119:112]}  + se_r[127:120];
                {overflow[14][1], se_window[14][15:8]} <= {{1'b0},line_buffer[13][127:120]}  + se_r[119:112];

                {overflow[14][2], se_window[14][39:32]} <= {{1'b0},line_buffer[9][119:112]} + se_r[95:88];
                {overflow[14][3], se_window[14][47:40]} <= {{1'b0},line_buffer[9][127:120]} + se_r[87:80];

                {overflow[14][4], se_window[14][71:64]} <= {{1'b0},line_buffer[5][119:112]} + se_r[63:56];
                {overflow[14][5], se_window[14][79:72]} <= {{1'b0},line_buffer[5][127:120]} + se_r[55:48];

                {overflow[14][6], se_window[14][103:96]}  <= {{1'b0},line_buffer[1][119:112]} + se_r[31:24];
                {overflow[14][7], se_window[14][111:104]} <= {{1'b0},line_buffer[1][127:120]} + se_r[23:16];

                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01)begin
                    {overflow[14][8], se_window[14][23:16]} <= {{1'b0},se_r[111:104]};
                    {overflow[14][9], se_window[14][31:24]} <= {{1'b0},se_r[103:96]};

                    {overflow[14][10],se_window[14][55:48]} <= {{1'b0},se_r[79:72]};
                    {overflow[14][11],se_window[14][63:56]} <= {{1'b0},se_r[71:64]};

                    {overflow[14][12],se_window[14][87:80]} <= {{1'b0},se_r[47:40]};
                    {overflow[14][13],se_window[14][95:88]} <= {{1'b0},se_r[39:32]};

                    {overflow[14][14],se_window[14][119:112]} <= {{1'b0},se_r[15:8]};
                    {overflow[14][15],se_window[14][127:120]} <= {{1'b0},se_r[7:0]};
                end
                else begin
                    {overflow[14][8], se_window[14][23:16]} <= {{1'b0},line_buffer[12][7:0]}  + se_r[111:104];
                    {overflow[14][9], se_window[14][31:24]} <= {{1'b0},line_buffer[12][15:8]} + se_r[103:96];

                    {overflow[14][10], se_window[14][55:48]} <= {{1'b0},line_buffer[8][7:0]}  + se_r[79:72];
                    {overflow[14][11], se_window[14][63:56]} <= {{1'b0},line_buffer[8][15:8]} + se_r[71:64];

                    {overflow[14][12], se_window[14][87:80]} <= {{1'b0},line_buffer[4][7:0]}  + se_r[47:40];
                    {overflow[14][13], se_window[14][95:88]} <= {{1'b0},line_buffer[4][15:8]} + se_r[39:32];

                    {overflow[14][14], se_window[14][119:112]} <= {{1'b0},line_buffer[0][7:0]}  + se_r[15:8];
                    {overflow[14][15], se_window[14][127:120]} <= {{1'b0},line_buffer[0][15:8]} + se_r[7:0];
                end
            end
        end
        endcase
    end
end
// SE window 15
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        overflow[15] <= 0;
        se_window[15] <= 0;
    end
    else begin
        case(OP)
        // erosion
        0: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                //normal pixel
                se_window[15][7:0]   <= (line_buffer[13][127:120] > se_r[7:0])  ? line_buffer[13][127:120] - se_r[7:0]  : 0;
                se_window[15][39:32] <= (line_buffer[9][127:120] > se_r[39:32]) ? line_buffer[9][127:120] - se_r[39:32] : 0;
                se_window[15][71:64] <= (line_buffer[5][127:120] > se_r[71:64]) ? line_buffer[5][127:120] - se_r[71:64] : 0;
                se_window[15][103:96]  <= (line_buffer[1][127:120] > se_r[103:96])  ? line_buffer[1][127:120] - se_r[103:96] : 0;

                //edge pixel
                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01) begin// the rightest 3 pixels
                    se_window[15][15:8] <= 0;
                    se_window[15][23:16] <= 0;
                    se_window[15][31:24] <= 0;

                    se_window[15][47:40] <= 0;
                    se_window[15][55:48] <= 0;
                    se_window[15][63:56] <= 0;

                    se_window[15][79:72] <= 0;
                    se_window[15][87:80] <= 0;
                    se_window[15][95:88] <= 0;

                    se_window[15][111:104] <= 0;
                    se_window[15][119:112] <= 0;
                    se_window[15][127:120] <= 0;
                end
                else begin
                    se_window[15][15:8]  <= (line_buffer[12][7:0]   > se_r[15:8])  ? line_buffer[12][7:0] - se_r[15:8]  : 0;
                    se_window[15][23:16] <= (line_buffer[12][15:8]  > se_r[23:16]) ? line_buffer[12][15:8] - se_r[23:16] : 0;
                    se_window[15][31:24] <= (line_buffer[12][23:16] > se_r[31:24]) ? line_buffer[12][23:16] - se_r[31:24] : 0;

                    se_window[15][47:40] <= (line_buffer[8][7:0]   > se_r[47:40]) ? line_buffer[8][7:0] - se_r[47:40] : 0;
                    se_window[15][55:48] <= (line_buffer[8][15:8]  > se_r[55:48]) ? line_buffer[8][15:8] - se_r[55:48] : 0;
                    se_window[15][63:56] <= (line_buffer[8][23:16] > se_r[63:56]) ? line_buffer[8][23:16] - se_r[63:56] : 0;

                    se_window[15][79:72] <= (line_buffer[4][7:0]   > se_r[79:72]) ? line_buffer[4][7:0] - se_r[79:72] : 0;
                    se_window[15][87:80] <= (line_buffer[4][15:8]  > se_r[87:80]) ? line_buffer[4][15:8]  - se_r[87:80] : 0;
                    se_window[15][95:88] <= (line_buffer[4][23:16] > se_r[95:88]) ? line_buffer[4][23:16]  - se_r[95:88] : 0;

                    se_window[15][111:104] <= (line_buffer[0][7:0]   > se_r[111:104]) ? line_buffer[0][7:0] - se_r[111:104] : 0;
                    se_window[15][119:112] <= (line_buffer[0][15:8]  > se_r[119:112])  ? line_buffer[0][15:8]  - se_r[119:112] : 0;
                    se_window[15][127:120] <= (line_buffer[0][23:16] > se_r[127:120])  ? line_buffer[0][23:16]   - se_r[127:120] : 0;
                end
            end
        end
        // dilation
        1: begin
            if(read_pixel_counter>13) begin // after fill 14 line buffer
                {overflow[15][12], se_window[15][7:0]}  <= {{1'b0},line_buffer[13][127:120]} + se_r[127:120];
                {overflow[15][13], se_window[15][39:32]} <= {{1'b0},line_buffer[9][127:120]} + se_r[95:88];
                {overflow[15][14], se_window[15][71:64]} <= {{1'b0},line_buffer[5][127:120]} + se_r[63:56];
                {overflow[15][15], se_window[15][103:96]} <= {{1'b0},line_buffer[1][127:120]} + se_r[31:24];

                if(cal_pixel_counter[1:0] == 2'b10)begin//read_pixel_counter[1:0] == 2'b01)begin
                    {overflow[15][0], se_window[15][15:8]} <= {{1'b0},se_r[119:112]};
                    {overflow[15][1], se_window[15][23:16]} <= {{1'b0},se_r[111:104]};
                    {overflow[15][2], se_window[15][31:24]} <= {{1'b0},se_r[103:96]};

                    {overflow[15][3], se_window[15][47:40]} <= {{1'b0},se_r[87:80]};
                    {overflow[15][4], se_window[15][55:48]} <= {{1'b0},se_r[79:72]};
                    {overflow[15][5], se_window[15][63:56]} <= {{1'b0},se_r[71:64]};

                    {overflow[15][6], se_window[15][79:72]} <= {{1'b0},se_r[55:48]};
                    {overflow[15][7], se_window[15][87:80]} <= {{1'b0},se_r[47:40]};
                    {overflow[15][8], se_window[15][95:88]} <= {{1'b0},se_r[39:32]};

                    {overflow[15][9], se_window[15][111:104]} <= {{1'b0},se_r[23:16]};
                    {overflow[15][10],se_window[15][119:112]} <= {{1'b0},se_r[15:8]};
                    {overflow[15][11],se_window[15][127:120]} <= {{1'b0},se_r[7:0]};

                end
                else begin
                    {overflow[15][0], se_window[15][15:8]} <= {{1'b0},line_buffer[12][7:0]} + se_r[119:112];
                    {overflow[15][1], se_window[15][23:16]} <= {{1'b0},line_buffer[12][15:8]} + se_r[111:104];
                    {overflow[15][2], se_window[15][31:24]} <= {{1'b0},line_buffer[12][23:16]} + se_r[103:96];

                    {overflow[15][3], se_window[15][47:40]} <= {{1'b0},line_buffer[8][7:0]} + se_r[87:80];
                    {overflow[15][4], se_window[15][55:48]} <= {{1'b0},line_buffer[8][15:8]} + se_r[79:72];
                    {overflow[15][5], se_window[15][63:56]} <= {{1'b0},line_buffer[8][23:16]}  + se_r[71:64];

                    {overflow[15][6], se_window[15][79:72]} <= {{1'b0},line_buffer[4][7:0]} + se_r[55:48];
                    {overflow[15][7], se_window[15][87:80]} <= {{1'b0},line_buffer[4][15:8]} + se_r[47:40];
                    {overflow[15][8], se_window[15][95:88]} <= {{1'b0},line_buffer[4][23:16]} + se_r[39:32];

                    {overflow[15][9], se_window[15][111:104]} <= {{1'b0},line_buffer[0][7:0]} + se_r[23:16];
                    {overflow[15][10], se_window[15][119:112]} <= {{1'b0},line_buffer[0][15:8]} + se_r[15:8];
                    {overflow[15][11], se_window[15][127:120]} <= {{1'b0},line_buffer[0][23:16]} + se_r[7:0];
                end
            end
        end
        2: se_window[15] <= {min_index[0],min_index[1],min_index[2],min_index[3],min_index[4],min_index[5],min_index[6],min_index[7],min_index[8],min_index[9],min_index[10],min_index[11],min_index[12],min_index[13],min_index[14],min_index[15]};
        endcase
    end
end

//======================================
//   histogram
//======================================
reg [7:0] final_min_index;
// min number index
generate
for(j = 0 ; j < 16 ; j=j +1 )begin
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) min_index[j] <= 255;
        else begin
            case(c_state)
                s_cal: begin
                    if(read_pixel_counter>0)begin
                        if(pic_in[j*8+7:j*8] < min_index[j])
                            min_index[j] <= pic_in[j*8+7:j*8];
                    end
                    else min_index[j] <= 255;
                end
                default: min_index[j] <= 255;
            endcase
        end
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n) final_min_index <= 255;
    else begin
        case(c_state)
            s_idle: final_min_index <= 255;
            s_cal: begin
                if(read_pixel_counter>0)begin
                   if(processed_pixel[15]<final_min_index)
                        final_min_index <= processed_pixel[15];
                end
            end

        endcase
    end
end

endgenerate
// histogram window
generate
for(j = 0 ; j < 16 ; j=j +1 )begin
    for (i = 0; i < 256; i = i + 1) begin
        always @(*)begin
            case(c_state)
                s_cal:begin
                    if(read_pixel_counter>0)begin
                        if(pic_in[j*8+7:j*8] <= i) histogram_window[j][i] = 1'b1;
                        else histogram_window[j][i] = 0;
                    end
                    else histogram_window[j][i] = 0;
                end
                default: histogram_window[j][i] = 0;
            endcase
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
            case(n_state)
                s_idle: cdf_table[j] <= 0;
                s_cal: begin
                    if((rready_m_inf && rvalid_m_inf  && !set_histo_done) || (read_picture_done && !revise_sram_delay))begin
                        cdf_table[j] <= cdf_table[j] + histogram_window[0][j] + histogram_window[1][j] + histogram_window[2][j] + histogram_window[3][j]
                                                     + histogram_window[4][j] + histogram_window[5][j] + histogram_window[6][j] + histogram_window[7][j]
                                                     + histogram_window[8][j] + histogram_window[9][j] + histogram_window[10][j] + histogram_window[11][j]
                                                     + histogram_window[12][j] + histogram_window[13][j] + histogram_window[14][j] + histogram_window[15][j];
                    end
                    else begin
                        case(new_value_counter)
                            1: cdf_table[j] <= (((cdf_table[j] - cdf_m)<<8) - (cdf_table[j] - cdf_m));
                        endcase
                    end
                end
            endcase
        end
    end
end
endgenerate

// cdf_Max - cdf_min
always @(posedge clk or negedge rst_n)begin
    if(!rst_n) cdf_Mm <= 0;
    else begin
        case(n_state)
            s_idle: cdf_Mm <= 0;
            s_cal: begin
                if(min_index_counter==2)
                    cdf_Mm <= cdf_table[255] - cdf_table[final_min_index];
            end
        endcase
    end
end

// cdf_min
always @(posedge clk or negedge rst_n)begin
    if(!rst_n) cdf_m <= 0;
    else begin
        case(n_state)
            s_cal: begin
                if(min_index_counter==2)
                    cdf_m <= cdf_table[final_min_index];
            end
            default: cdf_m <= 0;
        endcase
    end
end
//======================================
//      DisggnWare
//======================================
assign min_max = (OP==0) ? 1'b0:
                 (OP==1) ? 1'b1:
                 1'b0;

DW_minmax #(8,16) MM0  (.a(se_window[0]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[0]), .index(dw_idx));
DW_minmax #(8,16) MM1  (.a(se_window[1]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[1]), .index(dw_idx));
DW_minmax #(8,16) MM2  (.a(se_window[2]) ,.tc(1'b0), .min_max(min_max), .value(processed_pixel[2]), .index(dw_idx));
DW_minmax #(8,16) MM3  (.a(se_window[3]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[3]), .index(dw_idx));
DW_minmax #(8,16) MM4  (.a(se_window[4]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[4]), .index(dw_idx));
DW_minmax #(8,16) MM5  (.a(se_window[5]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[5]), .index(dw_idx));
DW_minmax #(8,16) MM6  (.a(se_window[6]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[6]), .index(dw_idx));
DW_minmax #(8,16) MM7  (.a(se_window[7]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[7]), .index(dw_idx));
DW_minmax #(8,16) MM8  (.a(se_window[8]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[8]), .index(dw_idx));
DW_minmax #(8,16) MM9  (.a(se_window[9]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[9]), .index(dw_idx));
DW_minmax #(8,16) MM10 (.a(se_window[10]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[10]), .index(dw_idx));
DW_minmax #(8,16) MM11 (.a(se_window[11]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[11]), .index(dw_idx));
DW_minmax #(8,16) MM12 (.a(se_window[12]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[12]), .index(dw_idx));
DW_minmax #(8,16) MM13 (.a(se_window[13]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[13]), .index(dw_idx));
DW_minmax #(8,16) MM14 (.a(se_window[14]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[14]), .index(dw_idx));
DW_minmax #(8,16) MM15 (.a(se_window[15]), .tc(1'b0), .min_max(min_max), .value(processed_pixel[15]), .index(dw_idx));

reg [7:0]cdf_table_index[15:0];

generate
for(i=0 ; i<16 ; i=i+1)begin
    always @(*)begin
        /* if((wready_m_inf && !revise_sram_delay)) begin
             cdf_table_index[i] <= sram_delay_wdata_r1[i*8+7:i*8];
         end*/
        if(write_pixel_counter==5)  begin
            cdf_table_index[i] <= sram_delay_wdata_r2[i*8+7:i*8];
        end
        else if(write_pixel_counter==6) begin
            cdf_table_index[i] <= sram_delay_wdata_r3[i*8+7:i*8];
        end
        else begin
            cdf_table_index[i] <= sram_delay_wdata_r[i*8+7:i*8];
        end
    end
end
endgenerate

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
// wen_pic //0:write 1:read
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wen_pic <= 1; // read
	end
	else begin
        case(n_state)
        s_cal:begin
            case(OP)
                2: if(read_picture_done) wen_pic <= 1;
                   else wen_pic <= 0;
                default: wen_pic <= 0;
            endcase
        end
        s_write:  wen_pic <= 1;
        default:  wen_pic <= 1;
		endcase
	end
end
// pic_addr
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pic_addr <= 0;
	end
	else begin
        case(n_state)
        s_cal:begin
            case(OP)
            2: if(!read_picture_done) pic_addr <= read_pixel_counter;
               else pic_addr <= 0;
            default:pic_addr <= cal_pixel_counter;
            endcase
        end
        s_write:begin
            if(wvalid_m_inf && wready_m_inf)
                    pic_addr <= write_pixel_counter;
                else pic_addr <= (revise_counter>0) ? revise_counter-1 : revise_counter;
        end
        default: pic_addr <= 0;
		endcase
	end
end
// pic_in
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pic_in <= 0;
	end
	else begin
        case(n_state)
        s_cal:begin
            case(OP)
            0: begin
                pic_in[7:0] <= processed_pixel[0];
                pic_in[15:8] <= processed_pixel[1];
                pic_in[23:16] <= processed_pixel[2];
                pic_in[31:24] <= processed_pixel[3];
                pic_in[39:32] <= processed_pixel[4];
                pic_in[47:40] <= processed_pixel[5];
                pic_in[55:48] <= processed_pixel[6];
                pic_in[63:56] <= processed_pixel[7];
                pic_in[71:64] <= processed_pixel[8];
                pic_in[79:72] <= processed_pixel[9];
                pic_in[87:80] <= processed_pixel[10];
                pic_in[95:88] <= processed_pixel[11];
                pic_in[103:96] <= processed_pixel[12];
                pic_in[111:104] <= processed_pixel[13];
                pic_in[119:112] <= processed_pixel[14];
                pic_in[127:120] <= processed_pixel[15];
            end
            1: begin
                pic_in[7:0] <= (overflow[0]) ? 'd255 : processed_pixel[0];
                pic_in[15:8] <= (overflow[1]) ? 'd255 : processed_pixel[1];
                pic_in[23:16] <= (overflow[2]) ? 'd255 : processed_pixel[2];
                pic_in[31:24] <= (overflow[3]) ? 'd255 : processed_pixel[3];
                pic_in[39:32] <= (overflow[4]) ? 'd255 : processed_pixel[4];
                pic_in[47:40] <= (overflow[5]) ? 'd255 : processed_pixel[5];
                pic_in[55:48] <= (overflow[6]) ? 'd255 : processed_pixel[6];
                pic_in[63:56] <= (overflow[7]) ? 'd255 : processed_pixel[7];
                pic_in[71:64] <= (overflow[8]) ? 'd255 : processed_pixel[8];
                pic_in[79:72] <= (overflow[9]) ? 'd255 : processed_pixel[9];
                pic_in[87:80] <= (overflow[10]) ? 'd255 : processed_pixel[10];
                pic_in[95:88] <= (overflow[11]) ? 'd255 : processed_pixel[11];
                pic_in[103:96] <= (overflow[12]) ? 'd255 : processed_pixel[12];
                pic_in[111:104] <= (overflow[13]) ? 'd255 : processed_pixel[13];
                pic_in[119:112] <= (overflow[14]) ? 'd255 : processed_pixel[14];
                pic_in[127:120] <= (overflow[15]) ? 'd255 : processed_pixel[15];
            end
            2: pic_in <= rdata_m_inf;
            endcase
        end
        default:   pic_in <= 0;
		endcase
	end
end

// pic_out => wdata_m_inf
assign wdata_m_inf = wdata_m_inf_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) wdata_m_inf_r <= 0;
    else begin
    case(OP)
        2:begin
            if(n_state==s_write)begin
                if((wready_m_inf && !revise_sram_delay)) begin
                    wdata_m_inf_r[7:0] <= cdf_table[sram_delay_wdata_r1[7:0]] / cdf_Mm;
                    wdata_m_inf_r[15:8] <= cdf_table[sram_delay_wdata_r1[15:8]] / cdf_Mm;
                    wdata_m_inf_r[23:16] <= cdf_table[sram_delay_wdata_r1[23:16]] / cdf_Mm;
                    wdata_m_inf_r[31:24] <= cdf_table[sram_delay_wdata_r1[31:24]] / cdf_Mm;
                    wdata_m_inf_r[39:32] <= cdf_table[sram_delay_wdata_r1[39:32]] / cdf_Mm;
                    wdata_m_inf_r[47:40] <= cdf_table[sram_delay_wdata_r1[47:40]] / cdf_Mm;
                    wdata_m_inf_r[55:48] <= cdf_table[sram_delay_wdata_r1[55:48]] / cdf_Mm;
                    wdata_m_inf_r[63:56] <= cdf_table[sram_delay_wdata_r1[63:56]] / cdf_Mm;
                    wdata_m_inf_r[71:64] <= cdf_table[sram_delay_wdata_r1[71:64]] / cdf_Mm;
                    wdata_m_inf_r[79:72] <= cdf_table[sram_delay_wdata_r1[79:72]] / cdf_Mm;
                    wdata_m_inf_r[87:80] <= cdf_table[sram_delay_wdata_r1[87:80]] / cdf_Mm;
                    wdata_m_inf_r[95:88] <= cdf_table[sram_delay_wdata_r1[95:88]] / cdf_Mm;
                    wdata_m_inf_r[103:96] <= cdf_table[sram_delay_wdata_r1[103:96]] / cdf_Mm;
                    wdata_m_inf_r[111:104] <= cdf_table[sram_delay_wdata_r1[111:104]] / cdf_Mm;
                    wdata_m_inf_r[119:112] <= cdf_table[sram_delay_wdata_r1[119:112]] / cdf_Mm;
                    wdata_m_inf_r[127:120] <= cdf_table[sram_delay_wdata_r1[127:120]] / cdf_Mm;
                end
                else begin
                    wdata_m_inf_r[7:0] <= cdf_table[cdf_table_index[0]] / cdf_Mm;
                    wdata_m_inf_r[15:8] <= cdf_table[cdf_table_index[1]] / cdf_Mm;
                    wdata_m_inf_r[23:16] <= cdf_table[cdf_table_index[2]] / cdf_Mm;
                    wdata_m_inf_r[31:24] <= cdf_table[cdf_table_index[3]] / cdf_Mm;
                    wdata_m_inf_r[39:32] <= cdf_table[cdf_table_index[4]] / cdf_Mm;
                    wdata_m_inf_r[47:40] <= cdf_table[cdf_table_index[5]] / cdf_Mm;
                    wdata_m_inf_r[55:48] <= cdf_table[cdf_table_index[6]] / cdf_Mm;
                    wdata_m_inf_r[63:56] <= cdf_table[cdf_table_index[7]] / cdf_Mm;
                    wdata_m_inf_r[71:64] <= cdf_table[cdf_table_index[8]] / cdf_Mm;
                    wdata_m_inf_r[79:72] <= cdf_table[cdf_table_index[9]] / cdf_Mm;
                    wdata_m_inf_r[87:80] <= cdf_table[cdf_table_index[10]] / cdf_Mm;
                    wdata_m_inf_r[95:88] <= cdf_table[cdf_table_index[11]] / cdf_Mm;
                    wdata_m_inf_r[103:96] <= cdf_table[cdf_table_index[12]] / cdf_Mm;
                    wdata_m_inf_r[111:104] <= cdf_table[cdf_table_index[13]] / cdf_Mm;
                    wdata_m_inf_r[119:112] <= cdf_table[cdf_table_index[14]] / cdf_Mm;
                    wdata_m_inf_r[127:120] <= cdf_table[cdf_table_index[15]] / cdf_Mm;
                end
            end
            /*else if(write_pixel_counter==5)  begin
                wdata_m_inf_r[7:0] <= cdf_table[sram_delay_wdata_r2[7:0]] / cdf_Mm;
                wdata_m_inf_r[15:8] <= cdf_table[sram_delay_wdata_r2[15:8]] / cdf_Mm;
                wdata_m_inf_r[23:16] <= cdf_table[sram_delay_wdata_r2[23:16]] / cdf_Mm;
                wdata_m_inf_r[31:24] <= cdf_table[sram_delay_wdata_r2[31:24]] / cdf_Mm;
                wdata_m_inf_r[39:32] <= cdf_table[sram_delay_wdata_r2[39:32]] / cdf_Mm;
                wdata_m_inf_r[47:40] <= cdf_table[sram_delay_wdata_r2[47:40]] / cdf_Mm;
                wdata_m_inf_r[55:48] <= cdf_table[sram_delay_wdata_r2[55:48]] / cdf_Mm;
                wdata_m_inf_r[63:56] <= cdf_table[sram_delay_wdata_r2[63:56]] / cdf_Mm;
                wdata_m_inf_r[71:64] <= cdf_table[sram_delay_wdata_r2[71:64]] / cdf_Mm;
                wdata_m_inf_r[79:72] <= cdf_table[sram_delay_wdata_r2[79:72]] / cdf_Mm;
                wdata_m_inf_r[87:80] <= cdf_table[sram_delay_wdata_r2[87:80]] / cdf_Mm;
                wdata_m_inf_r[95:88] <= cdf_table[sram_delay_wdata_r2[95:88]] / cdf_Mm;
                wdata_m_inf_r[103:96] <= cdf_table[sram_delay_wdata_r2[103:96]] / cdf_Mm;
                wdata_m_inf_r[111:104] <= cdf_table[sram_delay_wdata_r2[111:104]] / cdf_Mm;
                wdata_m_inf_r[119:112] <= cdf_table[sram_delay_wdata_r2[119:112]] / cdf_Mm;
                wdata_m_inf_r[127:120] <= cdf_table[sram_delay_wdata_r2[127:120]] / cdf_Mm;
            end
            else if(write_pixel_counter==6) begin
                wdata_m_inf_r[7:0] <= cdf_table[sram_delay_wdata_r3[7:0]] / cdf_Mm;
                wdata_m_inf_r[15:8] <= cdf_table[sram_delay_wdata_r3[15:8]] / cdf_Mm;
                wdata_m_inf_r[23:16] <= cdf_table[sram_delay_wdata_r3[23:16]] / cdf_Mm;
                wdata_m_inf_r[31:24] <= cdf_table[sram_delay_wdata_r3[31:24]] / cdf_Mm;
                wdata_m_inf_r[39:32] <= cdf_table[sram_delay_wdata_r3[39:32]] / cdf_Mm;
                wdata_m_inf_r[47:40] <= cdf_table[sram_delay_wdata_r3[47:40]] / cdf_Mm;
                wdata_m_inf_r[55:48] <= cdf_table[sram_delay_wdata_r3[55:48]] / cdf_Mm;
                wdata_m_inf_r[63:56] <= cdf_table[sram_delay_wdata_r3[63:56]] / cdf_Mm;
                wdata_m_inf_r[71:64] <= cdf_table[sram_delay_wdata_r3[71:64]] / cdf_Mm;
                wdata_m_inf_r[79:72] <= cdf_table[sram_delay_wdata_r3[79:72]] / cdf_Mm;
                wdata_m_inf_r[87:80] <= cdf_table[sram_delay_wdata_r3[87:80]] / cdf_Mm;
                wdata_m_inf_r[95:88] <= cdf_table[sram_delay_wdata_r3[95:88]] / cdf_Mm;
                wdata_m_inf_r[103:96] <= cdf_table[sram_delay_wdata_r3[103:96]] / cdf_Mm;
                wdata_m_inf_r[111:104] <= cdf_table[sram_delay_wdata_r3[111:104]] / cdf_Mm;
                wdata_m_inf_r[119:112] <= cdf_table[sram_delay_wdata_r3[119:112]] / cdf_Mm;
                wdata_m_inf_r[127:120] <= cdf_table[sram_delay_wdata_r3[127:120]] / cdf_Mm;
            end
            else begin
                wdata_m_inf_r[7:0] <= cdf_table[sram_delay_wdata_r[7:0]] / cdf_Mm;
                wdata_m_inf_r[15:8] <= cdf_table[sram_delay_wdata_r[15:8]] / cdf_Mm;
                wdata_m_inf_r[23:16] <= cdf_table[sram_delay_wdata_r[23:16]] / cdf_Mm;
                wdata_m_inf_r[31:24] <= cdf_table[sram_delay_wdata_r[31:24]] / cdf_Mm;
                wdata_m_inf_r[39:32] <= cdf_table[sram_delay_wdata_r[39:32]] / cdf_Mm;
                wdata_m_inf_r[47:40] <= cdf_table[sram_delay_wdata_r[47:40]] / cdf_Mm;
                wdata_m_inf_r[55:48] <= cdf_table[sram_delay_wdata_r[55:48]] / cdf_Mm;
                wdata_m_inf_r[63:56] <= cdf_table[sram_delay_wdata_r[63:56]] / cdf_Mm;
                wdata_m_inf_r[71:64] <= cdf_table[sram_delay_wdata_r[71:64]] / cdf_Mm;
                wdata_m_inf_r[79:72] <= cdf_table[sram_delay_wdata_r[79:72]] / cdf_Mm;
                wdata_m_inf_r[87:80] <= cdf_table[sram_delay_wdata_r[87:80]] / cdf_Mm;
                wdata_m_inf_r[95:88] <= cdf_table[sram_delay_wdata_r[95:88]] / cdf_Mm;
                wdata_m_inf_r[103:96] <= cdf_table[sram_delay_wdata_r[103:96]] / cdf_Mm;
                wdata_m_inf_r[111:104] <= cdf_table[sram_delay_wdata_r[111:104]] / cdf_Mm;
                wdata_m_inf_r[119:112] <= cdf_table[sram_delay_wdata_r[119:112]] / cdf_Mm;
                wdata_m_inf_r[127:120] <= cdf_table[sram_delay_wdata_r[127:120]] / cdf_Mm;
            end*/
        end
        default: begin
            if(wready_m_inf && !revise_sram_delay) wdata_m_inf_r <= sram_delay_wdata_r;
            else if(write_pixel_counter==4)  wdata_m_inf_r <= sram_delay_wdata_r1;
            else wdata_m_inf_r <= pic_out;
        end
    endcase
    end
end

// revise_sram_delay
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        revise_sram_delay <= 0;
    else begin
        case(n_state)
            s_cal: begin
                if(read_picture_done)
                    revise_sram_delay <= 1;
            end
            s_write: begin
                if(pic_addr==1)
                    revise_sram_delay <= 1;
                else if(wready_m_inf && wvalid_m_inf)
                    revise_sram_delay <= 1;
                else
                    revise_sram_delay <= 0;
            end
            default: revise_sram_delay <= 0;
        endcase
    end
end

// sram_delay_wdata_r
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sram_delay_wdata_r <= 0;
    else begin
        case(n_state)
        s_write:begin
            case(OP)
            2: sram_delay_wdata_r <= pic_out;
            default: begin
                if(revise_sram_delay )
                    sram_delay_wdata_r <= pic_out;
            end
            endcase
        end
        default: sram_delay_wdata_r <= 0;
        endcase
    end
end

// sram_delay_wdata_r1
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sram_delay_wdata_r1 <= 0;
    else begin
        case(OP)
            2: begin
                if(pic_addr==0 && revise_sram_delay)
                    sram_delay_wdata_r1 <= pic_out;
            end
            default: begin
                if(pic_addr==1)
                    sram_delay_wdata_r1 <= pic_out;
            end
        endcase
    end
end

// sram_delay_wdata_r2
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sram_delay_wdata_r2 <= 0;
    else begin
        case(OP)
            2: begin
                if(pic_addr==1)
                    sram_delay_wdata_r2 <= pic_out;
            end
            default: begin
                sram_delay_wdata_r2 <= 0;
            end
        endcase
    end
end

// sram_delay_wdata_r3
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sram_delay_wdata_r3 <= 0;
    else begin
        case(OP)
            2: begin
                if(pic_addr==2)
                    sram_delay_wdata_r3 <= pic_out;
            end
            default: begin
                sram_delay_wdata_r3 <= 0;
            end
        endcase
    end
end


RA1SH_pic SRAM_pic (.Q(pic_out), .CLK(clk),.CEN(cen),.WEN(wen_pic),.A(pic_addr), .D(pic_in), .OEN(oen));

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
    s_idle:  if(in_valid)       n_state = s_input;
	         else    	        n_state = s_idle;
    s_input: if(in_valid)       n_state = s_input;
             else               n_state = s_read;
    s_read  :if(rlast_m_inf)    n_state = s_cal;
             else               n_state = s_read;
    s_cal:   if(cal_pixel_done) n_state = s_write;
             else               n_state = s_cal;
    s_write: if(wlast_m_inf)    n_state = s_idle;
             else               n_state = s_write;
    default: n_state = c_state;
    endcase
end

endmodule

//============================================================//
//                 SUBMODULE - DRAM READ                      //
//============================================================//

module DRAM_read(
    // global siignal
    clk,
    rst_n,

    // Image Index
    pic_no,
    se_no,

    // State Control
    read,
    mode,

    // axi read address channel
    arid_m_inf,
    araddr_m_inf,
    arlen_m_inf,
    arsize_m_inf,
    arburst_m_inf,
    arvalid_m_inf,
    arready_m_inf,

    // axi read data channel
    rid_m_inf,
    rdata_m_inf,
    rresp_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    rready_m_inf
);

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter ID_WIDTH = 4;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 128;

//FSM
parameter s_idle = 2'd0;
parameter s_AddrRead = 2'd1;
parameter s_DataRead = 2'd2;
//======================================
//        INPUT DECLARATION
//======================================
// global signal
input clk;
input rst_n;

// image index
input [3:0] pic_no;
input [5:0] se_no;

// state control
input read;
input mode;

// axi read addr channel
output [ID_WIDTH-1:0]    arid_m_inf;    // fix - 0
output [ADDR_WIDTH-1:0]  araddr_m_inf;
output [7:0]             arlen_m_inf;   // set 0~255
output [2:0]             arsize_m_inf;  // fix - 16bytes
output [1:0]             arburst_m_inf; // fix - increase
output                   arvalid_m_inf;
input                    arready_m_inf;

// axi read data channel
input [ID_WIDTH-1:0]    rid_m_inf;    // fix
input [DATA_WIDTH-1:0]  rdata_m_inf;
input [1:0]             rresp_m_inf;  // fix
input                   rlast_m_inf;
input                   rvalid_m_inf;
output                  rready_m_inf;

//======================================
//        WIRE and REG
//======================================
reg [1:0] c_state,n_state;

// 0:pic 1:se
//reg mode;

// FSM
reg read_addr_done;
reg read_data_done;


reg [7:0] counter;
reg [7:0] read_data_counter;

// Read Address Chanel
reg [ADDR_WIDTH-1:0] araddr_m_inf_r;
reg arvalid_m_inf_r;

// Read Data Chanel
reg [DATA_WIDTH-1:0] rdata_m_inf_r;
reg                  rready_m_inf_r;

//======================================
//        Read Address Chanel
//======================================
assign araddr_m_inf = araddr_m_inf_r;
assign arlen_m_inf = (mode) ? 8'd0 : 8'd255 ; // 0:pic 1:se
assign arvalid_m_inf = arvalid_m_inf_r;

// addr
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        araddr_m_inf_r <= 0;
    else begin
        case (n_state)
            s_AddrRead: begin
                araddr_m_inf_r <= (mode) ? {{3{4'b0}}, {4'b0011} , {6'b0} ,{se_no}, {4'b0}}:  // 0x0003_00[]0
                                           {{3{4'b0}}, {4'b0100} , {pic_no}, {3{4'b0}}};      // 0x0004_[]000
            end
            default:  araddr_m_inf_r <= 0;
        endcase
    end
end

// valid
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        arvalid_m_inf_r <= 0;
    else begin
        case (n_state)
            s_AddrRead: begin
                if(arready_m_inf==1)
                    arvalid_m_inf_r <= 0;
                else
                    arvalid_m_inf_r <= 1;
            end
            default:arvalid_m_inf_r <= 0;
        endcase
    end
end

//======================================
//        Read Data Chanel
//======================================
assign rready_m_inf = rready_m_inf_r;

// data
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rdata_m_inf_r <= 0;
    else begin
        case (n_state)
            s_DataRead: begin
                if(rvalid_m_inf==1)
                    rdata_m_inf_r <= rdata_m_inf;
                else
                    rdata_m_inf_r <= 0;
            end
            default: rdata_m_inf_r <= 0;
        endcase
    end
end

// ready
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rready_m_inf_r<= 0;
    else begin
        case (n_state)
            s_DataRead:  if(rlast_m_inf) rready_m_inf_r <= 0;
                         else rready_m_inf_r <= 1;
            default:     rready_m_inf_r <= 0;
        endcase
    end
end

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
    s_idle:     if(read)            n_state = s_AddrRead;
	            else    	        n_state = s_idle;
    s_AddrRead: if(read_addr_done)  n_state = s_DataRead;
                else                n_state = s_AddrRead;
    s_DataRead: if(rlast_m_inf)     n_state = s_idle;
                else                n_state = s_DataRead;
    default:    n_state = c_state;
    endcase
end

// read address done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_addr_done <= 0;
    else begin
        if(arvalid_m_inf==1 && arready_m_inf==1)
            read_addr_done <=1;
        else
            read_addr_done <= 0;
    end
end

/*
// read data done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_data_done <= 0;
    else begin
        if(rlast_m_inf)
            read_data_done <=1;
        else
            read_data_done <= 0;
    end
end

// read data counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_data_counter <= 0;
    else begin
        case(n_state)
        s_DataRead: begin
            if(rready_m_inf && rvalid_m_inf)
                read_data_counter <= read_data_counter + 1;
        end
        default: read_data_counter <= 0;
        endcase
    end
end*/

endmodule

//============================================================//
//                 SUBMODULE - DRAM WRITE                     //
//============================================================//
module DRAM_write(
    // global signal
    clk,
    rst_n,
    // Image Index
    pic_no,
    se_no,
    // State control
    write_se,
    write_pic,
    // axi write address channel
    awid_m_inf,
    awaddr_m_inf,
    awsize_m_inf,
    awburst_m_inf,
    awlen_m_inf,
    awvalid_m_inf,
    awready_m_inf,
    // axi write data channel
    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    wready_m_inf,
    // axi write response channel
    bid_m_inf,
    bresp_m_inf,
    bvalid_m_inf,
    bready_m_inf
);
//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter ID_WIDTH = 4;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 128;

//FSM
parameter s_idle = 2'd0;
parameter s_AddrWrite = 2'd1;
parameter s_DataWrite = 2'd2;
parameter s_Response = 2'd3;

//======================================
//        INPUT DECLARATION
//======================================
// global signal
input clk;
input rst_n;

// image index
input [3:0] pic_no;
input [5:0] se_no;

// state control
input write_se;
input write_pic;

// axi write addr channel
output [ID_WIDTH-1:0]    awid_m_inf;
output [ADDR_WIDTH-1:0]  awaddr_m_inf;
output [2:0]             awsize_m_inf;
output [1:0]             awburst_m_inf;
output [7:0]             awlen_m_inf;
output                   awvalid_m_inf;
input                    awready_m_inf;

// axi write data channel
output  [DATA_WIDTH-1:0]   wdata_m_inf;
output                     wlast_m_inf;
output                     wvalid_m_inf;
input                      wready_m_inf;

// axi write resp channel
input [ID_WIDTH-1:0]    bid_m_inf;
input [1:0]             bresp_m_inf;
input                   bvalid_m_inf;
output                  bready_m_inf;

//======================================
//        WIRE and REG
//======================================
reg [2:0] c_state,n_state;

// FSM
reg write_addr_done;
reg write_data_done;
reg response_done;

reg [7:0] write_data_counter;

// Write Address Chanel
reg [ADDR_WIDTH-1:0] awaddr_m_inf_r;
reg awvalid_m_inf_r;

// Write Data Channel
reg                     wlast_m_inf_r;
reg                     wvalid_m_inf_r;

// Response Channel
reg bready_m_inf_r;

//======================================
//        Write Address Chanel
//======================================
assign awaddr_m_inf = awaddr_m_inf_r;
assign awlen_m_inf = 8'd255;
assign awvalid_m_inf = awvalid_m_inf_r;

// addr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        awaddr_m_inf_r <= 0;
    else begin
        case(n_state)
        s_AddrWrite: awaddr_m_inf_r <= {{3{4'b0}}, {1{4'b100}} , {pic_no}, {3{4'b0}}}; // 0x0004_[]000
        default: awaddr_m_inf_r <= 0;
        endcase
    end
end

// valid
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        awvalid_m_inf_r <= 0;
    else begin
        case (n_state)
            s_AddrWrite: begin
                if(awready_m_inf==1 || write_addr_done)
                    awvalid_m_inf_r <= 0;
                else
                    awvalid_m_inf_r <= 1;
            end
            default:awvalid_m_inf_r <= 0;
        endcase
    end
end

//======================================
//        Write Data Chanel
//======================================
//assign wdata_m_inf = wdata_m_inf_r;
assign wlast_m_inf = wlast_m_inf_r;
assign wvalid_m_inf = wvalid_m_inf_r;

// last
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wlast_m_inf_r <= 0;
    else begin
        case (n_state)
            s_DataWrite: begin
                if(write_data_counter == awlen_m_inf-1)
                    wlast_m_inf_r <= 1;
                else
                    wlast_m_inf_r <= 0;
            end
            default: wlast_m_inf_r <= 0;
        endcase
    end
end

// vaild
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wvalid_m_inf_r <= 0;
    else begin
        case (n_state)
            s_DataWrite: wvalid_m_inf_r <= 1;
            default:     wvalid_m_inf_r <= 0;
        endcase
    end
end
//======================================
//        Response Chanel
//======================================
assign bready_m_inf = bready_m_inf_r;

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        bready_m_inf_r <= 0;
    else begin
        case(n_state)
        s_Response: bready_m_inf_r <= 1;
        default: bready_m_inf_r <= 0;
        endcase
    end
end

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
    s_idle:      if(write_se)        n_state = s_AddrWrite;
	             else    	         n_state = s_idle;
    s_AddrWrite: if(write_pic)       n_state = s_DataWrite;
                 else                n_state = s_AddrWrite;
    s_DataWrite: if(write_data_done) n_state = s_Response;
                 else                n_state = s_DataWrite;
    s_Response:  if(response_done)   n_state = s_idle;
                 else                n_state = s_Response;
    default:     n_state = c_state;
    endcase
end

// write address done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        write_addr_done <= 0;
    else begin
        case(n_state)
            s_idle:write_addr_done <= 0;
            s_AddrWrite:begin
                if(awvalid_m_inf==1 && awready_m_inf==1)
                    write_addr_done <= 1;
            end
        endcase
    end
end

// write data done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        write_data_done <= 0;
    else begin
        if(write_data_counter == awlen_m_inf-1)
            write_data_done <=1;
        else
            write_data_done <= 0;
    end
end

// write data counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        write_data_counter <= 0;
    else begin
        case(n_state)
        s_DataWrite: begin
            if(wvalid_m_inf==1 && wready_m_inf==1)
                write_data_counter <= write_data_counter + 1;
        end
        default: write_data_counter <= 0;
        endcase
    end
end

// response done
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        response_done <= 0;
    else begin
        if(bready_m_inf==1 && bvalid_m_inf==1 && bresp_m_inf==2'b00)
            response_done <=1;
        else
            response_done <= 0;
    end
end

endmodule