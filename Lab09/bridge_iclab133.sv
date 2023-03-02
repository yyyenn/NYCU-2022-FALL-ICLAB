module bridge(input clk, INF.bridge_inf inf);

/***********************************************************************************************/
/*     modport bridge_inf(                                                                     */
/*     	    input  rst_n,                                                                      */
/*     		       C_addr, C_data_w, C_in_valid, C_r_wb,                                       */
/*     			   AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP,      */
/*          output C_out_valid, C_data_r,                                                      */
/*     		       AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY     */
/*         );                                                                                  */
/***********************************************************************************************/

//================================================================
// logic
//================================================================
logic [2:0] c_state, n_state;
logic [7:0] addr; // 256 restaurant / 256 delivery
logic [63:0] data;
logic act_done;

//================================================================
// state
//================================================================
parameter s_idle        = 3'd0 ;
parameter s_read_addr   = 3'd1 ;
parameter s_read_data   = 3'd2 ;
parameter s_write_addr  = 3'd3 ;
parameter s_write_data  = 3'd4 ;
parameter s_output      = 3'd5 ;

//================================================================
//   READ
//================================================================
// inf.AR_VALID
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.AR_VALID <= 0;
    else if(n_state == s_read_addr)
        inf.AR_VALID <= 1;
    else
        inf.AR_VALID <= 0;
end
// inf.AR_ADDR
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.AR_ADDR <= 0;
    else
        inf.AR_ADDR <= {{1'b1}, {5'b0}, {addr}, {3'b0}};
end
// inf.R_READY
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.R_READY <= 0;
    else if(n_state == s_read_data)
        inf.R_READY <= 1;
    else
        inf.R_READY <= 0;
end

//================================================================
//   WRITE
//================================================================
// inf.AW_VALID
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.AW_VALID <= 0;
    else if(n_state == s_write_addr)
        inf.AW_VALID <= 1;
    else
        inf.AW_VALID <= 0;
end
// inf.AW_ADDR
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.AW_ADDR <= 0;
    else
        inf.AW_ADDR <= {{1'b1}, {5'b0}, {addr}, {3'b0}};
end
// inf.W_VALID
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.W_VALID <= 0;
    else if(n_state == s_write_data)
        inf.W_VALID <= 1;
    else
        inf.W_VALID <= 0;
end
// inf.W_DATA
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.W_DATA <= 0;
    else
        inf.W_DATA <= data;
end
// inf.B_READY
always_ff @(posedge clk or  negedge inf.rst_n) begin
    if (!inf.rst_n)
        inf.B_READY <= 0;
    else if(n_state == s_idle)
        inf.B_READY <= 1;
    else
        inf.B_READY <= 0;
end


//================================================================
//   INPUT / OUTPUT
//================================================================
// input: addr
always_ff @(posedge clk or  negedge inf.rst_n) begin
	if (!inf.rst_n)
            addr <= 0 ;
	else begin
	    if (inf.C_in_valid==1)
                addr <= inf.C_addr;
	end
end

// input: data
always_ff @(posedge clk or  negedge inf.rst_n) begin
	if (!inf.rst_n)
        data <= 0 ;
	else begin
            if(n_state == s_idle)
                data <= 'd0;
	    else if (inf.C_in_valid == 1)
                data <= inf.C_data_w ;
	end
end

// output: out_valid
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (!inf.rst_n)
        inf.C_out_valid <= 0 ;
	else
		inf.C_out_valid <= (n_state==s_output) ? 'b1:
                           'b0 ;
end

// output: out_data
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (!inf.rst_n)
        inf.C_data_r <= 0 ;
	else if(inf.R_VALID==1)
      	inf.C_data_r <= inf.R_DATA;
end

//================================================================
//   FSM
//================================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (!inf.rst_n)
        c_state <= s_idle ;
	else
        c_state <= n_state ;
end
always_comb begin
	case(c_state)
	s_idle: begin
		        if (inf.C_in_valid==1) begin
    	        		n_state = (inf.C_r_wb) ? s_read_addr :  // 1 : read
		        		                         s_write_addr;  // 0 : write
		        end
                else n_state = s_idle;
		    end
	s_read_addr:  if (act_done)  n_state = s_read_data ;
                  else            n_state = s_read_addr;
    s_read_data:  if (act_done)  n_state = s_output;
                  else            n_state = s_read_data;
    s_write_addr: if (act_done)  n_state = s_write_data ;
                  else            n_state = s_write_addr;
    s_write_data: if (inf.B_VALID==1) n_state = s_output ;
                  else                n_state = s_write_data;
    s_output:     n_state = s_idle;
    default:      n_state = c_state;
	endcase
end

// act_done
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (!inf.rst_n)
                act_done <= 0 ;
	else begin
        if(n_state == s_read_addr) begin
            if(inf.AR_READY == 1 && inf.AR_VALID == 1)
                act_done <= 1;
            else
               act_done <= 0;
        end
        else if(n_state == s_read_data) begin
            if(inf.R_READY == 1 && inf.R_VALID == 1)
                act_done <= 1;
            else
               act_done <= 0;
        end
        else if(n_state == s_write_addr) begin
            if(inf.AW_READY == 1 && inf.AW_VALID == 1)
                act_done <= 1;
            else
               act_done <= 0;
        end
        else act_done <= 0;
	end
end


endmodule
