module ALU(data_operandA, data_operandB, ctrl_ALUopcode,
							ctrl_shiftamt, data_result, isNotEqual, isLessThan, overflow);
							
		input [31:0] data_operandA, data_operandB;
		input [4:0] ctrl_ALUopcode, ctrl_shiftamt;
		
		output [31:0] data_result;
		output isNotEqual, isLessThan, overflow;
		
		//Intermediate wires; B_Out = output of MUX for input B, shift_out = output of MUX for LS and RS outputs
		//and_or_out = output of MUX for and and or outputs, adder_final_out = and_or_out MUXed with adder sum
		wire[31:0] SLOut, SROut, Sum, OR, AND, B_Out, shift_out, and_or_out, everything_but_sum;
		wire subtract_ctrl;
		
		SL left_shifter(.data(data_operandA), .ctrl(ctrl_shiftamt), .out(SLOut)); 
		SRA right_shifter(.data(data_operandA), .ctrl(ctrl_shiftamt), .out(SROut));
	
		//subtract_ctrl is 1 iff the lower 2 bits of ctrl_ALUopcode are 01
		and and1(subtract_ctrl, ~ctrl_ALUopcode[1], ctrl_ALUopcode[0]);
		
		genvar i;
		generate
		//MUX will output ~B is ctrl bit is high
		for(i = 0; i < 32; i=i+1) begin: loop1
			mux_21 temp(.a(data_operandB[i]), .b(~data_operandB[i]), .ctrl(subtract_ctrl), .out(B_Out[i]));
		end
		
		endgenerate
		
		adder_32 adder(.A(data_operandA), .B(B_Out), .Cin(subtract_ctrl), .Props(OR), .Gens(AND), .Sums(Sum));
		
		//s is true if we're going to output sum as our final result
		wire sum_ctrl;
		and sum_ctrl_and(sum_ctrl, ~ctrl_ALUopcode[2], ~ctrl_ALUopcode[1]);
		
		generate
		for(i = 0; i < 32; i=i+1) begin: loop2
			mux_21 temp(.a(SLOut[i]), .b(SROut[i]), .ctrl(ctrl_ALUopcode[0]), .out(shift_out[i]));
			mux_21 temp2(.a(AND[i]), .b(OR[i]), .ctrl(ctrl_ALUopcode[0]), .out(and_or_out[i]));
			mux_21 temp3(.a(and_or_out[i]), .b(shift_out[i]), .ctrl(ctrl_ALUopcode[2]), .out(everything_but_sum[i]));
			mux_21 temp4(.a(everything_but_sum[i]), .b(Sum[i]), .ctrl(sum_ctrl), .out(data_result[i]));
			
			//mux_21 temp3(.a(Sum[i]), .b(and_or_out[i]), .ctrl(ctrl_ALUopcode[1]), .out(adder_final_out[i]));
			//mux_21 temp4(.a(adder_final_out[i]), .b(shift_out[i]), .ctrl(ctrl_ALUopcode[2]), .out(data_result[i]));
		end
		
		endgenerate
		
		//ISNOTEQUAL: true if ANY bit of Sum is 1
		wire w1, w2, w3, w4;
		or or1(w1, Sum[7:0]);
		or or2(w2, Sum[15:8]);
		or or3(w3, Sum[23:16]);
		or or4(w4, Sum[31:24]);
		or or5(isNotEqual, w1, w2, w4, w4);
		
		//isLessThan: True if adder result is negative (for subtraction)
		//If you have overflow, we negate the adder result
		mux_21 ltmux(.a(Sum[31]), .b(~Sum[31]), .ctrl(overflow), .out(isLessThan));
		
		//Overflow
		wire w5, w6, w7, w8, w9, w10;
		and and2(w5, ~data_operandA[31], ~data_operandB[31], Sum[31]);
		and and3(w6, data_operandA[31], data_operandB[31], ~Sum[31]);
		or or6(w7, w5, w6);
		
		and and4(w8, data_operandA[31], ~data_operandB[31], ~Sum[31]);
		and and5(w9, ~data_operandA[31], data_operandB[31], Sum[31]);
		or or7(w10, w8, w9);
		
		mux_21 overflowmux(.a(w7), .b(w10), .ctrl(subtract_ctrl), .out(overflow));
		
							
endmodule

module adder_32(A, B, Cin, Props, Gens, Sums);

	input [31:0] A, B;
	input Cin;
	output [31:0] Props, Gens, Sums;
	
	//block_carries[i] = carry IN to the ith 8-bit adder block
	//block_gens[i] = gen function for the ith block, same idea for block_props
	wire[3:0] block_carries, block_gens, block_props;
	
	assign block_carries[0] = Cin;
	
	genvar i;
	generate
	
	for(i = 0; i < 4; i=i+1) begin: loop1
		adder_block_8bit add_temp(.A(A[i*8+7:i*8]), .B(B[i*8+7:i*8]), .Cin(block_carries[i]), 
										.sums(Sums[i*8+7:i*8]), .PROP(block_props[i]), .GEN(block_gens[i]), 
										.prop(Props[i*8+7:i*8]), .gen(Gens[i*8+7:i*8]));
	end
	
	endgenerate
	
	//BLOCK CARRY 1
	wire w1;
	and and1(w1, block_props[0], block_carries[0]);
	or or1(block_carries[1], w1, block_gens[0]);
	
	//BLOCK CARRY 2
	wire w2, w3;
	and and2(w2, block_props[1], block_props[0], block_carries[0]);
	and and3(w3, block_props[1], block_gens[0]);
	or or2(block_carries[2], block_gens[1], w2, w3);
	
	//BLOCK CARRY 3
	wire w4, w5, w6;
	and and4(w4, block_props[2], block_props[1], block_props[0], block_carries[0]);
	and and5(w5, block_props[2], block_props[1], block_gens[0]);
	and and6(w6, block_props[2], block_gens[1]);
	or or3(block_carries[3], block_gens[2], w4, w5, w6); 

endmodule

module adder_block_8bit(A,B,Cin,sums, PROP, GEN, prop, gen);

	input [7:0] A, B;
	input Cin;
	output [7:0] sums, prop, gen;
	output PROP, GEN;
	
	//carries[i] = carry IN to ith block
	wire[7:0] carries;
	
	//Initialize C0 
	assign carries[0] = Cin;
	
	genvar i;
	generate
	
	for(i = 0; i < 8; i=i+1) begin: loop1
		full_adder add_temp(.a(A[i]), .b(B[i]), .cin(carries[i]), .p(prop[i]), .g(gen[i]), .sum(sums[i]));
	end
	
	endgenerate
	
	
	//CARRY 1
	wire w1;
	and and1(w1, prop[0], carries[0]);
	or or1(carries[1], w1, gen[0]);
	
	
	//CARRY 2
	wire w2, w3;
	and and2(w2, carries[0], prop[0], prop[1]);
	and and3(w3, prop[1], gen[0]);
	or or2(carries[2], gen[1], w2, w3); 
	
	//CARRY 3
	wire w4, w5, w6;
	and and4(w4, carries[0], prop[0], prop[1], prop[2]);
	and and5(w5, prop[2], prop[1], gen[0]);
	and and6(w6, prop[2], gen[1]);
	or or3(carries[3], w4, w5, w6, gen[2]);
	
	//CARRY 4
	wire w7, w8, w9, w10;
	and and7(w7, prop[3], prop[2], prop[1], prop[0], carries[0]);
	and and8(w8, prop[3], prop[2], prop[1], gen[0]);
	and and9(w9, prop[3], prop[2], gen[1]);
	and and10(w10, prop[3], gen[2]);
	or or4(carries[4], gen[3], w7, w8, w9, w10);
	
	//CARRY 5
	wire w11, w12, w13, w14, w15;
	and and11(w11, prop[4], prop[3], prop[2], prop[1], prop[0], carries[0]);
	and and12(w12, prop[4], prop[3], prop[2], prop[1], gen[0]);
	and and13(w13, prop[4], prop[3], prop[2], gen[1]);
	and and14(w14, prop[4], prop[3], gen[2]);
	and and15(w15, prop[4], gen[3]);
	or or5(carries[5], w11, w12, w13, w14, w15, gen[4]);
	
	//CARRY 6
	wire w16, w17, w18, w19, w20, w21;
	and and16(w16, prop[5], prop[4], prop[3], prop[2], prop[1], prop[0], carries[0]);
	and and17(w17, prop[5], prop[4], prop[3], prop[2], prop[1], gen[0]);
	and and18(w18, prop[5], prop[4], prop[3], prop[2], gen[1]);
	and and19(w19, prop[5], prop[4], prop[3], gen[2]);
	and and20(w20, prop[5], prop[4], gen[3]);
	and and21(w21, prop[5], gen[4]);
	or or6(carries[6], gen[5], w16, w17, w18, w19, w20, w21);
	
	//CARRY 7
	wire w22, w23, w24, w25, w26, w27, w28;
	and and22(w22, prop[6], prop[5], prop[4], prop[3], prop[2], prop[1], prop[0], carries[0]);
	and and23(w23, prop[6], prop[5], prop[4], prop[3], prop[2], prop[1], gen[0]);
	and and24(w24, prop[6], prop[5], prop[4], prop[3], prop[2], gen[1]);
	and and25(w25, prop[6], prop[5], prop[4], prop[3], gen[2]);
	and and26(w26, prop[6], prop[5], prop[4], gen[3]);
	and and27(w27, prop[6], prop[5], gen[4]);
	and and28(w28, prop[6], gen[5]);
	or or7(carries[7], w22, w23, w24, w25, w26, w27, w28, gen[6]);
	
	
	//BLOCK LEVEL PROP FUNCTION
	and and29(PROP, prop[0], prop[1], prop[2], prop[3], prop[4], prop[5], prop[6], prop[7]);
	
	//BLOCK LEVEL GEN FUNCTION
	wire w29, w30, w31, w32, w33, w34, w35;
	and and30(w29, prop[1], prop[2], prop[3], prop[4], prop[5], prop[6], prop[7], gen[0]);
	and and31(w30, prop[2], prop[3], prop[4], prop[5], prop[6], prop[7], gen[1]);
	and and32(w31, prop[3], prop[4], prop[5], prop[6], prop[7], gen[2]);
	and and33(w32, prop[4], prop[5], prop[6], prop[7], gen[3]);
	and and34(w33, prop[5], prop[6], prop[7], gen[4]);
	and and35(w34, prop[6], prop[7], gen[5]);
	and and36(w35, prop[7], gen[6]);
	or or8(GEN, gen[7], w29, w30, w31, w32, w33, w34, w35);
	

	
endmodule
	
	
module full_adder(a,b,cin,sum,p,g);

	input a, b, cin;
	output sum, p, g;
	
	//SUM
	xor sumgate(sum, a, b, cin);
	
	//G,P
	and and3(g, a, b);
	or or2(p, a, b);
	
endmodule


module SL(data, ctrl, out);

	input [31:0] data;
	input[4:0] ctrl;
	output [31:0] out;

	wire[31:0] SL16_out, SL8_out, SL4_out, SL2_out, SL1_out;
	wire[31:0] SL8_in, SL4_in, SL2_in, SL1_in;

	SLL_16 sl16(.data(data), .out(SL16_out));

	genvar i;
	generate
	for(i = 0; i < 32; i=i+1) begin: loop1
		mux_21 temp(.a(data[i]), .b(SL16_out[i]), .ctrl(ctrl[4]), .out(SL8_in[i]));
	end
	endgenerate
	
	SLL_8 sl8(.data(SL8_in), .out(SL8_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop2
		mux_21 temp(.a(SL8_in[i]), .b(SL8_out[i]), .ctrl(ctrl[3]), .out(SL4_in[i]));
	end
	endgenerate
	
	SLL_4 sl4(.data(SL4_in), .out(SL4_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop3
		mux_21 temp(.a(SL4_in[i]), .b(SL4_out[i]), .ctrl(ctrl[2]), .out(SL2_in[i]));
	end
	endgenerate
	
	SLL_2 sl2(.data(SL2_in), .out(SL2_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop4
		mux_21 temp(.a(SL2_in[i]), .b(SL2_out[i]), .ctrl(ctrl[1]), .out(SL1_in[i]));
	end
	endgenerate
	
	SLL_1 sl1(.data(SL1_in), .out(SL1_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop5
		mux_21 temp(.a(SL1_in[i]), .b(SL1_out[i]), .ctrl(ctrl[0]), .out(out[i]));
	end
	endgenerate
	

endmodule
















////////////////////////////
module SLL_16(data, out);

input [31:0] data;
output [31:0] out;

assign out[15:0] = 16'b0000000000000000;
assign out[31:16] = data[15:0];

endmodule

/////////////////////////
module SLL_8(data, out);

input [31:0] data;
output [31:0] out;

assign out[7:0] = 8'b00000000;
assign out[31:8] = data[23:0];

endmodule

///////////////////////////
module SLL_4(data, out);

input [31:0] data;
output [31:0] out;

assign out[3:0] = 4'b0000;
assign out[31:4] = data[27:0];

endmodule

/////////////////////////////
module SLL_2(data, out);

input [31:0] data;
output [31:0] out;

assign out[1:0] = 2'b00;
assign out[31:2] = data[29:0];

endmodule

///////////////////////////////
module SLL_1(data, out);

input [31:0] data;
output [31:0] out;

assign out[0] = 1'b0;
assign out[31:1] = data[30:0];

endmodule


module SRA(data, ctrl, out);

	input [31:0] data;
	input [4:0] ctrl;
	output [31:0] out;

	wire[31:0] SR16_out, SR8_out, SR4_out, SR2_out, SR1_out;
	wire[31:0] SR8_in, SR4_in, SR2_in, SR1_in;

	SRA_16 SR16(.data(data), .out(SR16_out));

	genvar i;
	generate
	for(i = 0; i < 32; i=i+1) begin: loop1
		mux_21 temp(.a(data[i]), .b(SR16_out[i]), .ctrl(ctrl[4]), .out(SR8_in[i]));
	end
	endgenerate
	
	SRA_8 SR8(.data(SR8_in), .out(SR8_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop2
		mux_21 temp(.a(SR8_in[i]), .b(SR8_out[i]), .ctrl(ctrl[3]), .out(SR4_in[i]));
	end
	endgenerate
	
	SRA_4 SR4(.data(SR4_in), .out(SR4_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop3
		mux_21 temp(.a(SR4_in[i]), .b(SR4_out[i]), .ctrl(ctrl[2]), .out(SR2_in[i]));
	end
	endgenerate
	
	SRA_2 SR2(.data(SR2_in), .out(SR2_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop4
		mux_21 temp(.a(SR2_in[i]), .b(SR2_out[i]), .ctrl(ctrl[1]), .out(SR1_in[i]));
	end
	endgenerate
	
	SRA_1 SR1(.data(SR1_in), .out(SR1_out));

	generate
	for(i = 0; i < 32; i=i+1) begin: loop5
		mux_21 temp(.a(SR1_in[i]), .b(SR1_out[i]), .ctrl(ctrl[0]), .out(out[i]));
	end
	endgenerate

endmodule










//////////////////////////////


module SRA_16(data, out);
	input [31:0] data;
	output [31:0] out;

	assign out[15:0] = data[31:16];

	genvar i;
	generate
	for(i=16; i<32; i=i+1) begin:loop1
		or or_temp(out[i], data[31], 1'b0);
	end
	endgenerate

endmodule


//////////////////////////////


module SRA_8(data, out);
	input [31:0] data;
	output [31:0] out;

	assign out[23:0] = data[31:8];

	genvar i;
	generate
	for(i=24; i<32; i=i+1) begin:loop1
		or or_temp(out[i], data[31], 1'b0);
	end
	endgenerate

endmodule

//////////////////////////////////

module SRA_4(data, out);
	input [31:0] data;
	output [31:0] out;

	assign out[27:0] = data[31:4];

	genvar i;
	generate
	for(i=28; i<32; i=i+1) begin:loop1
		or or_temp(out[i], data[31], 1'b0);
	end
	endgenerate

endmodule

//////////////////////////////////

module SRA_2(data, out);
	input [31:0] data;
	output [31:0] out;

	assign out[29:0] = data[31:2];

	genvar i;
	generate
	for(i=30; i<32; i=i+1) begin:loop1
		or or_temp(out[i], data[31], 1'b0);
	end
	endgenerate

endmodule

///////////////////////////////////

module SRA_1(data, out);
	input [31:0] data;
	output [31:0] out;

	assign out[30:0] = data[31:1];

	or or_temp(out[31], data[31], 1'b0);


endmodule

