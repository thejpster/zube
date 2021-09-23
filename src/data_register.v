/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 *
 * This is a register which can be written by the Z80. The contents of the register are always available on `data_out`.
 *
 * The contents are updated on the rising edge of `write_strobe`.
 * The contents are reset to zero on the rising edge of `reset`.
 *
 * Address decoding is handled outside the register.
 *
 * The `clk` input should be a high-speed wishbone clock, and the strobes should be aligned to that clock.
 */

`default_nettype none
`timescale 1ns/1ns
module data_register(
	input clk,
	input reset,
	input write_strobe,
	input[7:0] data_in,
	output[7:0] data_out
	);

	reg[7:0] contents;

	always @(posedge clk) begin
		if (reset) begin
			// Reset signal is low, so reset all state
			contents <= 8'b00000000;
		end else if (write_strobe) begin
			contents <= data_in;
		end
	end
	
	assign data_out = contents;

endmodule
`default_nettype wire