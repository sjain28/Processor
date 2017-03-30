//Modified version of regfile: Has an extra write port for $rstatus, register 31

module regfile_mod(
	clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, 
	ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA,
	data_readRegB, rs_write, rs_writeData
	);
	
	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input[31:0] data_writeReg, rs_writeData;
	input rs_write;
	
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
	for(i = 0; i < 31; i = i+1) begin: loop1
		and and_temp(register_write_enable_bits[i], ctrl_writeEnable, write_select_bits[i]);
	end
	endgenerate
	
	generate
	for(i = 0; i < 31; i = i+1) begin: loop2
		register reg_temp(clock, data_writeReg, register_write_enable_bits[i], Reg_data[32*i+31:32*i], ctrl_reset);
		end
	endgenerate
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Can write to $rstatus using regular write address or using rs_write (don't need writeenable for the latter); 
	assign register_write_enable_bits[31] = rs_write || (write_select_bits[31] && ctrl_writeEnable);
	
	//Write data to $rstatus: If rs_write is enabled, we select rs_writeData; otherwise, we select the regular write data
	wire[31:0] rstatus_dataIn;
	assign rstatus_dataIn = rs_write ? rs_writeData[31:0] : data_writeReg[31:0];
	
	register reg_status(clock, rstatus_dataIn, register_write_enable_bits[31], Reg_data[1023:992], ctrl_reset);
	
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
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
	
	
module tristate(in, oe, out);
	input in, oe;
	output out;
	
	assign out = oe? in : 1'bz;
	
endmodule
	
	