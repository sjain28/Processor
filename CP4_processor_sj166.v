module CP4_processor_sj166(clock, reset, /*ps2_key_pressed, ps2_out, lcd_write, lcd_data,*/ dmem_data_in, dmem_address, imem_out, 
									aluout_W, target_W, data_W, pc_W, opcode_W, rd_addr_W, aluop_W, overflow_W, FD_reset, F_D_out, PC_out);

	input 			clock, reset/*, ps2_key_pressed*/;
	//input 	[7:0]	ps2_out;
	
	//output 			lcd_write;
	//output 	[31:0] 	lcd_data;
	
	output 	[31:0] 	dmem_data_in;
	output	[11:0]	dmem_address;
	
	
/////FETCH STAGE: PC, IMEM, F/D register//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//TODO: Hook up imem
	//TODO: Add logic to deal with setx; need to do this in all stages
	
	wire[31:0] PC_in, PC_incr;
	output[31:0] PC_out;
	output[31:0] F_D_out; 
	wire[11:0] imem_in;
	input[31:0] imem_out;

	output FD_reset;

	register PC(.clk(clock), .data_in(PC_in), .write_enable(1'b1), .data_out(PC_out), .ctrl_reset(reset));
	assign imem_in = PC_out[11:0]; //imem read address = bottom 12 bits of PC 
	
	//imem myimem(	.address 	(imemin),
	//				.clken		(1'b1),
	//				.clock		(clock) //,
					//.q			(imem_out) // change where output q goes...
	//);
	
	register F_D(.clk(clock), .data_in(imem_out), .write_enable(1'b1), .data_out(F_D_out));
	
	adder_32 PC_adder(.A(PC_out), .B(32'h00000001), .Cin(1'b0), .Sums(PC_incr));
	
	
/////DECODE STAGE: REGFILE AND D/X////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//TODO: Test if correct values are read from regfile
	wire[4:0] rs_addr, rt_addr, regfile_write_addr, regfile_readinput_B, regfile_readinput_A;
	wire regfile_write_enable, rs_write;
	wire branch_indicator, sw_indicator, jr_indicator, bex_indicator, blt_indicator, bne_indicator;
	wire[31:0] regread_A, regread_B, rd_writedata, rs_writeData;
	wire[4:0] rstatus_addr = 5'b11110; //rstatus = 30
	
	
	//A = rs or rstatus if it's a bex, B = rt, or rd if it's a branch or a sw or a jr
	regfile_mod reg_file(.clock(clock), .ctrl_writeEnable(regfile_write_enable), .ctrl_reset(reset), .ctrl_writeReg(regfile_write_addr), 
						  .ctrl_readRegA(regfile_readinput_A[4:0]), .ctrl_readRegB(regfile_readinput_B[4:0]), .data_writeReg(rd_writedata[31:0]),
						  .rs_write(rs_write), .rs_writeData(rs_writeData), 
						  .data_readRegA(regread_A[31:0]), .data_readRegB(regread_B[31:0]));
	
	//Current instruction is branch instruction if opcode = 00010 or 00110
	assign bne_indicator = (~|F_D_out[31:29] && F_D_out[28] && ~F_D_out[27]); 
	assign blt_indicator = (~|F_D_out[31:30] && &F_D_out[29:28] && ~F_D_out[27]);
	assign branch_indicator = blt_indicator || bne_indicator;
	
	//Current instruction is sw if opcode = 00111
	assign sw_indicator = ~|F_D_out[31:30] && &F_D_out[29:27];
	
	//Current instruction is jr if opcode = 00100
	assign jr_indicator = (~|F_D_out[31:30] && F_D_out[29] && ~|F_D_out[28:27]);
	
	//Current instruction is bex if opcode = 10110
	assign bex_indicator = F_D_out[31] && ~F_D_out[30] && &F_D_out[29:28] && ~F_D_out[27];
	
	
	//If current instr is a bex, then the reg A that we read from will be rstatus, instead of rs
	generate
	
	for(i = 0; i < 5; i = i+1) begin: loop1
		//a: rs
		//b: rstatus
		//ctrl: bex indicator
		mux_21 temp(.a(F_D_out[i+17]), .b(rstatus_addr[i]), .ctrl(bex_indicator), .out(regfile_readinput_A[i]));
	end
	endgenerate
	
	// If current instr is a branch or sw, then the reg B that we read from regile will be rd, not rt. 
	genvar i; 
	generate
	
	for(i = 0; i < 5; i = i+1) begin: loop2
		//a: rt
		//b: rd
		//ctrl: branch indicator OR sw indicator
		mux_21 temp(.a(F_D_out[i+12]), .b(F_D_out[i+22]), .ctrl(branch_indicator || sw_indicator || jr_indicator), .out(regfile_readinput_B[i]));
	end
	endgenerate
	
	
	//_x denotes that these are the values for X stage
	wire DX_reset;
	wire[4:0] alu1_x, sh_x, rd_addr_x;
	wire[31:0] pc_x,  regA_x, regB_x, imdt_x, tgt_x;
	wire [4:0] op_x;
	
	DX d_x(.op(F_D_out[31:27]), .pc(PC_incr[31:0]), .alu(F_D_out[6:2]), .sh(F_D_out[11:7]), .a(regread_A[31:0]), .b(regread_B[31:0]), 
			 .imdt(F_D_out[16:0]), .t(F_D_out[26:0]), .rd_addr(F_D_out[26:22]), .clock(clock), 
			 .DX_reset(DX_reset), .opcode(op_x[4:0]), .PCplusone(pc_x[31:0]), .ALUopcode(alu1_x[4:0]), .shamt(sh_x[4:0]), .regA(regA_x[31:0]), 
			 .regB(regB_x[31:0]), .immediate(imdt_x[31:0]), .target(tgt_x[31:0]), .rd_address(rd_addr_x[4:0]));
	
	
	
//////EXECUTE STAGE: ALUs, branch logic /////////////////////////////////////////////////////////////////////////////////////////////////////

	wire br_x, jr_x, j_x, jal_x, bne_x, blt_x, bex_x;
	
	//Current instruction is branch instruction if opcode = 00010 or 00110
	assign bne_x = (~|op_x[4:2] && op_x[1] && ~op_x[0]); 
	assign blt_x = (~|op_x[4:3] && &op_x[2:1] && ~op_x[0]);
	assign br_x = blt_x || bne_x;
	
	//Current instruction is jr if opcode = 00100
	assign jr_x = ~|op_x[4:3] && op_x[2] && ~|op_x[1:0];
	
	//Current instruction is bex if opcode = 10110
	assign bex_x = op_x[4] && ~op_x[3] && &op_x[2:1] && ~op_x[0];
	
	//Current instruction is j indicator if opcode = 00001
	assign j_x = ~|op_x[4:1] && op_x[0];
	
	//Current instruction is jal if opcode = 00011
	assign jal_x = ~op_x[4:2] && &op_x[1:0];
	
	
	//Alu 2
	wire[31:0] branch_target;
	ALU ALU2(.data_operandA(pc_x[31:0]), .data_operandB(imdt_x[31:0]), .ctrl_ALUopcode(5'b00000), 
				.ctrl_shiftamt(5'b00000), .data_result(branch_target[31:0]));
				
	
	wire r_type_x;
	
	//Current isn is r-type if opcode = 00000
	assign r_type_x = ~|op_x[4:0];
	
	wire[31:0] alu1_inB, alu1_int; //Pick register if it's an r-type or a branch, pick imdt otherwise
	
	//MUX to select ALU1 intermediate input
	generate
	for(i = 0; i < 32; i = i+1) begin: loop3
		//a: imdt
		//b: registerb
		//ctrl: r_type_x OR branch
		mux_21 temp(.a(imdt_x[i]), .b(regB_x[i]), .ctrl(br_x || r_type_x), .out(alu1_int[i]));
	end
	endgenerate
	
	//If bex, alu1 input B = 0's
	assign alu1_inB[31:0] = bex_x ? 32'h00000000 : alu1_int[31:0];
	
	//ALU1 opcode: If it's an R-type, use the ALU opcode from FD. If not, default to 0 (addition). Then, if it's a branch or bex, pick subtraction. 
	wire[4:0] intermediate_opcode, alu1_opcode;
	assign intermediate_opcode = r_type_x ? alu1_x[4:0] : 5'b00000;
	assign alu1_opcode = br_x || bex_x ? 5'b00001 : intermediate_opcode;
	
	wire[31:0] alu1_out;
	wire alu1_LT, alu1_NEQ, alu1_OF;
	
	//ALU 1
	ALU ALU1(.data_operandA(regA_x[31:0]), .data_operandB(alu1_inB[31:0]), .ctrl_ALUopcode(alu1_opcode[4:0]), 
				.ctrl_shiftamt(sh_x[4:0]), .data_result(alu1_out[31:0]), .isNotEqual(alu1_NEQ), .isLessThan(alu1_LT), .overflow(alu1_OF));
	
	//X Stage Control 
	
	wire take_blt = blt_x && ~alu1_LT && alu1_NEQ;
	wire take_bne = bne_x && alu1_NEQ;
	wire take_branch = take_blt || take_bne;
	
	wire take_bex = bex_x && alu1_NEQ;
	wire take_target = j_x || jal_x || take_bex;
	
	wire take_rd = jr_x;
	
	
	//PC_alt will be one of {Branch Target, Target, or RD} .... PC will either be PC_alt or PC_Incr; if take_alt is true, PC will be PC_alt 
	wire [31:0] PC_alt; 
	wire take_alt = take_branch || take_target || take_rd;
	
	//Flush FD and DX if we branch or jump
	//assign DX_reset = take_alt || reset;
	assign FD_reset = take_alt || reset;
	
	//MUX: alt_int = branch target or immediate target
	wire[31:0] alt_int;
	generate
	
	for(i = 0; i < 32; i = i+1) begin: loop4
		//a: branch target
		//b: target
		//ctrl: take_target
		mux_21 temp(.a(branch_target[i]), .b(tgt_x[i]), .ctrl(take_target), .out(alt_int[i]));
	end
	endgenerate

	
	//MUX 2: Final value of PC_alt
	generate
	
	for(i = 0; i < 32; i = i+1) begin: loop5
		//a: branch target or target
		//b: rd
		//ctrl: take_rd
		mux_21 temp(.a(alt_int[i]), .b(regB_x[i]), .ctrl(take_rd), .out(PC_alt[i]));
	end
	endgenerate
	
	//MUX 3: PC = PC_Alt or PC_Incr
	generate
	for(i = 0; i < 32; i = i+1) begin: loop6
		//a: PC+1
		//b: PC alt
		//ctrl: take_alt
		mux_21 temp(.a(PC_incr[i]), .b(PC_alt[i]), .ctrl(take_alt), .out(PC_in[i]));
	end
	endgenerate


	wire[31:0] alu1out_M, target_M, regB_M, pc_M;
	wire[4:0] opcode_M, rd_addr_M, aluop_M;
	wire overflow_M;
	
	XM x_m(.op(op_x), .rd(rd_addr_x), .regb(regB_x), .alu(alu1_out), .tgt(tgt_x), .clock(clock), .reset(reset), .of(alu1_OF), .aluop(alu1_opcode), .pc(pc_x),
			 .overflow(overflow_M), .opcode(opcode_M), .rd_addr(rd_addr_M), .regB_data(regB_M), .aluout(alu1out_M), .target(target_M), .alu_opcode(aluop_M), .pc_out(pc_M));

	

	
	
	////// M STAGE: Memory reads and writes /////////////////////////////////////////////////////////////////////////////////////////////////////////

	assign dmem_address = alu1out_M[11:0];
	assign dmem_data_in = regB_M[31:0];
	wire[31:0] dmem_out;
	wire sw_M;
	assign sw_M = ~|opcode_M[4:3] && &opcode_M[2:0];

	
	//dmem mydmem(.address	(dmem_address), .clock(clock), .data(debug_data), .wren(sw_M), .q	(dmem_out)); 
	
	output[31:0] aluout_W, target_W, data_W, pc_W;
	output[4:0] opcode_W, rd_addr_W, aluop_W;
	output overflow_W;
	
	//data, alu, op, rd, tgt, of, clock, reset, data_out, alu_out, opcode, rd_addr, target, overflow
	MW M_W(.data(dmem_out), .alu(alu1out_M), .op(opcode_M), .rd(rd_addr_M), .tgt(target_M), .of(overflow_M), .clock(clock), .reset(reset), .aluop(aluop_M), .pc(pc_M),
			 .data_out(data_W), .alu_out(aluout_W), .opcode(opcode_W), .rd_addr(rd_addr_W), .target(target_W), .overflow(overflow_W),
			 .pc_out(pc_W), .alu_opcode(aluop_W));
	
	
	//////// W stage: Writing back to regfile ////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	//	wire regfile_write_enable, rs_write;
	//rd_writedata, rs_writeData
	//regfile_write_addr
	
	wire rtype_W = ~|opcode_W[4:0];
	
	wire add_W = rtype_W && ~|aluop_W[4:0]; //00000
	wire sub_W = rtype_W && (~|aluop_W[4:1] && aluop_W[0]); //00001
	wire mult_W = rtype_W && (~|aluop_W[4:3] && &aluop_W[2:1] && ~aluop_W[0]); //00110
	wire div_W = rtype_W && (~|aluop_W[4:3] && &aluop_W[2:0]); //00111
	
	wire addi_W = ~|opcode_W[4:3] && &opcode_W[2:0]; //00111
	wire lw_W = ~opcode_W[4] && opcode_W[3] && ~|opcode_W[2:0]; //01000
	wire itype_W = addi_W || lw_W;
	
	wire setx_W = opcode_W[4] && ~opcode_W[3] && opcode_W[2] && ~opcode_W[1] && opcode_W[0];//10101
	
	wire jal_W = ~|opcode_W[4:2] && &opcode_W[1:0]; //00011
	
	assign regfile_write_enable = rtype_W || itype_W || jal_W; //Do a register file write for every rtype, for addi/lw, and for jal
	
	//Write to rstatus for: add, subtract, mult, div, addi, setx	
	wire overflow_condition = (add_W || sub_W || mult_W || div_W || addi_W) && overflow_W;
	assign rs_write = overflow_condition || setx_W;
	
	// rd_addr for r-type, lw, addi; $31 for jal.
	assign regfile_write_addr = (rtype_W || lw_W || addi_W) ? rd_addr_W : 5'b11111; 	
	
	
	//Overflow code: 1 for add, 2 for addi, 3 for sub, 4 for mult, 5 for div
	wire[31:0] overflow_code;
	assign overflow_code[0] = add_W || sub_W || div_W;
	assign overflow_code[1] = addi_W || sub_W;
	assign overflow_code[2] = mult_W || div_W;
	
	//target for setx, overflow code otherwise
	assign rs_writeData = setx_W ? target_W : overflow_code;
	
	//rd_writeData: aluout for r-type, addi. data_out for lw. PC+1 for jal. 
	wire[31:0] int_data;
	assign int_data = (rtype_W || addi_W) ? aluout_W : data_W;
	
	assign rd_writedata = jal_W ? pc_W : int_data;
	
endmodule
