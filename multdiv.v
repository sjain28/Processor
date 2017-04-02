module multdiv(data_operandA, data_operandB, ctrl_MULT, ctrl_DIV, clock, 
								 data_result, data_exception, data_resultRDY, reset);

input [31:0] data_operandA, data_operandB;
input ctrl_MULT, ctrl_DIV, clock, reset;

output [31:0] data_result;
output data_exception, data_resultRDY;

wire[31:0] mult_out, div_out;
wire mult_exception, div_exception, mult_ready, div_ready;

div divider(.dividend(data_operandA), .divisor(data_operandB), .div_ctrl(ctrl_DIV), .clock(clock), 
				.data_ready(div_ready), .div_exception(div_exception), .quotient(div_out), .reset(reset));
				
mult multiplier(.data_A(data_operandA), .data_B(data_operandB), .mult_ctrl(ctrl_MULT), .clock(clock), 
					 .data_ready(mult_ready), .overflow(mult_exception), .product(mult_out), .reset(reset));

wire control_asserted, control_select;
or o1(control_asserted, ctrl_MULT, ctrl_DIV);
 
//The output of this signals whether it's a multiplication
dffe op_control(.d(ctrl_MULT), .clk(clock), .clrn(1'b1), .prn(1'b1), .ena(control_asserted), .q(control_select));


genvar i; 
	generate
	for(i = 0; i < 32; i = i+1) begin: loop1
		mux_21 mux_temp(.ctrl(control_select), .b(mult_out[i]), .a(div_out[i]), .out(data_result[i]));
	end
endgenerate
	
mux_21 mux1(.ctrl(control_select), .b(mult_ready), .a(div_ready), .out(data_resultRDY));
mux_21 mux2(.ctrl(control_select), .b(mult_exception), .a(div_exception), .out(data_exception));


endmodule



module counter16 (clock, reset, out);

input clock, reset;
output [4:0] out;
reg [4:0] next;

dff dff0(.d(next[0]), .clk(clock), .q(out[0]), .clrn(~reset));
dff dff1(.d(next[1]), .clk(clock), .q(out[1]), .clrn(~reset));
dff dff2(.d(next[2]), .clk(clock), .q(out[2]), .clrn(~reset));
dff dff3(.d(next[3]), .clk(clock), .q(out[3]), .clrn(~reset));
dff dff4(.d(next[4]), .clk(clock), .q(out[4]), .clrn(~reset));


always@(*) begin

casex({reset, out})
6'b1xxxxx: next = 0;
6'd0: next = 1;
6'd1: next = 2;
6'd2: next = 3;
6'd3: next = 4;
6'd4: next = 5;
6'd5: next = 6;
6'd6: next = 7;
6'd7: next = 8;
6'd8: next = 9;
6'd9: next = 10;
6'd10: next = 11;
6'd11: next = 12;
6'd12: next = 13;
6'd13: next = 14;
6'd14: next = 15;
6'd15: next = 16;
6'd16: next = 16;

default: next = 0;

endcase
end
endmodule

module counter32 (clock, reset, out);

input clock, reset;
output [5:0] out;
reg [5:0] next;

dff dff0(.d(next[0]), .clk(clock), .q(out[0]), .clrn(~reset));
dff dff1(.d(next[1]), .clk(clock), .q(out[1]), .clrn(~reset));
dff dff2(.d(next[2]), .clk(clock), .q(out[2]), .clrn(~reset));
dff dff3(.d(next[3]), .clk(clock), .q(out[3]), .clrn(~reset));
dff dff4(.d(next[4]), .clk(clock), .q(out[4]), .clrn(~reset));
dff dff5(.d(next[5]), .clk(clock), .q(out[5]), .clrn(~reset));


always@(*) begin

casex({reset, out})
7'b1xxxxxx: next = 0;
7'd0: next = 1;
7'd1: next = 2;
7'd2: next = 3;
7'd3: next = 4;
7'd4: next = 5;
7'd5: next = 6;
7'd6: next = 7;
7'd7: next = 8;
7'd8: next = 9;
7'd9: next = 10;
7'd10: next = 11;
7'd11: next = 12;
7'd12: next = 13;
7'd13: next = 14;
7'd14: next = 15;
7'd15: next = 16;
7'd16: next = 17;
7'd17: next = 18;
7'd18: next = 19;
7'd19: next = 20;
7'd20: next = 21;
7'd21: next = 22;
7'd22: next = 23;
7'd23: next = 24;
7'd24: next = 25;
7'd25: next = 26;
7'd26: next = 27;
7'd27: next = 28;
7'd28: next = 29;
7'd29: next = 30;
7'd30: next = 31;
7'd31: next = 32;
7'd32: next = 32;

default: next = 0;

endcase
end
endmodule


module div(dividend, divisor, quotient, div_ctrl, div_exception, clock, data_ready, reset);
//A = dividend, B = divisor

input[31:0] dividend, divisor;
input div_ctrl, clock, reset;

output[31:0] quotient;
output div_exception, data_ready;
wire divisor_0;

assign divisor_0 = ~|divisor[31:0];

wire fsm_done;

wire Trigger; //Trigger is the wire that signals that divisor < = remainder, so we do stuff in this cycle

//Counter and shift amount
wire[5:0] counter_state;
counter32 counter(.clock(clock), .reset(div_ctrl || reset), .out(counter_state));

//fsm done: counter = 32
and fsm_and(fsm_done, counter_state[5], ~counter_state[4], ~counter_state[3], ~counter_state[2], ~counter_state[1], ~counter_state[0]);

and exception(div_exception, divisor_0, fsm_done);

wire[4:0] shift_amt;
assign shift_amt = ~counter_state[4:0];

wire done; 
assign done = counter_state[5];

//remainder block
wire[31:0] rem_block_in, rem_block_out;
wire rem_block_enable;
register remainder_reg(.clk(clock), .data_in(rem_block_in), .write_enable(rem_block_enable), .data_out(rem_block_out), .ctrl_reset(1'b0));

or or1(rem_block_enable, Trigger, div_ctrl); //Write to remainder at beginning or when Trigger occurs


//sign resolved divisor
//sign resolved dividend

wire[31:0] resolved_divisor, resolved_dividend;
wire [4:0] divisor_opcode, dividend_opcode;

assign divisor_opcode[4:1] = 4'b0000;
assign dividend_opcode[4:1] = 4'b0000;
assign divisor_opcode[0] = divisor[31];
assign dividend_opcode[0] = dividend[31];
wire[31:0] zeros = 32'h00000000;

ALU divisor_ALU(.data_operandA(zeros), .data_operandB(divisor), .ctrl_ALUopcode(divisor_opcode), .ctrl_shiftamt(5'b00000), 
					 .data_result(resolved_divisor));
					 
ALU dividend_ALU(.data_operandA(zeros), .data_operandB(dividend), .ctrl_ALUopcode(dividend_opcode), .ctrl_shiftamt(5'b00000), 
					 .data_result(resolved_dividend));
					 
//ALU1
wire[31:0] ALU1_remainder, ALU1_output;
wire ALU_LT, ALU_equal, isEqual;

assign isEqual = ~|ALU1_output[31:0];
ALU ALU1(.data_operandA(resolved_divisor), .data_operandB(ALU1_remainder), .ctrl_ALUopcode(5'b00001), .ctrl_shiftamt(5'b00000), 
			 .isNotEqual(ALU_equal), .isLessThan(ALU_LT), .data_result(ALU1_output));

or or2(Trigger, isEqual, ALU_LT); 

//Shifter for remainder
SRA remainder_shifter(.data(rem_block_out), .ctrl(shift_amt), .out(ALU1_remainder));


//ALU2
wire[31:0] shifted_divisor, subtracted_remainder;
ALU ALU2(.data_operandA(rem_block_out), .data_operandB(shifted_divisor), .ctrl_ALUopcode(5'b00001), .ctrl_shiftamt(5'b00000),
			.data_result(subtracted_remainder));
			
//Shifter for divisor
SL divisor_shifter(.data(resolved_divisor), .ctrl(shift_amt), .out(shifted_divisor));

//Inputs to remainder block
genvar i; 
generate
	for(i = 0; i < 32; i = i+1) begin: loop1
		mux_21 mux_temp(.ctrl(div_ctrl), .b(resolved_dividend[i]), .a(subtracted_remainder[i]), .out(rem_block_in[i]));
	end
endgenerate

wire[31:0] intermediate_quotient;

//module reg_32_writable(clk, data_in, write_enable, data_out, ctrl_reset, write_address);
reg_32_writable quotient_block(.clk(clock), .data_in(32'hFFFFFFFF), .write_enable(Trigger),
								 .ctrl_reset(div_ctrl), .write_address(shift_amt), .data_out(intermediate_quotient));

or or3(data_ready, div_exception, done);

//sign resolved quotient		 
wire[4:0] quotient_opcode;
assign quotient_opcode[4:1] = 4'b0000;
xor operand_signs(quotient_opcode[0], dividend[31], divisor[31]);

ALU quotient_ALU(.data_operandA(zeros), .data_operandB(intermediate_quotient), .ctrl_ALUopcode(quotient_opcode), 
					  .ctrl_shiftamt(5'b00000), .data_result(quotient));
								 
endmodule

module mult(data_A, data_B, product, mult_ctrl, clock, data_ready, overflow, sign_overflow, top_product, maxneg_overflow, reset);

input [31:0] data_A, data_B;
input mult_ctrl, clock, reset;

output [31:0] product;
output data_ready, overflow;

//Set up FSM
wire[4:0] FSM_STATE;
counter16 FSM(.clock(clock), .reset(mult_ctrl || reset), .out(FSM_STATE));

//Initialize ALUOPCODE
wire[4:0] ALU_opcode;
assign ALU_opcode[4:1] = 4'b0000;

//Create preslicer with data_B as input
wire[15:0] shifts, adds, subtracts;
preslicer slicer(.shifts(shifts), .adds(adds), .subtracts(subtracts), .data_in(data_B));

//initialize LSB of ALUOPCODE using subtract_bit
//initialize do_nothing signal using add and subtract bits
wire add_bit, subtract_bit, do_nothing;
reg_16 add_ctrl(.clk(clock), .data_in(adds), .write_enable(mult_ctrl), .data_out(add_bit), .ctrl_reset(1'b0), .read_address(FSM_STATE));
reg_16 subtract_ctrl(.clk(clock), .data_in(subtracts), .write_enable(mult_ctrl), .data_out(subtract_bit), .ctrl_reset(1'b0), .read_address(FSM_STATE));
assign ALU_opcode[0] = subtract_bit;
and and1(do_nothing, ~add_bit, ~subtract_bit);

//Setup shift_bit
wire shift_bit;
reg_16 shift_ctrl(.clk(clock), .data_in(shifts), .write_enable(mult_ctrl), .data_out(shift_bit), .ctrl_reset(1'b0), .read_address(FSM_STATE));


//Setup ALU and wires going in/out
wire[31:0] shifted_multiplicand;
wire[63:0] full_ALU_out, full_product, reg_in;

assign product[31:0] = full_product[31:0];
assign full_ALU_out[31:0] = full_product[31:0];

genvar i; 
generate
	for(i = 0; i < 64; i = i+1) begin: loop1
		mux_21 mux_temp(.ctrl(do_nothing), .b(full_product[i]), .a(full_ALU_out[i]), .out(reg_in[i]));
	end
endgenerate

ALU alu(.data_operandA(full_product[63:32]), .data_operandB(shifted_multiplicand), .ctrl_ALUopcode(ALU_opcode), .ctrl_shiftamt(5'b00000), 
							  .data_result(full_ALU_out[63:32]));

//Setup shifters for ALU inputs and outputs
SLL_1_ctrl multiplicand_shifter(.data(data_A), .ctrl(shift_bit), .out(shifted_multiplicand));							  

//initialize DONE wire: done is true when fsmstate = 16 = 10000
wire fsm_done;
and and2(fsm_done, FSM_STATE[4], ~FSM_STATE[3], ~FSM_STATE[3], ~FSM_STATE[1], ~FSM_STATE[0]);

//Setup product register
shiftregister product_register(.clk(clock), .data_in(reg_in), .data_out(full_product), .ctrl_reset(mult_ctrl), .write_enable(~fsm_done));

//Setup check to see if we have overflow by checking upper 32 bits of product register
wire product_upper_OR;
or p_or(product_upper_OR, full_product[63:32]);

or ready_or(data_ready, overflow, fsm_done);

output[31:0] top_product;
assign top_product = full_product[63:32];

wire A0, B0, either_op_0;
assign A0 = ~|data_A[31:0];
assign B0 = ~|data_B[31:0];
or op0(either_op_0, A0, B0);


//Case 1: top product is not all the same, or it's different from sign of actual product
wire top_prod_all_zeros = ~|top_product[31:0];
wire top_prod_all_ones = &top_product[31:0];

wire all_ones, all_zeros;
and andones(all_ones, top_prod_all_ones, product[31]);
and andzeros(all_zeros, top_prod_all_zeros, ~product[31]);
 
output sign_overflow;
nor s_o_nor(sign_overflow, all_ones, all_zeros);


//Case 2: multiplying maxneg by maxneg

wire amaxneg, bmaxneg;
assign amaxneg = data_A[31] & (~|data_A[30:0]);
assign bmaxneg = data_B[31] & (~|data_B[30:0]);

output maxneg_overflow;
and maxneg(maxneg_overflow, amaxneg, bmaxneg);

wire both_cases;
or both(both_cases, sign_overflow, maxneg_overflow);

and final(overflow, both_cases, ~either_op_0, fsm_done);


endmodule

module preslicer(data_in, shifts, adds, subtracts);

input [31:0] data_in;
output [15:0] shifts, adds, subtracts;

wire [32:0] all_inputs;
assign all_inputs[0] = 1'b0; //Adding implicit 0
assign all_inputs[32:1] = data_in[31:0];

genvar i;
generate

for (i = 0; i < 16; i = i+1) begin: loop1
	
	//SHIFTS
	wire w1, w2;
	and and1(w1, all_inputs[i*2+2], ~all_inputs[i*2+1], ~all_inputs[i*2]);
	and and2(w2, ~all_inputs[i*2+2], all_inputs[i*2+1], all_inputs[i*2]);
	or or1(shifts[i], w1, w2);
	
	//ADDS
	wire w3, w4, w5;
	and and3(w3, ~all_inputs[i*2+2], all_inputs[i*2+1], ~all_inputs[i*2]);
	and and4(w4, ~all_inputs[i*2+2], ~all_inputs[i*2+1], all_inputs[i*2]);
	and and5(w5, ~all_inputs[i*2+2], all_inputs[i*2+1], all_inputs[i*2]);
	or or2(adds[i], w3, w4, w5);
	
	//SUBTRACTS
	wire w6, w7, w8;
	and and6(w6, all_inputs[i*2+2], ~all_inputs[i*2+1], ~all_inputs[i*2]);
	and and7(w7, all_inputs[i*2+2], all_inputs[i*2+1], ~all_inputs[i*2]);
	and and8(w8, all_inputs[i*2+2], ~all_inputs[i*2+1], all_inputs[i*2]);
	or or3(subtracts[i], w6, w7, w8);

end
endgenerate



endmodule

module reg_16(clk, data_in, write_enable, data_out, ctrl_reset, read_address);
//This is a register where we can specify the address of the DFF being read

	input clk, write_enable, ctrl_reset;
	input [15:0] data_in;
	input [3:0] read_address;
	
	output data_out;
	
	wire [15:0] stored_values;
	wire [4:0] decoder_input;
	
	//Using a 5:32 decoder, we give it a 0 in the MSB
	assign decoder_input[4] = 1'b0;
	assign decoder_input[3:0] = read_address[3:0];
	
	assign async_ctrl = 1;
	
	genvar i; 
	generate
	for(i = 0; i < 16; i = i+1) begin: loop1
		dffe dffe_temp(.d(data_in[i]), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(write_enable), .q(stored_values[i]));
	end
	endgenerate
	
	wire[31:0] decoder_out;
	decoder decode(.in(decoder_input), .out(decoder_out));
	
	generate
	for(i = 0; i < 16; i = i + 1) begin: loop2
		tristate temp(.in(stored_values[i]), .oe(decoder_out[i]), .out(data_out));
	end
	endgenerate
	
	
endmodule



module reg_32_writable(clk, data_in, write_enable, data_out, ctrl_reset, write_address);
//This is a register where we can specify the address of the DFF being written

	input clk, write_enable, ctrl_reset;
	input [31:0] data_in;
	input [4:0] write_address;
	
	output[31:0] data_out;
	
	assign async_ctrl = 1;
	
	wire[31:0] decoder_out, enables;
	decoder decode(.in(write_address), .out(decoder_out));

	
	
	genvar i; 
	generate
	for(i = 0; i < 32; i = i+1) begin: loop1
	
		and and1(enables[i], write_enable, decoder_out[i]);
		
		dffe dffe_temp(.d(data_in[i]), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(enables[i]), .q(data_out[i]));
	end
	endgenerate
	
	
endmodule


module shiftregister(clk, data_in, write_enable, data_out, ctrl_reset);

	input clk, write_enable, ctrl_reset;
	input [63:0] data_in;
	output [63:0] data_out;
	
	assign async_ctrl = 1;
	
	genvar i; 
	generate
	for(i = 0; i < 62; i = i+1) begin: loop1
		dffe dffe_temp(.d(data_in[i+2]), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(write_enable), .q(data_out[i]));
	end
	endgenerate
	
	
	//2 bits of sign extension
	
	wire bit_62;
	wire bit_63;
	
	assign bit_62 = data_in[63] ? 1'b1 : 1'b0;
	assign bit_63 = data_in[63] ? 1'b1 : 1'b0;

	dffe dffe_1(.d(bit_62), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(write_enable), .q(data_out[62]));
		
	dffe dffe_2(.d(bit_63), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(write_enable), .q(data_out[63]));
	
endmodule



//This module: 
//Is like a register that holds 64 bits, except: 
//It'll right-shift any input by 2


module SLL_1_ctrl(data, out, ctrl, overflow);

input [31:0] data;
input ctrl;
output [31:0] out;
output overflow;

and and1(overflow, ctrl, data[31]);

assign out[0] = ctrl ? 1'b0 : data[0];
assign out[31:1] = ctrl? data[30:0] : data[31:1];

endmodule

module tristate(in, oe, out);
	input in, oe;
	output out;
	
	assign out = oe? in : 1'bz;
	
endmodule
