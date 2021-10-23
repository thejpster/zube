/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 *
 * This is a register which can be written by the Z80. The contents of the
 * register are always available on `data_out`.
 *
 * * The contents are updated on the rising edge of `write_strobe`, and the
 *   `ready` bit is set.
 * * The ready bit is cleared on the rising edge of `read_strobe`.
 * * The contents are reset to zero on the rising edge of `reset`.
 *
 * Address decoding is handled outside the register.
 *
 * The `clk` input should be a high-speed wishbone clock, and the strobes
 * should be aligned to that clock.
 */

`default_nettype none
`timescale 1ns/1ns
module data_register(
	input wire clk,
	input wire reset,
	input wire write_strobe,
	input wire read_strobe,
	input wire [7:0] data_in,
	output wire [7:0] data_out,
	output reg ready
	);

	reg[7:0] contents;
	reg old_write_strobe;
	reg old_read_strobe;

	always @(posedge clk) begin
		if (reset) begin
			// Reset signal is active, so reset all state
			contents <= 8'b00000000;
			old_write_strobe <= 1'b0;
			old_read_strobe <= 1'b0;
			ready <= 1'b0;
		end else begin
			if (write_strobe && ~old_write_strobe) begin
				contents <= data_in;
				ready <= 1'b1;
			end else if (read_strobe && ~old_read_strobe) begin
				ready <= 1'b0;
			end
			old_read_strobe <= read_strobe;
			old_write_strobe <= write_strobe;
		end
	end

	assign data_out = contents;

endmodule
`default_nettype wire