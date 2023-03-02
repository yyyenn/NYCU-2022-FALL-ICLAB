`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
integer i,patnum;
integer gap, delay;
integer d_id_addr;
integer res_id_addr;
integer lat;


parameter SEED = 67 ;
parameter PATNUM = 400;
parameter base_addr = 65536;
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";

//================================================================
// wire & registers
//================================================================
logic [7:0] golden_DRAM[(base_addr+256*8)-1 :base_addr];
logic if_needed;
logic cancel_ctm_1;
logic [7:0] delivery_man_id;
Customer_status cus_status;
logic [7:0] res_id;
Food_id food_id;
logic [4:0] ser_food;

Action previous_action;
Action current_action;

logic [7:0] if_needed_d_man_id;
logic [7:0] if_needed_res_id;

Error_Msg golden_err_msg;
logic golden_complete;
logic [63:0] golden_out_info;
//================================================================
// class random
//================================================================
class random_action;
	randc Action action;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { action inside {Take, Deliver, Order, Cancel}; }
endclass

class random_d_man_id;
	randc int d_man_id;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { d_man_id inside {[0:254]}; }
endclass

class random_cus_status;
	randc Customer_status cus_status;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { cus_status inside {Normal, VIP}; }
endclass

class random_res_id;
	randc int res_id;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { res_id inside {[1:254]}; }
endclass

class random_food_id;
	randc Food_id food_id;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { food_id inside {FOOD1, FOOD2, FOOD3}; }
endclass

class random_ser_food;
	randc int ser_food;
	function new (int seed);
		this.srandom(seed);
	endfunction
	constraint limit { ser_food inside {[8:15]}; }
endclass

random_action     r_action     = new(SEED);
random_d_man_id   r_d_man_id   = new(SEED);
random_cus_status r_cus_status = new(SEED);
random_res_id     r_res_id     = new(SEED);
random_food_id    r_food_id    = new(SEED);
random_ser_food   r_ser_food   = new(SEED);

// DRAM info
D_man_Info delivery_man_info;
res_info restaurant_info;

//================================================================
// initial
//================================================================
initial begin
	// read in initial DRAM data
	$readmemh(DRAM_p_r, golden_DRAM);

    // reset
	reset_task;

    previous_action = No_action;
    if_needed = 0;
    delivery_man_id = 0;
    golden_complete = 0;

    @(negedge clk);

    //input
    for(i = 0 ; i < PATNUM ; i = i + 1) begin
        patnum = i;
        r_action.randomize();
        r_d_man_id.randomize();
        r_cus_status.randomize();
        r_res_id.randomize();
        r_food_id.randomize();
        r_ser_food.randomize();

        input_task;

        read_dram;

        calculate;

        wait_outvalid;

        if(golden_complete===1)
            write_dram;

        check_ans;

    end
end


//================================================================
// task
//================================================================

task reset_task ;
	inf.rst_n = 1'b1 ;
	inf.id_valid = 1'b0 ;
	inf.act_valid = 1'b0 ;
	inf.cus_valid = 1'b0 ;
	inf.res_valid = 1'b0 ;
    inf.food_valid = 1'b0 ;
	inf.D = 'bx;
	#(1.0);	inf.rst_n = 0 ;
	#(6.0); inf.rst_n = 1 ;
endtask

task action_choose; begin
    inf.act_valid = 1;
    // 0-19 Order -> Take
    if(patnum>=0 && patnum<20) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Order;
            current_action = Order;
        end
        else begin
            inf.D.d_act[0] = Take;
            current_action = Take;
        end
    end
    // 20-39 Order -> Cancel
    else if(patnum>=20 && patnum<40) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Order;
            current_action = Order;
        end
        else begin
            inf.D.d_act[0] = Cancel;
            current_action = Cancel;
        end
    end
    // 40-59 Order -> Deliver
    else if(patnum>=40 && patnum<60) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Order;
            current_action = Order;
        end
        else begin
            inf.D.d_act[0] = Deliver;
            current_action = Deliver;
        end
    end
    // 60-79 Take -> Deliver
    else if(patnum>=60 && patnum<80) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Take;
            current_action = Take;
        end
        else begin
            inf.D.d_act[0] = Deliver;
            current_action = Deliver;
        end
    end
    // 80-99 Cancel -> Deliver
    else if(patnum>=80 && patnum<100) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Cancel;
            current_action = Cancel;
        end
        else begin
            inf.D.d_act[0] = Deliver;
            current_action = Deliver;
        end
    end
    // 100- 109 Deliver
    else if(patnum>=100 && patnum<110) begin
        inf.D.d_act[0] = Deliver;
        current_action = Deliver;
    end
    // 110-139 Cancel
    else if(patnum>=110 && patnum<140) begin
        inf.D.d_act[0] = Cancel;
        current_action = Cancel;
    end
    // 140-159 Take -> Cancel
    else if(patnum>=140 && patnum<160) begin
        if(patnum%2==0) begin
            inf.D.d_act[0] = Take;
            current_action = Take;
        end
        else begin
            inf.D.d_act[0] = Cancel;
            current_action = Cancel;
        end
    end
    // 160-199 Take
    else if(patnum>=160 && patnum<200) begin
        inf.D.d_act[0] = Take;
        current_action = Take;
    end
    // 200-282 Deliver
    else if(patnum>=200 && patnum<283) begin
        inf.D.d_act[0] = Deliver;
        current_action = Deliver;
    end
    // 283 Order
    else if(patnum==283)begin
        inf.D.d_act[0] = Order;
        current_action = Order;
    end
    // 284-394 Order(if_needed)
    else if(patnum>=284 && patnum<395) begin
        if_needed = 1;
        inf.D.d_act[0] = Order;
        current_action = Order;
    end
    // 395 Cancel
    else if(patnum==395) begin
        inf.D.d_act[0] = Cancel;
        current_action = Cancel;
    end
    // 396 Take
    else if(patnum==396) begin
        if_needed = 0;
        inf.D.d_act[0] = Take;
        current_action = Take;
    end
    // 397 Take(if needed)
    else if(patnum==397) begin
        if_needed = 1;
        inf.D.d_act[0] = Take;
        current_action = Take;
    end
    // 398 Cancel
    else if(patnum>=398 && patnum<400) begin
        inf.D.d_act[0] = Cancel;
        current_action = Cancel;
    end
    // random
    else begin
        inf.D.d_act[0] = r_action.action;
        current_action = r_action.action;
    end
end endtask

task d_man_choose;begin
    if(patnum==0||patnum==1)
        delivery_man_id = 0;
    else if(patnum<284 && current_action != Order)
        delivery_man_id = delivery_man_id + 1;
     else if(patnum==395)
        delivery_man_id = 253;
    else if(patnum==396)
        delivery_man_id = 254;
    else if(patnum==398)
        delivery_man_id = 254;
    else if(patnum==399)
        delivery_man_id = 255;
    else if(patnum>=285 && patnum<396)
        delivery_man_id = r_d_man_id.d_man_id;
    else if(patnum>400)
        delivery_man_id = r_d_man_id.d_man_id;
end endtask

task res_choose; begin
    if(patnum>=0 && patnum<20) begin
         res_id = delivery_man_id; //0;
    end
    else if(patnum>=60 && patnum<80) begin
        res_id = 0;
    end
    else if(patnum>=20 && patnum<60) begin
        res_id = $urandom_range(20,29);
    end
    else if(patnum>=130 && patnum<140) begin
        res_id = 0;
    end
    else if(patnum>=140 && patnum<160) begin
        res_id = 255;
    end
    else if(patnum==283) begin
        res_id = 252;
    end
    else if(patnum==395) begin
        res_id = 218;
    end
    else if(patnum==396) begin
        res_id = 254;
    end
    else if(patnum==397) begin
        res_id = 255;
    end
    else if(patnum==398) begin
        res_id = 254;
    end
    else if(patnum==399) begin
        res_id = 69;
    end
    // random
    else begin
        res_id = r_res_id.res_id;
    end
end endtask

task cus_status_choose; begin
    if(patnum==396)
        cus_status = Normal;
    else if(patnum==397)
        cus_status = VIP;
    else
        cus_status = r_cus_status.cus_status;
end endtask

task food_choose; begin
    if(patnum>=130 && patnum<160) begin
        food_id = $urandom_range(1,2);
    end
    else if(patnum==395) begin
        food_id = 2;
    end
    else if(patnum>=396 && patnum<400) begin
        food_id = 3;
    end
    else begin
        food_id = r_food_id.food_id;
    end
end endtask

task ser_food_choose; begin
    // 284-395 Order
    if(patnum>=284 && patnum<396) begin
        ser_food = 1;
    end
    else begin
        ser_food = r_ser_food.ser_food;
    end
end endtask

task input_task ;

    action_choose;
    d_man_choose;
    res_choose;
    cus_status_choose ;
    food_choose;
    ser_food_choose;

    /*if(patnum>400) begin
        if(previous_action == current_action)
            if_needed = 1;
        else
            if_needed = 0;
    end*/

    random_gap_task;

    case(current_action)
        Take: begin
            if(if_needed) begin
                previous_action = Take;
                // customer info
                inf.cus_valid = 1;

                inf.D.d_ctm_info[0].ctm_status = cus_status;
                inf.D.d_ctm_info[0].res_ID     = res_id;
                inf.D.d_ctm_info[0].food_ID    = food_id;
                inf.D.d_ctm_info[0].ser_food   = ser_food;

                random_gap_task;
            end
            else begin
                previous_action = Take;

                // store if_needed
                if_needed_d_man_id = delivery_man_id;

                // delivery man id
                inf.id_valid = 1;
                inf.D.d_id[0] = delivery_man_id;

                random_gap_task;

                // customer info
                inf.cus_valid = 1;
                inf.D.d_ctm_info[0].ctm_status = cus_status;
                inf.D.d_ctm_info[0].res_ID     = res_id;
                inf.D.d_ctm_info[0].food_ID    = food_id;
                inf.D.d_ctm_info[0].ser_food   = ser_food;

                random_gap_task;
            end
        end
        Deliver: begin
            previous_action = Deliver;

            // delivery man id
            inf.id_valid = 1;
            inf.D.d_id[0] = delivery_man_id;

            random_gap_task;
        end
        Order: begin
            if(if_needed) begin
                previous_action = Order;
                // food id serving
                inf.food_valid = 1;
                inf.D.d_food_ID_ser[0].d_food_ID  = food_id;
                inf.D.d_food_ID_ser[0].d_ser_food = ser_food;

                random_gap_task;
            end
            else begin
                previous_action = Order;

                // store if_needed
                if_needed_res_id =  res_id;

                // restaurant id
                inf.res_valid = 1;
                inf.D.d_res_id[0] = res_id;

                random_gap_task;

                // food id serving
                inf.food_valid = 1;
                inf.D.d_food_ID_ser[0].d_food_ID  = food_id;
                inf.D.d_food_ID_ser[0].d_ser_food = ser_food;

                random_gap_task;
            end
        end
        Cancel: begin
            previous_action = Cancel;
            // restaurant id
            inf.res_valid = 1;
            inf.D.d_res_id[0] = res_id;

            random_gap_task;

            // food id serving
            inf.food_valid = 1;
            inf.D.d_food_ID_ser[0].d_food_ID  = food_id;
            inf.D.d_food_ID_ser[0].d_ser_food = ser_food;

            random_gap_task;

            // delivery man id
            inf.id_valid = 1;
            inf.D.d_id[0] = delivery_man_id;

            random_gap_task;

        end
    endcase
endtask

task calculate; begin
    case(current_action)
        Take: begin
            if(delivery_man_info.ctm_info2 != 0) begin
                golden_complete = 0;
                golden_err_msg =  D_man_busy;
                golden_out_info = 0;
            end
            else begin
                if(food_id == 1 && restaurant_info.ser_FOOD1 < ser_food) begin
                    golden_complete = 0;
                    golden_err_msg = No_Food;
                    golden_out_info = 0;
                end
                else if(food_id == 2 && restaurant_info.ser_FOOD2 < ser_food) begin
                    golden_complete = 0;
                    golden_err_msg = No_Food;
                    golden_out_info = 0;
                end
                else if(food_id == 3 && restaurant_info.ser_FOOD3 < ser_food) begin
                    golden_complete = 0;
                    golden_err_msg = No_Food;
                    golden_out_info = 0;
                end
                else  begin
                    case(food_id)
                        FOOD1: restaurant_info.ser_FOOD1 = restaurant_info.ser_FOOD1 - ser_food;
                        FOOD2: restaurant_info.ser_FOOD2 = restaurant_info.ser_FOOD2 - ser_food;
                        FOOD3: restaurant_info.ser_FOOD3 = restaurant_info.ser_FOOD3 - ser_food;
                    endcase
                    if(delivery_man_info.ctm_info1 == 0) begin
                        delivery_man_info.ctm_info1.ctm_status = cus_status;
                        delivery_man_info.ctm_info1.res_ID     = res_id;
                        delivery_man_info.ctm_info1.food_ID    = food_id;
                        delivery_man_info.ctm_info1.ser_food   = ser_food;
                    end
                    else if(cus_status == VIP && delivery_man_info.ctm_info1.ctm_status != VIP)begin
                        delivery_man_info.ctm_info1.ctm_status = cus_status;
                        delivery_man_info.ctm_info1.res_ID     = res_id;
                        delivery_man_info.ctm_info1.food_ID    = food_id;
                        delivery_man_info.ctm_info1.ser_food   = ser_food;
                        delivery_man_info.ctm_info2.ctm_status = golden_DRAM[d_id_addr][7:6];
                        delivery_man_info.ctm_info2.res_ID     = {golden_DRAM[d_id_addr][5:0],golden_DRAM[d_id_addr+1][7:6]};
                        delivery_man_info.ctm_info2.food_ID    = golden_DRAM[d_id_addr+1][5:4];
                        delivery_man_info.ctm_info2.ser_food   = golden_DRAM[d_id_addr+1][3:0];
                    end
                    else begin
                        delivery_man_info.ctm_info2.ctm_status = cus_status;
                        delivery_man_info.ctm_info2.res_ID     = res_id;
                        delivery_man_info.ctm_info2.food_ID    = food_id;
                        delivery_man_info.ctm_info2.ser_food   = ser_food;
                    end
                    golden_complete = 1;
                    golden_err_msg = No_Err;
                    golden_out_info = {delivery_man_info, restaurant_info};
                end
            end
        end
        Deliver: begin
            if( delivery_man_info.ctm_info1===0) begin
                golden_complete = 0;
                golden_err_msg = No_customers;
                golden_out_info = 0;
            end
            else begin
                delivery_man_info.ctm_info1 = delivery_man_info.ctm_info2;
                delivery_man_info.ctm_info2 = 0;

                golden_complete = 1;
                golden_err_msg = No_Err;
                golden_out_info = {delivery_man_info , 32'd0};
            end
        end
        Order: begin
            if(restaurant_info.limit_num_orders - restaurant_info.ser_FOOD1 - restaurant_info.ser_FOOD2 - restaurant_info.ser_FOOD3 < ser_food) begin
                golden_complete = 0;
                golden_err_msg = Res_busy;
                golden_out_info = 0;
            end
            else begin
                case(food_id)
                    FOOD1: restaurant_info.ser_FOOD1 = restaurant_info.ser_FOOD1 + ser_food;
                    FOOD2: restaurant_info.ser_FOOD2 = restaurant_info.ser_FOOD2 + ser_food;
                    FOOD3: restaurant_info.ser_FOOD3 = restaurant_info.ser_FOOD3 + ser_food;
                endcase
                golden_complete = 1;
                golden_err_msg = No_Err;
                golden_out_info = {32'd0, restaurant_info};
            end
        end
        Cancel: begin

            if(delivery_man_info == 0) begin
                golden_complete = 0;
                golden_err_msg = Wrong_cancel;
                golden_out_info = 0;
            end
            else begin
                if(delivery_man_info.ctm_info1.res_ID != res_id && delivery_man_info.ctm_info2.res_ID !=  res_id) begin
                    golden_complete = 0;
                    golden_err_msg = Wrong_res_ID;
                    golden_out_info = 0;
                end
                else if(delivery_man_info.ctm_info1.res_ID ==  res_id )begin
                    if(delivery_man_info.ctm_info1.food_ID == food_id) begin
                        delivery_man_info.ctm_info1.ctm_status = golden_DRAM[d_id_addr+2][7:6];
                        delivery_man_info.ctm_info1.res_ID     = {golden_DRAM[d_id_addr+2][5:0],golden_DRAM[d_id_addr+3][7:6]};
                        delivery_man_info.ctm_info1.food_ID    = golden_DRAM[d_id_addr+3][5:4];
                        delivery_man_info.ctm_info1.ser_food   = golden_DRAM[d_id_addr+3][3:0];
                        delivery_man_info.ctm_info2 = 0;

                        golden_complete = 1;
                        golden_err_msg = No_Err;
                        golden_out_info = {delivery_man_info , 32'd0};
                    end
                    else begin
                        golden_complete = 0;
                        golden_err_msg = Wrong_food_ID;
                        golden_out_info = 0;
                    end
                end
                // customer 2
                if(delivery_man_info.ctm_info1.res_ID == res_id)begin
                    if(delivery_man_info.ctm_info1.food_ID == food_id) begin
                        delivery_man_info.ctm_info1 = 0;
                        golden_complete = 1;
                        golden_err_msg = No_Err;
                        golden_out_info = {delivery_man_info , 32'd0};
                    end
                    else begin
                        golden_complete = 0;
                        golden_err_msg = Wrong_food_ID;
                        golden_out_info = 0;
                    end
                end
                if(delivery_man_info.ctm_info2.res_ID == res_id)begin
                    if(delivery_man_info.ctm_info2.food_ID == food_id) begin
                        delivery_man_info.ctm_info2 = 0;
                        golden_complete = 1;
                        golden_err_msg = No_Err;
                        golden_out_info = {delivery_man_info , 32'd0};
                    end
                    else begin
                        golden_complete = 0;
                        golden_err_msg = Wrong_food_ID;
                        golden_out_info = 0;
                    end
                end
            end
        end
    endcase
end endtask

task read_dram; begin
    d_id_addr = (current_action == Take && if_needed == 1) ? base_addr + (8 * if_needed_d_man_id)+4 : base_addr + (8 * delivery_man_id) + 4;

    res_id_addr = (current_action == Order && if_needed == 1) ? base_addr + (8 * if_needed_res_id) : base_addr + (8 * res_id);
    // delivery man info
    delivery_man_info.ctm_info1.ctm_status = golden_DRAM[d_id_addr][7:6];
    delivery_man_info.ctm_info1.res_ID     = {golden_DRAM[d_id_addr][5:0],golden_DRAM[d_id_addr+1][7:6]};
    delivery_man_info.ctm_info1.food_ID    = golden_DRAM[d_id_addr+1][5:4];
    delivery_man_info.ctm_info1.ser_food   = golden_DRAM[d_id_addr+1][3:0];

    delivery_man_info.ctm_info2.ctm_status = golden_DRAM[d_id_addr+2][7:6];
    delivery_man_info.ctm_info2.res_ID     = {golden_DRAM[d_id_addr+2][5:0],golden_DRAM[d_id_addr+3][7:6]};
    delivery_man_info.ctm_info2.food_ID    = golden_DRAM[d_id_addr+3][5:4];
    delivery_man_info.ctm_info2.ser_food   = golden_DRAM[d_id_addr+3][3:0];

    // restaurant info
    restaurant_info.limit_num_orders = golden_DRAM[res_id_addr] ;
    restaurant_info.ser_FOOD1        = golden_DRAM[res_id_addr+1];
    restaurant_info.ser_FOOD2        = golden_DRAM[res_id_addr+2];
    restaurant_info.ser_FOOD3        = golden_DRAM[res_id_addr+3];
end endtask

// if correct
task write_dram; begin
    // delivery man info
    golden_DRAM[d_id_addr]   = {delivery_man_info.ctm_info1.ctm_status , delivery_man_info.ctm_info1.res_ID[7:2]};
    golden_DRAM[d_id_addr+1] = {delivery_man_info.ctm_info1.res_ID[1:0], delivery_man_info.ctm_info1.food_ID, delivery_man_info.ctm_info1.ser_food};
    golden_DRAM[d_id_addr+2] = {delivery_man_info.ctm_info2.ctm_status , delivery_man_info.ctm_info2.res_ID[7:2]};
    golden_DRAM[d_id_addr+3] = {delivery_man_info.ctm_info2.res_ID[1:0], delivery_man_info.ctm_info2.food_ID, delivery_man_info.ctm_info2.ser_food};
    // restaurant info
    golden_DRAM[res_id_addr]   = restaurant_info.limit_num_orders;
    golden_DRAM[res_id_addr+1] = restaurant_info.ser_FOOD1;
    golden_DRAM[res_id_addr+2] = restaurant_info.ser_FOOD2;
    golden_DRAM[res_id_addr+3] = restaurant_info.ser_FOOD3;
end endtask

task wait_outvalid; begin
    lat = 1;
    while(inf.out_valid!==1) begin
        lat = lat + 1;
        @(negedge clk);
    end
end endtask

task check_ans; begin
    if(golden_complete !== inf.complete || golden_err_msg != inf.err_msg || golden_out_info != inf.out_info) begin
        $display("Wrong Answer");
        $finish;
    end
    else begin
        if(patnum==PATNUM-1) begin
            @(negedge clk);
            $finish;
        end
    end
    random_delay_task;
end endtask

//in_valid -> in_valid
task random_gap_task; begin
    gap = 1;
    @(negedge clk);
	inf.id_valid = 1'b0 ;
	inf.act_valid = 1'b0 ;
	inf.cus_valid = 1'b0 ;
	inf.res_valid = 1'b0 ;
    inf.food_valid = 1'b0 ;
	inf.D = 'bx;
    repeat(gap) @(negedge clk);
end endtask

//out_valid -> in_valid
task random_delay_task; begin
	delay = 2;
    repeat(delay) @(negedge clk);
	inf.id_valid = 1'b0 ;
	inf.act_valid = 1'b0 ;
	inf.cus_valid = 1'b0 ;
	inf.res_valid = 1'b0 ;
    inf.food_valid = 1'b0 ;
	inf.D = 'bx;
end endtask

endprogram