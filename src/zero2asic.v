/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ns
module zero2asic (
	input clk,
	input reset,
	input cs,
	input data_in,
	output data_out
	);

	reg flipflop;

	always @(posedge clk) begin
		if (reset) begin
			flipflop <= 1'b0;	
		end else begin
			flipflop <= data_in;		
		end		
	end

	assign data_out = reset ? 1'b0 : flipflop; 

endmodule
`default_nettype wire