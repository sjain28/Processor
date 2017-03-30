module DX(op, pc, alu, sh, a, b, imdt, t, rd_addr, clock, DX_reset, 
			 opcode, PCplusone, ALUopcode, shamt, regA, regB, immediate, target, rd_address);

input [4:0] op, alu, sh, rd_addr; //op = opcode, alu = aluopcode, sh = shamt, rd_addr = rd address
input [31:0] a, b, pc; //a = reg a contents, b = reg b contents, pc = PC+1 for the instruction being stored in DX
input [16:0] imdt;
input[26:0] t;
input clock, DX_reset; //j = jr indicator, bex = bex indicator

output [4:0] opcode, ALUopcode, shamt, rd_address;
output [31:0] regA, regB, PCplusone;
output [31:0] immediate;
output [31:0] target;

register A(.clk(clock), .data_in(a), .write_enable(1'b1), .data_out(regA), .ctrl_reset(DX_reset));
register B(.clk(clock), .data_in(b), .write_enable(1'b1), .data_out(regB), .ctrl_reset(DX_reset));

//Sign extending the immediate
wire[31:0] sx_imdt;
assign sx_imdt[16:0] = imdt[16:0];
assign sx_imdt[31:17] = imdt[16] ? 15'b111111111111111 : 15'b00000000000000000;
register I(.clk(clock), .data_in(sx_imdt), .write_enable(1'b1), .data_out(immediate), .ctrl_reset(DX_reset));

//Target is always positive; we sign extend target with 0's
wire [31:0] sx_tgt;
assign sx_tgt[26:0] = t[26:0];
assign sx_tgt[31:27] = 5'b00000;
register T(.clk(clock), .data_in(sx_tgt), .write_enable(1'b1), .data_out(target), .ctrl_reset(DX_reset));


register P(.clk(clock), .data_in(pc), .write_enable(1'b1), .data_out(PCplusone), .ctrl_reset(DX_reset));

wire[31:0] misc_wires;
wire[31:0] misc_outputs;

assign misc_wires[4:0] = op;
assign misc_wires[9:5] = alu;
assign misc_wires[14:10] = sh;
assign misc_wires[19:15] = rd_addr;

register misc(.clk(clock), .data_in(misc_wires), .write_enable(1'b1), .data_out(misc_outputs), .ctrl_reset(DX_reset));

assign opcode = misc_outputs[4:0];
assign ALUopcode = misc_outputs[9:5];
assign shamt = misc_outputs[14:10];
assign rd_address = misc_outputs[19:15];

endmodule