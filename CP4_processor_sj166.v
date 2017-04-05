module CP4_processor_sj166(clock, reset, /*ps2_key_pressed, ps2_out, lcd_write, lcd_data,*/ dmem_data_in, dmem_address, 
									opcode_W, regfile_write_addr, regfile_write_enable, rs_write, rd_writedata, rs_writeData, imem_out, flush, sw_M, 
									dmem_out, PC_out, op_x, M_data, alu_inA, alu_inB, take_blt, alu1_LT, alu1_NEQ, alu1_OF, alu1_opcode,
									mxbypass_A, mxbypass_B, wxbypass_A, wxbypass_B);

	input 			clock, reset/*, ps2_key_pressed*/;
	//input 	[7:0]	ps2_out;
	
	//output 			lcd_write;
	//output 	[31:0] 	lcd_data;
	
	output 	[31:0] 	dmem_data_in;
	output	[11:0]	dmem_address;
	
	
/////FETCH STAGE: PC, IMEM, F/D register//////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire[31:0] PC_in, PC_incr, FD_in, PC_FD;
	output[31:0] PC_out;
	wire[31:0] F_D_out; 
	wire[11:0] imem_in;
	output[31:0] imem_out;
	output flush;

	register PC(.clk(~clock), .data_in(PC_in), .write_enable(1'b1), .data_out(PC_out), .ctrl_reset(reset));
	assign imem_in = PC_out[11:0]; //imem read address = bottom 12 bits of PC 
	
	imem myimem(	.address 	(imem_in),
					.clken		(1'b1),
					.clock		(~clock), 
					.q			(imem_out)
	);
	
	assign FD_in = flush ? 32'h00000000 : imem_out;
	register F_D(.clk(clock), .data_in(FD_in), .write_enable(1'b1), .data_out(F_D_out), .ctrl_reset(reset));
	register PC_F(.clk(clock), .data_in(PC_out), .write_enable(1'b1), .data_out(PC_FD), .ctrl_reset(reset));
	
	adder_32 PC_adder(.A(PC_out), .B(32'h00000001), .Cin(1'b0), .Sums(PC_incr));
	
	wire lw_D = ~F_D_out[31] && F_D_out[30] && ~|F_D_out[29:27]; //01000
	wire[4:0] rd_imem = imem_out[26:22];
	wire[4:0] rs_imem = imem_out[21:17];
	wire[4:0] rt_imem = imem_out[16:12];
	wire[4:0] rd_D = F_D_out[26:22];

	wire[4:0] rd_conflict = rd_imem ~^ rd_D;
	wire[4:0] rs_conflict = rs_imem ~^ rd_D;
	wire[4:0] rt_conflict = rt_imem ~^ rd_D;
	
	wire lw_conflict = lw_D && (&rd_conflict[4:0] || &rs_conflict[4:0] || &rt_conflict[4:0]);
	
/////DECODE STAGE: REGFILE AND D/X////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire[4:0] rs_addr, rt_addr, regfile_readinput_B, regfile_readinput_A;
	output[4:0] regfile_write_addr;
	output regfile_write_enable, rs_write;
	wire branch_indicator, sw_indicator, jr_indicator, bex_indicator, blt_indicator, bne_indicator;
	wire[31:0] regread_A, regread_B;
   output[31:0]	rd_writedata, rs_writeData;
	wire[4:0] rstatus_addr = 5'b11110; //rstatus = 30
	wire[4:0] regA_actual, regB_actual; //Indicates the ACTUAL register locations read for A and B

	
	//A = rs or rstatus if it's a bex, B = rt, or rd if it's a branch or a sw or a jr
	regfile_mod reg_file(.clock(~clock), .ctrl_writeEnable(regfile_write_enable), .ctrl_reset(reset), .ctrl_writeReg(regfile_write_addr), 
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
	
	assign regA_actual = bex_indicator ? rstatus_addr : F_D_out[21:17];
	assign regB_actual = branch_indicator || sw_indicator || jr_indicator ? F_D_out[26:22] : F_D_out[16:12];
	
	// If current instr is a branch or jr or sw, then the reg B that we read from regile will be rd, not rt. 
	genvar i; 
	generate
	
	for(i = 0; i < 5; i = i+1) begin: loop2
		//a: rt
		//b: rd
		//ctrl: branch indicator OR sw indicator OR jr indicator
		mux_21 temp(.a(F_D_out[i+12]), .b(F_D_out[i+22]), .ctrl(branch_indicator || sw_indicator || jr_indicator), .out(regfile_readinput_B[i]));
	end
	endgenerate
	
	
	//_x denotes that these are the values for X stage
	wire[4:0] alu1_x, sh_x, rd_addr_x, addrA_x, addrB_x;
	wire[31:0] pc_x,  regA_x, regB_x, imdt_x, tgt_x;
	output [4:0] op_x;
	
	DX d_x(.op(F_D_out[31:27]), .pc(PC_FD), .alu(F_D_out[6:2]), .sh(F_D_out[11:7]), .a(regread_A[31:0]), .b(regread_B[31:0]), .flush(flush), 
			 .imdt(F_D_out[16:0]), .t(F_D_out[26:0]), .rd_addr(F_D_out[26:22]), .clock(clock), .addrA(regA_actual), .addrB(regB_actual), 
			 .DX_reset(reset), .opcode(op_x[4:0]), .PCplusone(pc_x[31:0]), .ALUopcode(alu1_x[4:0]), .shamt(sh_x[4:0]), .regA(regA_x[31:0]), 
			 .regB(regB_x[31:0]), .immediate(imdt_x[31:0]), .target(tgt_x[31:0]), .rd_address(rd_addr_x[4:0]), .addressA(addrA_x), .addressB(addrB_x));
	
	
	
//////EXECUTE STAGE: ALUs, branch logic /////////////////////////////////////////////////////////////////////////////////////////////////////

	wire br_x, jr_x, j_x, jal_x, bne_x, blt_x, bex_x, r_type_x, lw_x, sw_x, addi_x;
	
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
	assign jal_x = ~|op_x[4:2] && &op_x[1:0];
	
	//00000
	assign r_type_x = ~|op_x[4:0];
	
	//01000
	assign lw_x = ~op_x[4] && op_x[3] && ~|op_x[2:0];
	
	//00111
	assign sw_x = ~|op_x[4:3] && &op_x[2:0];
	
	//00101
	assign addi_x = ~|op_x[4:3] && op_x[2] && ~op_x[1] && op_x[0];
	
	//Alu 2
	wire[31:0] branch_target;
	ALU ALU2(.data_operandA(pc_x[31:0]), .data_operandB(imdt_x[31:0]), .ctrl_ALUopcode(5'b00000), 
				.ctrl_shiftamt(5'b00000), .data_result(branch_target[31:0]));
				
	
		
	wire[31:0] alu_inA, alu_inB, alu1_int1, alu1_int2; //Pick register if it's an r-type or a branch, pick imdt otherwise; int1, int2 = intermediates for input B
	
	//MUX to select ALU1 intermediate input
	generate
	for(i = 0; i < 32; i = i+1) begin: loop3
		//a: imdt
		//b: registerb
		//ctrl: r_type_x OR branch
		mux_21 temp(.a(imdt_x[i]), .b(regB_x[i]), .ctrl(br_x || r_type_x), .out(alu1_int1[i]));
	end
	endgenerate
	
	//If bex, alu1 input B = 0's
	assign alu1_int2[31:0] = bex_x ? 32'h00000000 : alu1_int1[31:0];
	
	
	wire A_usesReg = r_type_x || addi_x || sw_x || lw_x || bex_x || blt_x || bne_x;
	wire B_usesReg = r_type_x || bne_x || blt_x;
	
	//MX BYPASSING
	wire[4:0] aX_M = addrA_x ~^ M_addr; //aX_M = bitwise XNOR of register A in X stage with write destination for M stage
	wire[4:0] bX_M = addrB_x ~^ M_addr; //bX_M = bitwise XNOR of register B in X stage with write destination for M stage
	
	output mxbypass_A, mxbypass_B;
	assign mxbypass_A = A_usesReg && M_writes && &aX_M[4:0];
	assign mxbypass_B = B_usesReg && M_writes && &bX_M[4:0];
	
	//WX BYPASSING
	output wxbypass_A, wxbypass_B;
	wire[4:0] aX_W = addrA_x ~^ regfile_write_addr;
	wire[4:0] bX_W = addrB_x ~^ regfile_write_addr;
	
	assign wxbypass_A = A_usesReg && regfile_write_enable && &aX_W[4:0];
	assign wxbypass_B = B_usesReg && regfile_write_enable && &bX_W[4:0];
	
	output[31:0] alu_inA, alu_inB;
	
	//PICKING BW MX AND MX BYPASSES
	wire[31:0] a_bypassed = mxbypass_A ? M_data : rd_writedata;
	assign alu_inA = wxbypass_A || mxbypass_A ? a_bypassed : regA_x;
	
	wire[31:0] b_bypassed = mxbypass_B ? M_data : rd_writedata;
	assign alu_inB = wxbypass_B || mxbypass_B ? b_bypassed : alu1_int2;
	
	
	//ALU1 opcode: If it's an R-type, use the ALU opcode from FD. If not, default to 0 (addition). Then, if it's a branch or bex, pick subtraction. 
	wire[4:0] intermediate_opcode;
	output[4:0] alu1_opcode;
	assign intermediate_opcode = r_type_x ? alu1_x[4:0] : 5'b00000;
	assign alu1_opcode = br_x || bex_x ? 5'b00001 : intermediate_opcode;
	
	wire[31:0] alu1_out;
	output alu1_LT, alu1_NEQ, alu1_OF;
	
	//ALU 1
	ALU ALU1(.data_operandA(alu_inA), .data_operandB(alu_inB), .ctrl_ALUopcode(alu1_opcode), 
				.ctrl_shiftamt(sh_x[4:0]), .data_result(alu1_out), .isNotEqual(alu1_NEQ), .isLessThan(alu1_LT), .overflow(alu1_OF));
	
	
	

	
	
	
	//Setting up multdiv							 
	wire[31:0] multdiv_result, multdiv_addr_out;
	wire multdiv_ready;
	
	wire[31:0] multdiv_addr_in, multdiv_A, multdiv_B;
	wire multdiv_exception, x_mult, x_div, multdiv_reset;
	wire[4:0] multdiv_writeAddr;
	
	assign multdiv_addr_in[4:0] = rd_addr_x;
		
	register multdiv_addr(clock, multdiv_addr_in, x_mult || x_div, multdiv_addr_out, reset);
	register mdA(~clock, alu_inA, x_mult || x_div, multdiv_A, reset);
	register mdB(~clock, alu_inB, x_mult || x_div, multdiv_B, reset);
	
	assign x_mult = ~|alu1_opcode[4:3] && &alu1_opcode[2:1] && ~alu1_opcode[0]; //mult if alu1_x = 00110
	assign x_div = ~|alu1_opcode[4:3] && &alu1_opcode[2:0]; //div if 00111
	
	multdiv mult_div(multdiv_A, multdiv_B, x_mult, x_div, clock, multdiv_result, multdiv_exception, 
						  multdiv_ready, multdiv_reset);
	
	wire[5:0] counter_outputs;
	counter33 multdiv_counter(.clock(clock), .reset(x_mult || x_div), .out(counter_outputs));
	
	//Reset multdiv when counter = 0
	assign multdiv_reset = ~|counter_outputs[5:0];
	
	
	
	
	
	
	
	
	
	
	//X Stage Control 
	
	output take_blt = blt_x && ~alu1_LT && |alu1_out[31:0];
	wire take_bne = bne_x && alu1_NEQ;
	wire take_branch = take_blt || take_bne;
	
	wire take_bex = bex_x && alu1_NEQ;
	wire take_target = j_x || jal_x || take_bex;
	
	wire take_rd = jr_x;
	
	
	//PC_alt will be one of {Branch Target, Target, or RD} .... PC will either be PC_alt or PC_Incr; if take_alt is true, PC will be PC_alt 
	wire [31:0] PC_alt; 
	wire take_alt = take_branch || take_target || take_rd;
	
	assign flush = take_alt;
	
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

	wire[31:0] jr_reg, jr_reg_bypassed;
	assign jr_reg_bypassed = (M_writes && &bX_M[4:0]) ? M_data : rd_writedata;
	assign jr_reg = (M_writes && &bX_M[4:0]) || (regfile_write_enable && &bX_W[4:0]) ? jr_reg_bypassed : regB_x;
		
	//MUX 2: Final value of PC_alt
	generate
	
	for(i = 0; i < 32; i = i+1) begin: loop5
		//a: branch target or target
		//b: rd
		//ctrl: take_rd (same as jr_x)
		mux_21 temp(.a(alt_int[i]), .b(jr_reg[i]), .ctrl(take_rd), .out(PC_alt[i]));
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
	
	XM x_m(.op(op_x), .rd(rd_addr_x), .regb(jr_reg), .alu(alu1_out), .tgt(tgt_x), .clock(clock), .reset(reset), .of(alu1_OF), .aluop(alu1_opcode), .pc(pc_x),
			 .overflow(overflow_M), .opcode(opcode_M), .rd_addr(rd_addr_M), .regB_data(regB_M), .aluout(alu1out_M), .target(target_M), .alu_opcode(aluop_M), .pc_out(pc_M));

	

	
	
	////// M STAGE: Memory reads and writes /////////////////////////////////////////////////////////////////////////////////////////////////////////

	assign dmem_address = alu1out_M[11:0];
	assign dmem_data_in = regB_M[31:0];
	output[31:0] dmem_out;
	output sw_M;
	assign sw_M = ~|opcode_M[4:3] && &opcode_M[2:0];

	
	dmem mydmem(.address	(dmem_address), .clock(~clock), .data(dmem_data_in), .wren(sw_M), .q	(dmem_out)); 
	
	wire[31:0] target_W, data_W, pc_W;
	wire[4:0] rd_addr_W, aluop_W;
	wire overflow_W;
	output[4:0] opcode_W;
	wire[31:0] aluout_W;
	
	//data, alu, op, rd, tgt, of, clock, reset, data_out, alu_out, opcode, rd_addr, target, overflow
	MW M_W(.data(dmem_out), .alu(alu1out_M), .op(opcode_M), .rd(rd_addr_M), .tgt(target_M), .of(overflow_M), .clock(clock), .reset(reset), .aluop(aluop_M), .pc(pc_M),
			 .data_out(data_W), .alu_out(aluout_W), .opcode(opcode_W), .rd_addr(rd_addr_W), .target(target_W), .overflow(overflow_W),
			 .pc_out(pc_W), .alu_opcode(aluop_W));
			 
			 
	//Control signals and data used for MX bypasses
	
	wire rtype_M, addi_M, setx_M, jal_M;
	
	//00000
	assign rtype_M = ~|opcode_M[4:0];
	
	//00101
	assign addi_M = ~|opcode_M[4:3] && opcode_M[2] && ~opcode_M[1] && opcode_M[0];
	
	//00011
	assign jal_M = ~|opcode_M[4:2] && &opcode_M[1:0];
	
	//10101
	assign setx_M = opcode_M[4] && ~opcode_M[3] && opcode_M[2] && ~opcode_M[1] && opcode_M[0];
	
	wire M_writes;
	wire[4:0] M_addr, M_addr_int;
	output[31:0] M_data;
	wire[31:0] M_data_int;
	
	assign M_writes = rtype_M || addi_M || setx_M || jal_M;
	
	//rd if addi or rtype, otherwise assume it's a setx and use $30...then check if it's a jal
	assign M_addr_int = addi_M || rtype_M ? rd_addr_M : 5'b11110;
	assign M_addr = jal_M ? 5'b11111 : M_addr_int;
	
	assign M_data_int = rtype_M || addi_M ? alu1out_M : target_M;
	assign M_data = jal_M ? pc_M : M_data_int;
	
	//////// W stage: Writing back to regfile ////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	//	wire regfile_write_enable, rs_write;
	//rd_writedata, rs_writeData
	//regfile_write_addr
	
	wire rtype_W = ~|opcode_W[4:0];
	
	wire add_W = rtype_W && ~|aluop_W[4:0]; //00000
	wire sub_W = rtype_W && (~|aluop_W[4:1] && aluop_W[0]); //00001
	wire mult_W = rtype_W && (~|aluop_W[4:3] && &aluop_W[2:1] && ~aluop_W[0]); //00110
	wire div_W = rtype_W && (~|aluop_W[4:3] && &aluop_W[2:0]); //00111
	
	wire rtype_regular = rtype_W && ~mult_W && ~div_W; //"regular" rtype = not mult or div
	
	wire addi_W = ~|opcode_W[4:3] && opcode_W[2] && ~opcode_W[1] && opcode_W[0]; //00101
	wire lw_W = ~opcode_W[4] && opcode_W[3] && ~|opcode_W[2:0]; //01000
	wire itype_W = addi_W || lw_W;
	
	wire setx_W = opcode_W[4] && ~opcode_W[3] && opcode_W[2] && ~opcode_W[1] && opcode_W[0];//10101
	
	wire jal_W = ~|opcode_W[4:2] && &opcode_W[1:0]; //00011
	
	//wire[31:0] multdiv_result;
	//wire multdiv_exception, multdiv_ready;
	//wire [4:0] multdiv_writeAddr
	
	//Do a register file write for regular rtypes, itypes, jal, and whenever multdiv is ready
	assign regfile_write_enable = rtype_regular || itype_W || jal_W || multdiv_ready; 
	
	//Write to rstatus for: add, subtract, mult, div, addi, setx	
	wire overflow_condition = ((add_W || sub_W || addi_W) && overflow_W) || (multdiv_ready && multdiv_exception);
	assign rs_write = overflow_condition || setx_W;
	
	// rd_addr for r-type, lw, addi; $31 for jal.
	wire[4:0] regfile_write_addr_int = (rtype_W || lw_W || addi_W) ? rd_addr_W : 5'b11111; 	
	assign regfile_write_addr = multdiv_ready ? multdiv_addr_out[4:0] : regfile_write_addr_int;
	
	//Overflow code: 1 for add, 2 for addi, 3 for sub, 4 for mult, 5 for div: WONT WORK FOR MULT DIV 
	wire[31:0] overflow_code;
	assign overflow_code[0] = add_W || sub_W || div_W;
	assign overflow_code[1] = addi_W || sub_W;
	assign overflow_code[2] = mult_W || div_W;
	
	//target for setx, overflow code otherwise
	assign rs_writeData = setx_W ? target_W : overflow_code;
	
	//rd_writeData: aluout for r-type regular, addi. data_out for lw. PC+1 for jal. multdiv out for multdiv. 
	wire[31:0] int_data1, int_data2;
	assign int_data1 = (rtype_W || addi_W) ? aluout_W : data_W;
	assign int_data2 = multdiv_ready ? multdiv_result : int_data1;
	
	assign rd_writedata = jal_W ? pc_W : int_data2;
	
	//TODO: 
	//Fix multdiv overflow codes; Right now, div_W and mult_W get triggered with the m/d instr reaches W stage...not when m/d result is actually ready
	//Deal with special case when X stage is reading rstatus, and we're updating rstatus with an exception code
	
	
endmodule
