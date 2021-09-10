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
	input reset_b,
	input reg1_cs_b,
	input reg2_cs_b,
	input write_strobe_b,
	input read_strobe_b,
	inout[7:0] data_bus
	);


	// Register Number 1
	reg[7:0] reg1_contents;

	// Register Number 2
	reg[7:0] reg2_contents;

	// Buffered output data
	reg[7:0] sync_data_out;

	// Buffered input data
	reg[7:0] sync_data_in;

	// Buffered write strobe
    reg sync_write_strobe_b;

    // Buffered read strobe
    reg sync_read_strobe_b;

    wire bus_dir;

	always @(posedge clk) begin
		// Sample incoming signals with our high speed clock
		// Helps avoid metastability, by keeping everything ticking along with the high speed clock
		sync_write_strobe_b = write_strobe_b;
		sync_read_strobe_b = read_strobe_b;
		sync_data_in = data_bus;
	end

	always @(posedge clk) begin
		if (~reset_b) begin
			// Reset signal is low, so reset all state
			reg1_contents <= 8'b00000000;
			reg2_contents <= 8'b00000000;
		end else if (~sync_write_strobe_b) begin
			// Write strobe has gone low, so grab value off data bus
			if (~reg1_cs_b) begin
				// Update reg1
				reg1_contents <= sync_data_in;
			end
			if (~reg2_cs_b) begin
				// Update reg2
				reg2_contents <= sync_data_in;
			end
		end else if (~sync_read_strobe_b) begin
			// Read strobe has gone low, so write value to data bus
			if (~reg1_cs_b) begin
				// Read out reg1
				sync_data_out <= reg1_contents;
			end
			if (~reg2_cs_b) begin
				// Read out reg2
				sync_data_out <= reg2_contents;
			end
		end
	end

	// Only drive the bus when required
	assign bus_dir = reset_b && ~read_strobe_b && (~reg1_cs_b || ~reg2_cs_b);
	assign data_bus = bus_dir ? sync_data_out : 8'bzzzzzzzz;

endmodule
`default_nettype wire

// End of file
