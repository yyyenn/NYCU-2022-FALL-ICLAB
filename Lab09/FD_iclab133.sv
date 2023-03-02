module FD(input clk, INF.FD_inf inf);
import usertype::*;

//===========================================================================
// logic
//===========================================================================
State c_state, n_state;
logic [1:0] cal_counter;
logic cal_done;
logic revise_state_delay; // revise id_valid delay
logic C_in_valid_flag;

// Take
logic get_customer;
logic take_second_write; // dram second write
logic force_jump;
D_man_Info delivery_man_info_reg;
res_info restaurant_info_reg;

// Cancel
logic cancel_ctm_1;
logic cancel_ctm_2;

// input
Action action;                     // act_valid
Delivery_man_id delivery_man_id;   // id_valid
Ctm_Info ctm_info;                 // cus_valid
Restaurant_id restaurant_id;       // res_valid
food_ID_servings food_id_servings; // food_valid

// DRAM info
D_man_Info delivery_man_info;
res_info restaurant_info;

//===========================================================================
// Input
//===========================================================================
// action (act_valid)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        action <= No_action;
    else if(inf.act_valid)
        action <= inf.D.d_act[0];
end

// delivery_man_id (id_valid)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        delivery_man_id <= 0;
    else if(inf.id_valid)
        delivery_man_id <= inf.D.d_id[0];
end

// ctm_info (cus_valid)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        ctm_info <= 0;
    else if(inf.cus_valid)
        ctm_info <= inf.D.d_ctm_info[0];
end

// restaurant_id (res_valid)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        restaurant_id <= 0;
    else if(inf.res_valid)
        restaurant_id <= inf.D.d_res_id[0];
end

// food_id_servings (food_valid)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        food_id_servings <= 0;
    else if(inf.food_valid)
        food_id_servings <= inf.D.d_food_ID_ser[0];
end

//===========================================================================
// read DRAM
//===========================================================================
// delivery_man_info.ctm_info1
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        delivery_man_info.ctm_info1 <= 0;
    else if(n_state == s_read_dram) begin
        // store Take/Deliver/Order/Cancel
        delivery_man_info.ctm_info1 <= {inf.C_data_r[39:38],{inf.C_data_r[37:32],inf.C_data_r[47:46]},inf.C_data_r[45:44],inf.C_data_r[43:40]};
    end
    else if(n_state == s_in_progress) begin
        if(action == Cancel && cal_counter == 2) begin
            if(cancel_ctm_1) begin
                if(cancel_ctm_2)
                    delivery_man_info.ctm_info1 <= 16'd0;
                else
                    delivery_man_info.ctm_info1 <= delivery_man_info.ctm_info2;
            end
        end
    end
    // Take renew
    else if(n_state == s_take_check && cal_counter == 1 && inf.err_msg == No_Err) begin
        // delivery man has one customer
        if(delivery_man_info.ctm_info1 != 0) begin
            // Take: VIP
            if(ctm_info.ctm_status == VIP && delivery_man_info.ctm_info1.ctm_status!=VIP)
                delivery_man_info.ctm_info1 <= ctm_info;
        end
        // delivery man has no customer
        else
            delivery_man_info.ctm_info1 <= ctm_info;
    end
end

// delivery_man_info.ctm_info2
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        delivery_man_info.ctm_info2 <= 0;
    else if(n_state == s_read_dram) begin
        // store Take/Deliver/Order/Cancel
        delivery_man_info.ctm_info2 <= {inf.C_data_r[55:54],{inf.C_data_r[53:48],inf.C_data_r[63:62]},inf.C_data_r[61:60],inf.C_data_r[59:56]};
    end
    else if(n_state == s_in_progress) begin
        if(action == Cancel && cal_counter == 2) begin
            if(cancel_ctm_1 || cancel_ctm_2) begin
                    delivery_man_info.ctm_info2 <= 16'd0;
            end
        end
    end
    // Take renew
    else if(n_state == s_take_check && cal_counter == 1  && inf.err_msg == No_Err) begin
        // delivery man has one customer
        if(delivery_man_info.ctm_info1 != 0) begin
            // Take: VIP
            if(ctm_info.ctm_status == VIP && delivery_man_info.ctm_info1.ctm_status!=VIP)
                delivery_man_info.ctm_info2 <= delivery_man_info.ctm_info1;
            else
                delivery_man_info.ctm_info2 <= ctm_info;
        end
    end
end

// restaurant_info
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        restaurant_info <= 0;
    else begin // Delivery & Cancel haven't renew
        if(n_state == s_read_dram) begin
            // store Deliver/Order/Cancel
            restaurant_info <= {inf.C_data_r[7:0], inf.C_data_r[15:8], inf.C_data_r[23:16], inf.C_data_r[31:24]};
        end
        else if(n_state == s_in_progress)begin
            // Order renew
            if(action == Order && cal_counter == 1) begin
                if(food_id_servings.d_food_ID == 1)
                    restaurant_info.ser_FOOD1 <= restaurant_info.ser_FOOD1 + food_id_servings.d_ser_food;
                else if(food_id_servings.d_food_ID == 2)
                    restaurant_info.ser_FOOD2 <= restaurant_info.ser_FOOD2 + food_id_servings.d_ser_food;
                else if(food_id_servings.d_food_ID == 3)
                    restaurant_info.ser_FOOD3 <= restaurant_info.ser_FOOD3 + food_id_servings.d_ser_food;
            end
            // store Take
            else if(action == Take)// && (ctm_info.res_ID != delivery_man_id))
                restaurant_info <= {inf.C_data_r[7:0], inf.C_data_r[15:8], inf.C_data_r[23:16], inf.C_data_r[31:24]};
        end
        else if(n_state == s_take_check && cal_counter == 1) begin
            // Take renew
            if(ctm_info.food_ID == 1)
                restaurant_info.ser_FOOD1 <= restaurant_info.ser_FOOD1 - ctm_info.ser_food;
            else if(ctm_info.food_ID == 2)
                restaurant_info.ser_FOOD2 <= restaurant_info.ser_FOOD2 - ctm_info.ser_food;
            else if(ctm_info.food_ID == 3)
                restaurant_info.ser_FOOD3 <= restaurant_info.ser_FOOD3 - ctm_info.ser_food;
        end
    end
end

//================= store Take no-use DRAM data =================/
// restaurant_info_reg
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        restaurant_info_reg <= 0;
    else if(n_state == s_read_dram)begin
        // store Take no-use delivery man
        restaurant_info_reg <= inf.C_data_r[31:0];
    end
    else if(n_state == s_output && (ctm_info.res_ID == delivery_man_id) && inf.err_msg == No_Err)
        restaurant_info_reg <= {restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
end

// delivery_man_info_reg
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        delivery_man_info_reg <= 0;
    else if(n_state == s_in_progress && action == Take) begin
        // store Take no-use restaurant
        delivery_man_info_reg <= inf.C_data_r[63:32];
    end
end

//===========================================================================
// in progress
//===========================================================================
// Take: get_customer
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        get_customer <= 0;
    else begin
        if(n_state == s_idle)
            get_customer <= 0;
        else if(inf.cus_valid == 1)
            get_customer <= 1;
    end
end

// Cancel: cancel_ctm_1;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        cancel_ctm_1 <= 0;
    else begin
        if(delivery_man_info.ctm_info1[13:6] == restaurant_id) begin
            if(delivery_man_info.ctm_info1[5:4] == food_id_servings.d_food_ID)
                cancel_ctm_1 <= 1;
            else
                cancel_ctm_1 <= 0;
        end
        else begin
            cancel_ctm_1 <= 0;
        end
    end
end

// Cancel: cancel_ctm_2;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        cancel_ctm_2 <= 0;
    else begin
        if(delivery_man_info.ctm_info2[13:6] == restaurant_id) begin
            if(delivery_man_info.ctm_info2[5:4] == food_id_servings.d_food_ID)
                cancel_ctm_2 <= 1;
            else
                cancel_ctm_2 <= 0;
        end
        else begin
            cancel_ctm_2 <= 0;
        end
    end
end


//===========================================================================
// Output
//===========================================================================
// C_addr
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.C_addr <= 0;
    else begin
        if(n_state == s_read_dram) begin
            case(action)
                Take:    inf.C_addr <= delivery_man_id;
                Deliver: inf.C_addr <= delivery_man_id;
                Order:   inf.C_addr <= restaurant_id;
                Cancel:  inf.C_addr <= delivery_man_id;
            endcase
        end
        else if(n_state == s_in_progress) begin // Take: read restaurant info
            inf.C_addr <= ctm_info.res_ID;
        end
        if(n_state == s_write_dram) begin
            case(action)
                Take:    inf.C_addr <= delivery_man_id;
                Deliver: inf.C_addr <= delivery_man_id;
                Order:   inf.C_addr <= restaurant_id;
                Cancel:  inf.C_addr <= delivery_man_id;
            endcase
        end
        else if(n_state == s_sec_write_dram)
            inf.C_addr <= ctm_info.res_ID;
    end
end

// C_data_w
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.C_data_w <= 0;
    else begin
        if(n_state == s_write_dram) begin
            case(action)
                Take: begin
                    if(ctm_info.res_ID != delivery_man_id)
                        inf.C_data_w <= {delivery_man_info.ctm_info2[7:0], delivery_man_info.ctm_info2[15:8], delivery_man_info.ctm_info1[7:0], delivery_man_info.ctm_info1[15:8],restaurant_info_reg};
                end
                Deliver: inf.C_data_w <= {{16'd0}, delivery_man_info.ctm_info2[7:0], delivery_man_info.ctm_info2[15:8], restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
                Order:   inf.C_data_w <= {delivery_man_info.ctm_info2[7:0], delivery_man_info.ctm_info2[15:8], delivery_man_info.ctm_info1[7:0], delivery_man_info.ctm_info1[15:8], restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
                Cancel:  inf.C_data_w <= {delivery_man_info.ctm_info2[7:0], delivery_man_info.ctm_info2[15:8], delivery_man_info.ctm_info1[7:0], delivery_man_info.ctm_info1[15:8], restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
            endcase
        end
        // Only Take
        else if(n_state == s_sec_write_dram) begin
            if(ctm_info.res_ID != delivery_man_id)
                inf.C_data_w <= {delivery_man_info_reg,  restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
            else
                inf.C_data_w <= {delivery_man_info.ctm_info2[7:0], delivery_man_info.ctm_info2[15:8], delivery_man_info.ctm_info1[7:0], delivery_man_info.ctm_info1[15:8], restaurant_info.ser_FOOD3, restaurant_info.ser_FOOD2,  restaurant_info.ser_FOOD1, restaurant_info.limit_num_orders};
        end
    end
end
// C_in_valid_flag
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        C_in_valid_flag <= 0;
    else if(inf.C_out_valid)
        C_in_valid_flag <= 0;
    else begin
        if(n_state == s_read_dram) begin
            if(action==Deliver || action==Cancel || action==Take) begin
                if(revise_state_delay)
                    C_in_valid_flag <= 1;
            end
            else C_in_valid_flag <= 1;
        end
        else if(n_state == s_in_progress) begin // Take: read restaurant info
            if(get_customer)
                C_in_valid_flag <= 1;
            else
                C_in_valid_flag <= 0;
        end
        else if(n_state == s_write_dram) begin
            if(action == Take) begin
                if(ctm_info.res_ID == delivery_man_id)
                    C_in_valid_flag <= 0;
                else
                    C_in_valid_flag <= 1;
            end
            else C_in_valid_flag <= 1;
        end
        else if(n_state == s_sec_write_dram) begin
            C_in_valid_flag <= 1;
        end
        else
            C_in_valid_flag <= 0;
    end
end

// C_in_valid
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.C_in_valid <= 0;
    else if(C_in_valid_flag == 1)
        inf.C_in_valid <= 0;
    else begin
        if(n_state == s_read_dram) begin
            if(action==Deliver || action==Cancel || action==Take) begin
                if(revise_state_delay)
                    inf.C_in_valid <= 1;
            end
            else inf.C_in_valid <= 1;
        end
        else if(n_state == s_in_progress) begin // Take: read restaurant info
            if(get_customer)
                inf.C_in_valid <= 1;
            else
                inf.C_in_valid <= 0;
        end
        else if(n_state == s_write_dram) begin
            if(action == Take) begin
                if(ctm_info.res_ID == delivery_man_id)
                    inf.C_in_valid <= 0;
                else
                    inf.C_in_valid <= 1;
            end
            else inf.C_in_valid <= 1;
        end
        else if(n_state == s_sec_write_dram) begin
            inf.C_in_valid <= 1;
        end
        else
            inf.C_in_valid <= 0;
    end
end

// C_r_wb (0 : write / 1 : read)
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.C_r_wb <= 0;
    else if(n_state == s_write_dram)
        inf.C_r_wb <= 0;
    else if(n_state == s_sec_write_dram)
        inf.C_r_wb <= 0;
    else
        inf.C_r_wb <= 1;
end

// out_valid
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.out_valid <= 0;
    else begin
        if(n_state == s_output) // c_state == s_output => give output
            inf.out_valid <= 1;
        else
            inf.out_valid <= 0;
    end
end

// err_msg
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.err_msg <= No_Err;
    else if(n_state == s_idle)
        inf.err_msg <= No_Err;
    else begin
        case(action)
        Take: begin // 1-level determine
            if(n_state == s_in_progress) begin
                if(delivery_man_info.ctm_info2 != 0)
                    inf.err_msg <= D_man_busy;
                else
                    inf.err_msg <= No_Err;
            end
            else if(n_state == s_take_check) begin
                if(delivery_man_info.ctm_info2 != 0)
                    inf.err_msg <= D_man_busy;
                else begin
                    if(ctm_info.food_ID == 1 && restaurant_info.ser_FOOD1 < ctm_info.ser_food)
                        inf.err_msg <= No_Food;
                    else if(ctm_info.food_ID == 2 && restaurant_info.ser_FOOD2 < ctm_info.ser_food)
                        inf.err_msg <= No_Food;
                    else if(ctm_info.food_ID == 3 && restaurant_info.ser_FOOD3 < ctm_info.ser_food)
                        inf.err_msg <= No_Food;
                    else
                        inf.err_msg <= No_Err;
                end
            end
        end
        Deliver: begin // 1-level determine
            if(n_state == s_in_progress) begin
                if(delivery_man_info == 0)
                    inf.err_msg <= No_customers;
                else
                    inf.err_msg <= No_Err;
            end
        end
        Order: begin // 1-level determine
            if(n_state == s_in_progress) begin
                if(restaurant_info.limit_num_orders - restaurant_info.ser_FOOD1 - restaurant_info.ser_FOOD2 - restaurant_info.ser_FOOD3 < food_id_servings.d_ser_food)
                    inf.err_msg <= Res_busy;
                else
                    inf.err_msg <= No_Err;
            end
        end
        Cancel: begin // 2-level determine
            if(n_state == s_in_progress) begin
                if(delivery_man_info == 0)
                    inf.err_msg <= Wrong_cancel;
                else begin
                    if(delivery_man_info.ctm_info2 == 0) begin
                        if(delivery_man_info.ctm_info1[13:6] != restaurant_id)
                            inf.err_msg <= Wrong_res_ID;
                        else begin
                            if(cancel_ctm_1)
                                inf.err_msg <= No_Err;
                            else
                                inf.err_msg <= Wrong_food_ID;

                        end
                    end
                    else if(delivery_man_info.ctm_info1[13:6] != restaurant_id && delivery_man_info.ctm_info2[13:6] != restaurant_id) begin
                        inf.err_msg <= Wrong_res_ID;
                    end
                    else begin
                        if(cancel_ctm_1 || cancel_ctm_2)
                            inf.err_msg <= No_Err;
                        else
                            inf.err_msg <= Wrong_food_ID;
                    end
                end
            end
        end
        endcase
    end
end

// complete
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.complete <= 0 ;
    else if(n_state == s_idle)
        inf.complete <= 0;
    else begin
        if(inf.err_msg == No_Err) inf.complete <= 1;
        else inf.complete <= 0;
    end
end

// out_info
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        inf.out_info <= 0;
    else if(n_state == s_output)begin
        if(inf.err_msg == No_Err) begin
            case(action)
                Take   : inf.out_info <= {delivery_man_info,restaurant_info};
                Deliver: inf.out_info <= {delivery_man_info.ctm_info2,48'd0};
                Order  : inf.out_info <= {32'd0, restaurant_info};
                Cancel : inf.out_info <= {delivery_man_info,32'd0};
            endcase
        end
        else
            inf.out_info <= 0;
    end
    else
        inf.out_info <= 0;
end

//===========================================================================
// FSM
//===========================================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (!inf.rst_n)
        c_state <= s_idle ;
	else
        c_state <= n_state ;
end

always_comb begin
	case(c_state)
		s_idle      : if (inf.act_valid) n_state = s_input_act;
                      else n_state = s_idle;

        s_input_act : n_state = s_input_other;

        s_input_other: begin
            case(action)
                Take:    if(inf.id_valid) n_state = s_read_dram;         // first take
                         else if(inf.cus_valid) n_state = s_in_progress; // if needed
                         else n_state = s_input_other;

                Deliver: if(inf.id_valid) n_state = s_read_dram;
                         else n_state = s_input_other;

                Order:   if(inf.food_valid) n_state = s_read_dram;
                         else n_state = s_input_other;

                Cancel:  if(inf.id_valid) n_state = s_read_dram;
                         else n_state = s_input_other;
                default: n_state = c_state;
            endcase
        end
        s_read_dram   : if (inf.C_out_valid) n_state = s_in_progress;
                        else n_state = s_read_dram;

        s_in_progress : if (cal_done) begin
                            if(inf.err_msg != No_Err) n_state = s_output;
                            else n_state = s_write_dram;
                        end
                        else if(action == Take && inf.C_out_valid) n_state = s_take_check;
                        else n_state = s_in_progress;

        s_write_dram :  if (inf.C_out_valid) begin
                            if(action == Take) n_state = s_sec_write_dram;
                            else n_state = s_output;
                        end
                        else if(force_jump) n_state = s_sec_write_dram;
                        else n_state = s_write_dram;

        s_output : n_state = s_idle ;

        //=========== extra for take ===========//
        s_take_check :  if (cal_done) begin
                            if(inf.err_msg != No_Err) n_state = s_output;
                            else n_state = s_write_dram;
                        end
                        else n_state = s_take_check;

        s_sec_write_dram:  if (inf.C_out_valid) n_state = s_output;
                           else n_state = s_sec_write_dram;
        default: n_state = c_state;
	endcase
end

// cal_counter
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        cal_counter <= 0;
    else begin
        if(action == Take)
            if(n_state == s_take_check)
                cal_counter <= cal_counter + 1;
            else
                cal_counter <= 0;
        else begin
            if(n_state == s_in_progress)
                cal_counter <= cal_counter + 1;
            else
                cal_counter <= 0;
        end

    end
end

// cal_done
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        cal_done <= 0;
    else begin
        if(action == Take)
            if(n_state == s_take_check) begin
                if(cal_counter==1) cal_done <= 1;
            end
            else cal_done <= 0;
        else begin
            if(n_state == s_in_progress) begin
                case(action)
                Deliver: if(cal_counter==1) cal_done <= 1;
                Order:   if(cal_counter==1) cal_done <= 1;
                Cancel:  if(cal_counter==2) cal_done <= 1;
                endcase
            end
            else cal_done <= 0;
        end
    end
end

// revise_state_delay
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n)
        revise_state_delay <= 0;
    else begin
        if(n_state == s_read_dram)
            revise_state_delay <= 1;
        else
            revise_state_delay <= 0;
    end
end

// force_jump
always_comb begin
    if(action == Take) begin
        if(ctm_info.res_ID == delivery_man_id)
            force_jump <= 1;
        else
            force_jump <= 0;
    end
    else
        force_jump <= 0;
end

endmodule