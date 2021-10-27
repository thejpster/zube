/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 *
 * This is a FIFO register. The contents of the
 * register are always available on `data_out`.
 *
 * * The new contents are stored on the rising edge of `write_strobe`.
 * * The old contents are retrieved on the rising edge of `write_strobe`.
 * * The empty bit indicates when the FIFO is empty.
 * * The full bit indicates when the FIFO is full.
 * * Overflowing the FIFO is undefined behaviour.
 * * The FIFO is emptied on the rising edge of `reset`.
 *
 * Address decoding is handled outside the register.
 *
 * The `clk` input should be a high-speed wishbone clock, and the strobes
 * should be aligned to that clock.
 */

`default_nettype none
`timescale 1ns/1ns
module data_register #(
	// Size of FIFO
	parameter [7:0]  DEPTH_BITS = 8'h03
)(
	input wire clk,
	input wire reset,
	input wire write_strobe,
	input wire read_strobe,
	input wire [7:0] data_in,
	output wire [7:0] data_out,
	output wire not_empty,
	output wire full
	);

	localparam DEPTH = 1 << DEPTH_BITS;

	reg[7:0] contents [DEPTH - 1:0];
	reg [DEPTH_BITS - 1:0] read_ptr;
	reg [DEPTH_BITS - 1:0] write_ptr;
	reg [DEPTH_BITS:0] count;
	reg old_write_strobe;
	reg old_read_strobe;

	wire write_cycle;
	wire read_cycle;

	assign write_cycle = write_strobe && ~old_write_strobe;
	assign read_cycle = read_strobe && ~old_read_strobe;

	always @(posedge clk) begin
		if (reset) begin
			// Reset signal is active, so reset all state
			read_ptr <= 0;
			write_ptr <= 0;
			contents[0] <= 0;
			old_write_strobe <= 0;
			old_read_strobe <= 0;
			count <= 0;
		end else begin
			// Handle write
			if (!full && write_cycle) begin
				contents[write_ptr] <= data_in;
				write_ptr <= write_ptr + 1;
			end
			// Handle read
			if (not_empty && read_cycle) begin
				read_ptr <= read_ptr + 1;
			end
			// Update counter
			if (!full && write_cycle && not_empty && read_cycle) begin
				// No change
				count <= count;
			end else if (not_empty && read_cycle) begin
				count <= count - 1;
			end else if (!full && write_cycle) begin
				count <= count + 1;
			end

			old_read_strobe <= read_strobe;
			old_write_strobe <= write_strobe;
		end
	end

	assign not_empty = count != 0;
	assign full = count == DEPTH;
	assign data_out = not_empty ? contents[read_ptr] : 8'h00;

endmodule
`default_nettype wire