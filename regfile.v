module regfile(
	clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, 
	ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA,
	data_readRegB
	);
	
	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input[31:0] data_writeReg;
	
	output[31:0] data_readRegA, data_readRegB;
	
	wire [31:0] write_select_bits; //Input to the AND gates for write enable
	decoder write_decoder(ctrl_writeReg, write_select_bits);
	
	wire[31:0] read_select_bitsA; //RS1 address
	decoder read_decoderA(ctrl_readRegA, read_select_bitsA);
	
	wire[31:0] read_select_bitsB; //RS2 address
	decoder read_decoderB(ctrl_readRegB, read_select_bitsB);
	
	wire[31:0] register_write_enable_bits; //The actual bit that gets sent to the register
	
	wire[1023:0] Reg_data; //Output from the registers
	
	
	genvar i; 
	generate
	for(i = 0; i < 32; i = i+1) begin: loop1
		and and_temp(register_write_enable_bits[i], ctrl_writeEnable, write_select_bits[i]);
	end
	endgenerate
	
	generate
	for(i = 0; i < 32; i = i+1) begin: loop2
		register reg_temp(clock, data_writeReg, register_write_enable_bits[i], Reg_data[32*i+31:32*i], ctrl_reset);
		end
	endgenerate
	
	generate
	for(i = 0; i < 1024; i = i+1) begin: loop3
		tristate tri_temp(Reg_data[i], read_select_bitsA[i/32], data_readRegA[i%32]);
		end
	endgenerate
	
	generate
	for(i = 0; i < 1024; i = i+1) begin: loop4
		tristate tri_temp(Reg_data[i], read_select_bitsB[i/32], data_readRegB[i%32]);
		end
	endgenerate
	
	endmodule
	
module decoder(in, out);

	input [4:0] in;
	output [31:0] out; 

//32 and gates
//Complemented first
//input 0 alternates
//input 1 in groups of 2
//input 2 in groups of 4
//input 3 in groups of 8
//input 4 in groups of 16

	and and1(out[0], ~in[0], ~in[1], ~in[2], ~in[3], ~in[4]);
	and and2(out[1], in[0], ~in[1], ~in[2], ~in[3], ~in[4]);
	and and3(out[2], ~in[0], in[1], ~in[2], ~in[3], ~in[4]);
	and and4(out[3], in[0], in[1], ~in[2], ~in[3], ~in[4]);
	
	and and5(out[4], ~in[0], ~in[1], in[2], ~in[3], ~in[4]);
	and and6(out[5], in[0], ~in[1], in[2], ~in[3], ~in[4]);
	and and7(out[6], ~in[0], in[1], in[2], ~in[3], ~in[4]);
	and and8(out[7], in[0], in[1], in[2], ~in[3], ~in[4]);
	
	and and9(out[8], ~in[0], ~in[1], ~in[2], in[3], ~in[4]);
	and and10(out[9], in[0], ~in[1], ~in[2], in[3], ~in[4]);
	and and11(out[10], ~in[0], in[1], ~in[2], in[3], ~in[4]);
	and and12(out[11], in[0], in[1], ~in[2], in[3], ~in[4]);
	
	and and13(out[12], ~in[0], ~in[1], in[2], in[3], ~in[4]);
	and and14(out[13], in[0], ~in[1], in[2], in[3], ~in[4]);
	and and15(out[14], ~in[0], in[1], in[2], in[3], ~in[4]);
	and and16(out[15], in[0], in[1], in[2], in[3], ~in[4]);
	
	and and17(out[16], ~in[0], ~in[1], ~in[2], ~in[3], in[4]);
	and and18(out[17], in[0], ~in[1], ~in[2], ~in[3], in[4]);
	and and19(out[18], ~in[0], in[1], ~in[2], ~in[3], in[4]);
	and and20(out[19], in[0], in[1], ~in[2], ~in[3], in[4]);
	
	and and21(out[20], ~in[0], ~in[1], in[2], ~in[3], in[4]);
	and and22(out[21], in[0], ~in[1], in[2], ~in[3], in[4]);
	and and23(out[22], ~in[0], in[1], in[2], ~in[3], in[4]);
	and and24(out[23], in[0], in[1], in[2], ~in[3], in[4]);
	
	and and25(out[24], ~in[0], ~in[1], ~in[2], in[3], in[4]);
	and and26(out[25], in[0], ~in[1], ~in[2], in[3], in[4]);
	and and27(out[26], ~in[0], in[1], ~in[2], in[3], in[4]);
	and and28(out[27], in[0], in[1], ~in[2], in[3], in[4]);
	
	and and29(out[28], ~in[0], ~in[1], in[2], in[3], in[4]);
	and and30(out[29], in[0], ~in[1], in[2], in[3], in[4]);
	and and31(out[30], ~in[0], in[1], in[2], in[3], in[4]);
	and and32(out[31], in[0], in[1], in[2], in[3], in[4]);

endmodule


	
module tristate(in, oe, out);
	input in, oe;
	output out;
	
	assign out = oe? in : 1'bz;
	
endmodule
	
	