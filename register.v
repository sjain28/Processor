module register(clk, data_in, write_enable, data_out, ctrl_reset);

	input clk, write_enable, ctrl_reset;
	input [31:0] data_in;
	output [31:0] data_out;
	
	assign async_ctrl = 1;
	
	genvar i; 
	generate
	for(i = 0; i < 32; i = i+1) begin: loop1
		dffe dffe_temp(.d(data_in[i]), .clk(clk), .clrn(~ctrl_reset), .prn(async_ctrl),
		.ena(write_enable), .q(data_out[i]));
	end
	endgenerate
	
endmodule
