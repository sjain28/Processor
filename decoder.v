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
