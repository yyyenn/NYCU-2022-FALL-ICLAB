module SP(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	in_data,
	in_mode,
	// Output signals
	out_valid,
	out_data
);

// INPUT AND OUTPUT DECLARATION
input		clk;
input		rst_n;
input		in_valid;
input		cg_en;
input [8:0] in_data;
input [2:0] in_mode;

output reg 		  out_valid;
output reg signed[9:0] out_data;

//-------------------------------//
//    PARAMETER                  //
//-------------------------------//
parameter s_idle     = 'd0;
parameter s_input    = 'd1;
//parameter s_graycode = 'd2;
parameter s_addsub   = 'd3;
parameter s_SMA      = 'd4;
parameter s_median   = 'd5;
parameter s_output   = 'd6;
genvar i,j;
//-------------------------------//
//    WIRE AND REG DECLARATION   //
//-------------------------------//
// FSM
reg [2:0] c_state, n_state;
reg [3:0] counter;
reg graycode_done;
reg addsub_done;
reg SMA_done;
reg median_done;
// input register
reg [2:0] mode;
reg signed [8:0] data [8:0];
// for graycode
wire signed[8:0] graycode_data_w ;
reg signed [8:0] graycode_data_r [8:0];
// for add_sub
reg signed [8:0] min,max;
wire signed [9:0] diff,mid;
reg signed [8:0] addsub_data_w [8:0];
reg signed [8:0] addsub_data_r [8:0];
// for SMA
wire signed [10:0] SMA_data_w1 [8:0];
wire signed [8:0] SMA_data_w2 [8:0];
reg signed [8:0] SMA_data_r [8:0];
// for median
reg [1:0] cal_counter;
reg signed [8:0] compare_out_r[8:0];
// for compare
wire signed [8:0] out_w[8:0];
wire signed [8:0] out_w1[8:0];
wire signed [8:0] min_w, mid_w, max_w;

//-------------------------------//
//    INPUT                      //
//-------------------------------//
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		mode <= 0;
	else begin
		if(n_state == s_input && counter == 0)
			mode <= in_mode;
	end
end

//-------------------------------//
//    Graycode                   //
//-------------------------------//
assign graycode_data_w[8] = in_data[8];
assign graycode_data_w[7] = in_data[7];
assign graycode_data_w[6] = graycode_data_w[7] ^ in_data[6];
assign graycode_data_w[5] = graycode_data_w[6] ^ in_data[5];
assign graycode_data_w[4] = graycode_data_w[5] ^ in_data[4];
assign graycode_data_w[3] = graycode_data_w[4] ^ in_data[3];
assign graycode_data_w[2] = graycode_data_w[3] ^ in_data[2];
assign graycode_data_w[1] = graycode_data_w[2] ^ in_data[1];
assign graycode_data_w[0] = graycode_data_w[1] ^ in_data[0];

// graycode_data_r
generate
for(i=0 ; i<8 ;i=i+1)begin
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n)
			graycode_data_r[i] <= 0;
		else begin
			if(n_state == s_input) begin
				graycode_data_r[i] <= graycode_data_r[i+1];
			end
		end
	end
end
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		graycode_data_r[8] <= 0;
	else begin
		if(n_state == s_input) begin
			if(counter==0) begin
				if(in_mode[0])
					graycode_data_r[8] <=  (graycode_data_w[8]==1) ? (~graycode_data_w[7:0]) + 'b1:
													               	 graycode_data_w;
				else
					 graycode_data_r[8] <= in_data;
			end
			else begin
				if(mode[0])
					graycode_data_r[8] <=  (graycode_data_w[8]==1) ? (~graycode_data_w[7:0]) + 'b1:
													               	 graycode_data_w;
				else
					 graycode_data_r[8] <= in_data;
			end
		end
	end
end

//-------------------------------//
//    add sub                    //
//-------------------------------//
// addsub_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		addsub_done <= 0;
	else begin
		if(n_state==s_idle) begin
			addsub_done <= 0;
		end
		else if(n_state==s_input && counter>1) begin
			if(mode[1]==0)
				addsub_done <= 1;
			else
				addsub_done <= 0;
		end
		else if(n_state == s_addsub && cal_counter==1)begin
			addsub_done <= 1;
		end
	end
end

// min &  max
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		min <= 255;
	else begin
		if(counter > 0 && counter <= 9)begin
			if(min > graycode_data_r[8])
				min <= graycode_data_r[8];
		end
		else
			min <= 255;
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		max <= -256;
	else begin
		if(counter > 0 && counter <= 9)begin
			if(max < graycode_data_r[8])
				max <= graycode_data_r[8];
		end
		else
			max <= -256;
	end
end

// diff & mid
assign diff = (max-min)/2;
assign mid = (max+min)/2;

// addsub_data_w
generate
for(i=0; i<9 ; i=i+1)begin
	always @(*) begin
	    addsub_data_w[i] = (graycode_data_r[i] < mid)? graycode_data_r[i] + diff:
						   (graycode_data_r[i] > mid)? graycode_data_r[i] - diff:
						    graycode_data_r[i];
	end
end
endgenerate

// addsub_data_r
generate
for(i=0; i<9 ; i=i+1)begin
	always @(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			addsub_data_r[i] <= 0;
		end
		else if(n_state == s_addsub)begin
			if(mode[1])
				addsub_data_r[i] <= addsub_data_w[i];
			else
				addsub_data_r[i] <= graycode_data_r[i];
		end
	end
end
endgenerate
//-------------------------------//
//    SMA                        //
//-------------------------------//
// SMA_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		SMA_done <= 0;
	else begin
		if(n_state==s_idle) begin
			SMA_done <= 0;
		end
		else if(n_state==s_input && counter>1) begin
			if(mode[2]==0)
				SMA_done <= 1;
			else
				SMA_done <= 0;
		end
		else if(n_state==s_SMA)begin
			SMA_done <= 1;
		end
	end
end

// SMA_data_w1
assign SMA_data_w1[0] = (addsub_data_r[8] + addsub_data_r[0] + addsub_data_r[1]);
assign SMA_data_w1[8] = (addsub_data_r[7] + addsub_data_r[8] + addsub_data_r[0]);

generate
for(i=1; i<8 ; i=i+1)begin
	assign SMA_data_w1[i] = (addsub_data_r[i-1] + addsub_data_r[i] + addsub_data_r[i+1]);
end
endgenerate

// SMA_data_w2
generate
for(i=0; i<9 ; i=i+1)begin
	assign SMA_data_w2[i] = (mode[2]) ? SMA_data_w1[i] / 3:
									    addsub_data_r[i];
end
endgenerate


// SMA_data_r
generate
for(i=0; i<9 ; i=i+1)begin
	always @(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			SMA_data_r[i] <= 0;
		end
		else if(n_state == s_SMA)begin
			SMA_data_r[i] <= SMA_data_w2[i];
		end
	end
end
endgenerate

//-------------------------------//
//    MEDIAN                     //
//-------------------------------//
// median_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		median_done <= 0;
	else begin
		if(n_state == s_idle)
			median_done <= 0;
		else if(n_state==s_median)
			median_done <= 1;
	end
end

compare cmp1(.a(SMA_data_r[0]),.b(SMA_data_r[1]),.c(SMA_data_r[2]),.min(out_w[0]),.mid(out_w[1]),.max(out_w[2]));
compare cmp2(.a(SMA_data_r[3]),.b(SMA_data_r[4]),.c(SMA_data_r[5]),.min(out_w[3]),.mid(out_w[4]),.max(out_w[5]));
compare cmp3(.a(SMA_data_r[6]),.b(SMA_data_r[7]),.c(SMA_data_r[8]),.min(out_w[6]),.mid(out_w[7]),.max(out_w[8]));

compare cmp4(.a(out_w[0]),.b(out_w[3]),.c(out_w[6]),.min(out_w1[0]),.mid(out_w1[1]),.max(out_w1[2]));
compare cmp5(.a(out_w[1]),.b(out_w[4]),.c(out_w[7]),.min(out_w1[3]),.mid(out_w1[4]),.max(out_w1[5]));
compare cmp6(.a(out_w[2]),.b(out_w[5]),.c(out_w[8]),.min(out_w1[6]),.mid(out_w1[7]),.max(out_w1[8]));

compare cmp7(.a(out_w1[2]),.b(out_w1[4]),.c(out_w1[6]),.min(min_w),.mid(mid_w),.max(max_w));

// cal counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_counter <= 0;
    else begin
		if(n_state == s_addsub || n_state == s_median ) begin
			cal_counter <= cal_counter + 1;
		end
		else
			cal_counter <= 0;
	end
end
//-------------------------------//
//    OUTPUT                     //
//-------------------------------//
//out_valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		out_valid <= 0;
	else begin
		if(n_state == s_median || ( n_state == s_output && counter < 2))
			out_valid <= 1;
		else
			out_valid <= 0;
	end
end
//out_data
always @(posedge clk or negedge rst_n)begin
	if(!rst_n)
		out_data <= 0;
	else begin
		if(n_state == s_idle)
			out_data <= 0;
		else if(n_state == s_median)
			out_data <= out_w1[8];
		else if( n_state == s_output && counter < 2)begin
			case(counter)
			0: out_data <= mid_w;
			1: out_data <= out_w1[0];
			endcase
		end
	end
end
//-------------------------------//
//    FSM                        //
//-------------------------------//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle:    if(in_valid) 	  n_state = s_input;
	      	   else    	   		  n_state = s_idle;
	s_input:   if(counter<9)  	  n_state = s_input;
			   else 			  n_state = s_addsub;
	s_addsub:  if(!addsub_done)   n_state = s_addsub;
			   else 			  n_state = s_SMA;
	s_SMA:     if(!SMA_done)  	  n_state = s_SMA;
               else               n_state = s_median;
	s_median:  if(!median_done)   n_state = s_median;
               else         	  n_state = s_output;
	s_output:  if(counter<2)	  n_state = s_output;
               else         	  n_state = s_idle;
    default: n_state = c_state;
    endcase
end

// counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        counter <= 0;
    else begin
		case(n_state)
			s_idle: counter <= 0;
			s_input: counter <= counter + 1;
			s_output: counter <= counter + 1;
			default: counter <= 0;
		endcase
	end
end

endmodule

module compare(a,b,c,min,mid,max);
input signed[8:0] a,b,c;
output reg signed [8:0] min,mid,max;

always @(*) begin
	if(a > b) begin
		if(a > c) begin
			if(b > c) begin //a > b > c
				min = c;
				mid = b;
				max = a;
			end
			else begin //a > c > b
				min = b;
				mid = c;
				max = a;
			end
		end
		else begin //c > a > b
			min = b;
			mid = a;
			max = c;
		end
	end
	else begin
		if(a > c) begin // b > a > c
			min = c;
			mid = a;
			max = b;
		end
		else begin
			if(b > c) begin  // b > c > a
				min = a;
				mid = c;
				max = b;
			end
			else begin // c > b > a
				min = a;
				mid = b;
				max = c;
			end
		end
	end
end

endmodule
/*
//-------------------------------//
//    PARAMETER                  //
//-------------------------------//
parameter s_idle     = 'd0;
parameter s_input    = 'd1;
//parameter s_graycode = 'd2;
parameter s_addsub   = 'd3;
parameter s_SMA      = 'd4;
parameter s_median   = 'd5;
parameter s_output   = 'd6;
genvar i,j;
//-------------------------------//
//    WIRE AND REG DECLARATION   //
//-------------------------------//
// FSM
reg [2:0] c_state, n_state;
reg [3:0] counter;
reg graycode_done;
reg addsub_done;
reg SMA_done;
reg median_done;
// input register
reg [2:0] mode;
reg signed [8:0] data [8:0];
// for graycode
wire signed[8:0] graycode_data_w ;
reg signed [8:0] graycode_data_r [8:0];
// for add_sub
reg signed [8:0] min,max;
wire signed [9:0] diff,mid;
reg signed [8:0] addsub_data_w [8:0];
reg signed [8:0] addsub_data_r [8:0];
// for SMA
wire signed [10:0] SMA_data_w1 [8:0];
wire signed [8:0] SMA_data_w2 [8:0];
reg signed [8:0] SMA_data_r [8:0];
// for median
reg [1:0] cal_counter;
reg signed [8:0] compare_out_r[8:0];
// for compare
wire signed [8:0] out_w[8:0];
wire signed [8:0] out_w1[8:0];
wire signed [8:0] min_w, mid_w, max_w;
// for Gate
//-------------------------------//
//    INPUT                      //
//-------------------------------//
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		mode <= 0;
	else begin
		if(n_state == s_input && counter == 0) begin
			mode <= in_mode;
		end
	end
end

//-------------------------------//
//    Graycode                   //
//-------------------------------//
// graycode_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		graycode_done <= 0;
	else begin
		if(n_state==s_idle) begin
			graycode_done <= 0;
		end
		else if(n_state==s_input && counter>1) begin
			if(mode[0]==0)
				graycode_done <= 1;
			else
				graycode_done <= 0;
		end
	end
end

assign graycode_data_w[8] = in_data[8];
assign graycode_data_w[7] = in_data[7];
assign graycode_data_w[6] = graycode_data_w[7] ^ in_data[6];
assign graycode_data_w[5] = graycode_data_w[6] ^ in_data[5];
assign graycode_data_w[4] = graycode_data_w[5] ^ in_data[4];
assign graycode_data_w[3] = graycode_data_w[4] ^ in_data[3];
assign graycode_data_w[2] = graycode_data_w[3] ^ in_data[2];
assign graycode_data_w[1] = graycode_data_w[2] ^ in_data[1];
assign graycode_data_w[0] = graycode_data_w[1] ^ in_data[0];

// graycode_data_r
generate
for(i=0 ; i<8 ;i=i+1)begin
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n)
			graycode_data_r[i] <= 0;
		else begin
			if(n_state == s_input) begin
				graycode_data_r[i] <= graycode_data_r[i+1];
			end
		end
	end
end
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		graycode_data_r[8] <= 0;
	else begin
		if(n_state == s_input) begin
			if(counter==0) begin
				if(in_mode[0])
					graycode_data_r[8] <=  (graycode_data_w[8]==1) ? (~graycode_data_w[7:0]) + 'b1:
													               	 graycode_data_w;
				else
					 graycode_data_r[8] <= in_data;
			end
			else begin
				if(mode[0])
					graycode_data_r[8] <=  (graycode_data_w[8]==1) ? (~graycode_data_w[7:0]) + 'b1:
													               	 graycode_data_w;
				else
					 graycode_data_r[8] <= in_data;
			end
		end
	end
end

//-------------------------------//
//    add sub                    //
//-------------------------------//
// addsub_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		addsub_done <= 0;
	else begin
		if(n_state==s_idle) begin
			addsub_done <= 0;
		end
		else if(n_state==s_input && counter>1) begin
			if(mode[1]==0)
				addsub_done <= 1;
			else
				addsub_done <= 0;
		end
		else if(n_state == s_addsub && cal_counter==1)begin
			addsub_done <= 1;
		end
	end
end

// min &  max
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		min <= 255;
	else begin
		if(n_state == s_idle)
			min <= 255;
		else if(counter > 0)begin
			if(min > graycode_data_r[8])
				min <= graycode_data_r[8];
		end
		else if(n_state == s_addsub)begin
			if(min > graycode_data_r[8])
				min <= graycode_data_r[8];
		end
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		max <= -256;
	else begin
		if(n_state==s_idle)
			max <= -256;
		else if(counter > 0)begin
			if(max < graycode_data_r[8])
				max <= graycode_data_r[8];
		end
		else if(n_state == s_addsub)begin
			if(max < graycode_data_r[8])
				max <= graycode_data_r[8];
		end
	end
end

// diff & mid
assign diff = (max-min)/2;
assign mid = (max+min)/2;

// addsub_data_w
generate
for(i=0; i<9 ; i=i+1)begin
	always @(*) begin
	    addsub_data_w[i] = (graycode_data_r[i] < mid)? graycode_data_r[i] + diff:
						   (graycode_data_r[i] > mid)? graycode_data_r[i] - diff:
						    graycode_data_r[i];
	end
end
endgenerate

// addsub_data_r
generate
for(i=0; i<9 ; i=i+1)begin
	always @(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			addsub_data_r[i] <= 0;
		end
		else if(n_state == s_addsub)begin
			if(mode[1])
				addsub_data_r[i] <= addsub_data_w[i];
			else
				addsub_data_r[i] <= graycode_data_r[i];
		end
	end
end
endgenerate
//-------------------------------//
//    SMA                        //
//-------------------------------//
// SMA_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		SMA_done <= 0;
	else begin
		if(n_state==s_idle) begin
			SMA_done <= 0;
		end
		else if(n_state==s_input && counter>1) begin
			if(mode[2]==0)
				SMA_done <= 1;
			else
				SMA_done <= 0;
		end
		else if(n_state==s_SMA)begin
			SMA_done <= 1;
		end
	end
end

// SMA_data_w1
assign SMA_data_w1[0] = (addsub_data_r[8] + addsub_data_r[0] + addsub_data_r[1]);
assign SMA_data_w1[8] = (addsub_data_r[7] + addsub_data_r[8] + addsub_data_r[0]);

generate
for(i=1; i<8 ; i=i+1)begin
	assign SMA_data_w1[i] = (addsub_data_r[i-1] + addsub_data_r[i] + addsub_data_r[i+1]);
end
endgenerate

// SMA_data_w2
generate
for(i=0; i<9 ; i=i+1)begin
	assign SMA_data_w2[i] = (mode[2]) ? SMA_data_w1[i] / 3:
									    addsub_data_r[i];
end
endgenerate

// SMA_data_r
generate
for(i=0; i<9 ; i=i+1)begin
	always @(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			SMA_data_r[i] <= 0;
		end
		else if(n_state == s_SMA)begin
			SMA_data_r[i] <= SMA_data_w2[i];
		end
	end
end
endgenerate

//-------------------------------//
//    MEDIAN                     //
//-------------------------------//
// median_done
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		median_done <= 0;
	else begin
		if(n_state == s_idle)
			median_done <= 0;
		else if(n_state==s_median)
			median_done <= 1;
	end
end

compare cmp1(.a(SMA_data_r[0]),.b(SMA_data_r[1]),.c(SMA_data_r[2]),.min(out_w[0]),.mid(out_w[1]),.max(out_w[2]));
compare cmp2(.a(SMA_data_r[3]),.b(SMA_data_r[4]),.c(SMA_data_r[5]),.min(out_w[3]),.mid(out_w[4]),.max(out_w[5]));
compare cmp3(.a(SMA_data_r[6]),.b(SMA_data_r[7]),.c(SMA_data_r[8]),.min(out_w[6]),.mid(out_w[7]),.max(out_w[8]));

compare cmp4(.a(out_w[0]),.b(out_w[3]),.c(out_w[6]),.min(out_w1[0]),.mid(out_w1[1]),.max(out_w1[2]));
compare cmp5(.a(out_w[1]),.b(out_w[4]),.c(out_w[7]),.min(out_w1[3]),.mid(out_w1[4]),.max(out_w1[5]));
compare cmp6(.a(out_w[2]),.b(out_w[5]),.c(out_w[8]),.min(out_w1[6]),.mid(out_w1[7]),.max(out_w1[8]));

compare cmp7(.a(out_w1[2]),.b(out_w1[4]),.c(out_w1[6]),.min(min_w),.mid(mid_w),.max(max_w));

// cal counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cal_counter <= 0;
    else begin
		if(n_state == s_addsub || n_state == s_median ) begin
			cal_counter <= cal_counter + 1;
		end
		else
			cal_counter <= 0;
	end
end
//-------------------------------//
//    OUTPUT                     //
//-------------------------------//
//out_valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		out_valid <= 0;
	else begin
		if(n_state == s_median || ( n_state == s_output && counter < 2))
			out_valid <= 1;
		else
			out_valid <= 0;
	end
end
//out_data
always @(posedge clk or negedge rst_n)begin
	if(!rst_n)
		out_data <= 0;
	else begin
		if(n_state == s_idle)
			out_data <= 0;
		else if(n_state == s_median)
			out_data <= out_w1[8];
		else if( n_state == s_output && counter < 2)begin
			case(counter)
			0: out_data <= mid_w;
			1: out_data <= out_w1[0];
			endcase
		end
	end
end
//-------------------------------//
//    FSM                        //
//-------------------------------//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        c_state <= s_idle;
    else
        c_state <= n_state;
end

always@(*) begin
    case(c_state)
    s_idle:    if(in_valid) 	  n_state = s_input;
	      	   else    	   		  n_state = s_idle;
	s_input:   if(counter<9) 	  n_state = s_input;
			   else 			  n_state = s_addsub;
	s_addsub:  if(!addsub_done)   n_state = s_addsub;
			   else 			  n_state = s_SMA;
	s_SMA:     if(!SMA_done)  	  n_state = s_SMA;
               else               n_state = s_median;
	s_median:  if(!median_done)   n_state = s_median;
               else         	  n_state = s_output;
	s_output:  if(counter<2)	  n_state = s_output;
               else         	  n_state = s_idle;
    default: n_state = c_state;
    endcase
end

// counter
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        counter <= 0;
    else begin
		case(n_state)
			s_idle: counter <= 0;
			s_input: counter <= counter + 1;
			s_output: counter <= counter + 1;
			default: counter <= 0;
		endcase
	end
end

endmodule

module compare(a,b,c,min,mid,max);
input signed[8:0] a,b,c;
output reg signed [8:0] min,mid,max;

always @(*) begin
	if(a > b) begin
		if(a > c) begin
			if(b > c) begin //a > b > c
				min = c;
				mid = b;
				max = a;
			end
			else begin //a > c > b
				min = b;
				mid = c;
				max = a;
			end
		end
		else begin //c > a > b
			min = b;
			mid = a;
			max = c;
		end
	end
	else begin
		if(a > c) begin // b > a > c
			min = c;
			mid = a;
			max = b;
		end
		else begin
			if(b > c) begin  // b > c > a
				min = a;
				mid = c;
				max = b;
			end
			else begin // c > b > a
				min = a;
				mid = b;
				max = c;
			end
		end
	end
end

endmodule*/