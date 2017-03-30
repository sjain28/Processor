module XM(op, rd, regb, alu, tgt, of, clock, reset, opcode, rd_addr, regB_data, aluout, target, overflow);

input[4:0] op, rd;
input[31:0] regb, alu, tgt;
input clock, reset, of;

output[4:0] opcode, rd_addr;
output[31:0] regB_data, aluout, target;
output overflow;

register regB(.clk(clock), .data_in(regb), .write_enable(1'b1), .data_out(regB_data), .ctrl_reset(reset));
register alureg(.clk(clock), .data_in(alu), .write_enable(1'b1), .data_out(aluout), .ctrl_reset(reset));
register tgtreg(.clk(clock), .data_in(tgt), .write_enable(1'b1), .data_out(target), .ctrl_reset(reset));

wire[31:0] misc_in, misc_out;
assign misc_in[4:0] = op;
assign misc_in[9:5] = rd;
assign misc_in[10] = of;

register misc(.clk(clock), .data_in(misc_in), .write_enable(1'b1), .data_out(misc_out), .ctrl_reset(reset));

assign opcode = misc_out[4:0];
assign rd_addr = misc_out[9:5];
assign overflow = misc_out[10];

endmodule
