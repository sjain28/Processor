module MW(data, alu, op, rd, tgt, of, clock, reset, data_out, alu_out, opcode, rd_addr, target, overflow);

input[31:0] data, alu, tgt;
input[4:0] op, rd;
input of, clock, reset;

output[4:0] opcode, rd_addr;
output[31:0] data_out, alu_out, target;
output overflow;

register regData(.clk(clock), .data_in(data), .write_enable(1'b1), .data_out(data_out), .ctrl_reset(reset));
register alureg(.clk(clock), .data_in(alu), .write_enable(1'b1), .data_out(alu_out), .ctrl_reset(reset));
register tgtreg(.clk(clock), .data_in(tgt), .write_enable(1'b1), .data_out(target), .ctrl_reset(reset));

wire[31:0] misc_in, misc_out;
assign misc[4:0] = op;
assign misc[9:5] = rd;
assign misc[10] = of;

register misc(.clk(clock), .data_in(misc_in), .write_enable(1'b1), .data_out(misc_out), .ctrl_reset(reset));

assign opcode = misc_out[4:0];
assign rd_addr = misc_out[9:5];
assign overflow = misc_out[10];

endmodule
