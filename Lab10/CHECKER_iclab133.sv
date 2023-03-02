module Checker(input clk, INF.CHECKER inf);
import usertype::*;

covergroup Spec1 @(posedge clk iff (inf.id_valid) );
	coverpoint inf.D.d_id[0] {
		option.at_least = 1;
        option.auto_bin_max = 256;
	}
endgroup : Spec1

covergroup Spec2 @(posedge clk iff (inf.act_valid) );
	coverpoint inf.D.d_act[0] {
		option.at_least = 10;
        bins    t[]    = (Take, Deliver, Order, Cancel => Take, Deliver, Order, Cancel);
	}
endgroup : Spec2

covergroup Spec3 @(negedge clk iff (inf.out_valid) );
	coverpoint inf.complete {
		option.at_least = 200;
        bins not_complete = {0};
        bins complete = {1};
	}
endgroup : Spec3

covergroup Spec4 @(negedge clk iff (inf.out_valid) );
	coverpoint inf.err_msg {
		option.at_least = 20;
        bins No_Food        =   {No_Food       } ;
        bins D_man_busy     =   {D_man_busy    } ;
        bins No_customers   =   {No_customers  } ;
        bins Res_busy	    =   {Res_busy	   } ;
        bins Wrong_cancel   =   {Wrong_cancel  } ;
        bins Wrong_res_ID   =   {Wrong_res_ID  } ;
        bins Wrong_food_ID  =   {Wrong_food_ID } ;
	}
endgroup : Spec4


Spec1 cov_1 = new();
Spec2 cov_2 = new();
Spec3 cov_3 = new();
Spec4 cov_4 = new();

//************************************ below assertion is to check your pattern *****************************************
//                                          Please finish and hand in it
// This is an example assertion given by TA, please write the required assertions below
//  assert_interval : assert property ( @(posedge clk)  inf.out_valid |=> inf.id_valid == 0 [*2])
//  else
//  begin
//  	$display("Assertion X is violated");
//  	$fatal;
//  end
wire #(0.5) rst_reg = inf.rst_n;

Action action ;
always_ff @(posedge clk or negedge inf.rst_n)  begin
	if (!inf.rst_n)
        action <= No_action ;
	else begin
		if (inf.act_valid==1)
            action <= inf.D.d_act[0] ;
	end
end
//write other assertions
//========================================================================================================================================================
// Assertion 1. All output signals (including FD.sv and bridge.sv) should be zero after reset.
//========================================================================================================================================================
assert_1 : assert property ( @(negedge rst_reg) (inf.out_valid===0) && (inf.err_msg===No_Err) && (inf.complete===0) && (inf.out_info===0) &&
                            (inf.C_addr===0) && (inf.C_data_w===0) && (inf.C_in_valid===0) && (inf.C_r_wb===0) &&
                            (inf.C_out_valid===0) && (inf.C_data_r===0) && (inf.AR_VALID===0) && (inf.AR_ADDR===0) &&
                            (inf.R_READY===0) && (inf.AW_VALID===0) && (inf.AW_ADDR===0) && (inf.W_VALID===0) && (inf.W_DATA===0) && (inf.B_READY===0))
	else begin
		$display("Assertion 1 is violated");
		$fatal;
	end

//========================================================================================================================================================
// Assertion 2. If action is completed, err_msg should be 4’b0.
//========================================================================================================================================================
assert_2 : assert property ( @(negedge clk) (inf.out_valid===1 && inf.complete===1) |-> inf.err_msg===No_Err )
    else begin
    	$display("Assertion 2 is violated");
    	$fatal;
    end
//========================================================================================================================================================
// Assertion 3. If action is not completed, out_info should be 64’b0.
//========================================================================================================================================================
assert_3 : assert property ( @(negedge clk) (inf.out_valid===1 && inf.complete===0) |-> inf.out_info===64'b0 )
    else begin
    	$display("Assertion 3 is violated");
        $fatal;
    end

//========================================================================================================================================================
// Assertion 4. The gap between each input valid is at least 1 cycle and at most 5 cycles.
//========================================================================================================================================================
assert_4_Take_1 : assert property ( @(negedge clk) (action===Take && inf.act_valid===1) |=> ##[1:5] (inf.id_valid===1 || inf.cus_valid===1) )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Take_2 : assert property ( @(negedge clk) (action===Take && inf.id_valid===1) |=> ##[1:5] inf.cus_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Deliver : assert property ( @(negedge clk) (action===Deliver && inf.act_valid===1) |=> ##[1:5] inf.id_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Order_1 : assert property ( @(negedge clk) (action===Order && inf.act_valid===1) |=> ##[1:5] (inf.res_valid===1 || inf.food_valid===1) )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Order_2 : assert property ( @(negedge clk) (action===Order && inf.res_valid===1) |=> ##[1:5] inf.food_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_1 : assert property ( @(negedge clk) (action===Cancel && inf.act_valid===1) |=> ##[1:5] inf.res_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_2 : assert property ( @(negedge clk) (action===Cancel && inf.res_valid===1) |=> ##[1:5] inf.food_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_3 : assert property ( @(negedge clk) (action===Cancel && inf.food_valid===1) |=> ##[1:5] inf.id_valid===1 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

//========================================================================================================================================================
// Assertion 4. The gap between each input valid is not 0
//========================================================================================================================================================
assert_4_Take_1_0 : assert property ( @(negedge clk) (action===Take && inf.act_valid===1) |=> (inf.id_valid===0 && inf.cus_valid===0) )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Take_2_0 : assert property ( @(negedge clk) (action===Take && inf.id_valid===1) |=>  inf.cus_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Deliver_0 : assert property ( @(negedge clk) (action===Deliver && inf.act_valid===1) |=>  inf.id_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Order_1_0 : assert property ( @(negedge clk) (action===Order && inf.act_valid===1) |=>  (inf.res_valid===0 && inf.food_valid===0) )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Order_2_0 : assert property ( @(negedge clk) (action===Order && inf.res_valid===1) |=> inf.food_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_1_0 : assert property ( @(negedge clk) (action===Cancel && inf.act_valid===1) |=> inf.res_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_2_0 : assert property ( @(negedge clk) (action===Cancel && inf.res_valid===1) |=> inf.food_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

assert_4_Cancel_3_0 : assert property ( @(negedge clk) (action===Cancel && inf.food_valid===1) |=> inf.id_valid===0 )
    else begin
    	$display("Assertion 4 is violated");
        $fatal;
    end

//========================================================================================================================================================
// Assertion 5. All input valid signals won’t overlap with each other.
//========================================================================================================================================================
assert_5_act : assert property ( @(posedge clk) (inf.act_valid===1) |-> ((inf.id_valid===0)&&(inf.cus_valid===0)&&(inf.res_valid===0)&&(inf.food_valid===0)))
    else begin
    	$display("Assertion 5 is violated");
        $fatal;
    end

assert_5_id : assert property ( @(posedge clk) (inf.id_valid===1) |-> ((inf.act_valid===0)&&(inf.cus_valid===0)&&(inf.res_valid===0)&&(inf.food_valid===0)))
    else begin
    	$display("Assertion 5 is violated");
        $fatal;
    end

assert_5_ctm : assert property ( @(posedge clk) (inf.cus_valid===1) |-> ((inf.id_valid===0)&&(inf.act_valid===0)&&(inf.res_valid===0)&&(inf.food_valid===0)))
    else begin
    	$display("Assertion 5 is violated");
        $fatal;
    end

assert_5_res : assert property ( @(posedge clk) (inf.res_valid===1) |-> ((inf.id_valid===0)&&(inf.cus_valid===0)&&(inf.act_valid===0)&&(inf.food_valid===0)))
    else begin
    	$display("Assertion 5 is violated");
        $fatal;
    end

assert_5_food : assert property ( @(posedge clk) (inf.food_valid===1) |-> ((inf.id_valid===0)&&(inf.cus_valid===0)&&(inf.res_valid===0)&&(inf.act_valid===0)))
    else begin
    	$display("Assertion 5 is violated");
        $fatal;
    end
//========================================================================================================================================================
// Assertion 6. Out_valid can only be high for exactly one cycle.
//========================================================================================================================================================
assert_6 : assert property ( @(negedge clk)  (inf.out_valid===1) |=> (inf.out_valid===0) )
    else begin
    	$display("Assertion 6 is violated");
        $fatal;
    end

//========================================================================================================================================================
// Assertion
//========================================================================================================================================================
// 7. Next operation will be valid 2-10 cycles after out_valid fall.
assert_7_1 :assert property ( @(posedge clk) (inf.out_valid===1) |=> (inf.act_valid===0) )
    else begin
     	$display("Assertion 7 is violated");
     	$fatal;
    end

assert_7_2 :assert property ( @(posedge clk) (inf.out_valid===1) |-> ##[2:10] (inf.act_valid===1) )
    else begin
     	$display("Assertion 7 is violated");
     	$fatal;
    end

//========================================================================================================================================================
// Assertion 8. Latency should be less than 1200 cycles for each operation
//========================================================================================================================================================
assert_8_Take : assert property ( @(posedge clk) (action===Take && inf.cus_valid===1) |-> (##[1:1200] inf.out_valid===1) )
    else begin
    	$display("Assertion 8 is violated");
        $fatal;
    end

assert_8_Deliver : assert property ( @(posedge clk) (action===Deliver && inf.id_valid===1) |-> (##[1:1200] inf.out_valid===1) )
    else begin
    	$display("Assertion 8 is violated");
        $fatal;
    end

assert_8_Order : assert property ( @(posedge clk) (action===Order && inf.food_valid===1) |-> (##[1:1200] inf.out_valid===1) )
    else begin
    	$display("Assertion 8 is violated");
        $fatal;
    end

assert_8_Cancel : assert property ( @(posedge clk) (action===Cancel && inf.id_valid===1) |-> (##[1:1200] inf.out_valid===1) )
    else begin
    	$display("Assertion 8 is violated");
        $fatal;
    end

endmodule