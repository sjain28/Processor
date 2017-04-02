module counter33 (clock, reset, out);

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
7'd32: next = 33;
7'd33: next = 33;

default: next = 33;

endcase
end
endmodule
