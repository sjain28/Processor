module mux_21(a, b, ctrl, out);
input a, b, ctrl;
output out;

assign out = ctrl ? b : a;

endmodule
