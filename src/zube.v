/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ns
module zube(
	input clk,
	input reset_b,
	input z80_write_strobe_b,
	input z80_read_strobe_b,
	input [7:0] z80_address_bus,
	input[7:0] z80_data_bus_in,
	output[7:0] z80_data_bus_out,
	output z80_bus_dir
	);

    // Buffered data bus
    reg[7:0] sync_z80_data_bus_in;
    reg[7:0] sync_z80_data_bus_out;

    // Write to Status OUT from Z80
	reg status_out_cs;
    // Write to Status IN from SoC
	reg status_in_cs;
    // Write to Data OUT from Z80
	reg data_out_cs;
    // Write to Data IN from Soc
	reg data_in_cs;

	// Signals when we can drive the Z80 data bus
	reg data_out_ready;

	// Our base address
	reg[7:0] base_address;

	// What's in the Data OUT Register 
	wire[7:0] data_out_contents;

	// What's in the Data In Register 
	wire[7:0] data_in_contents;

	// What's in the Status In Register
	wire[7:0] status_in_contents;

	// What's in the Status Out Register
	wire[7:0] status_out_contents;

	// Are we driving the Z80 bus?
	reg bus_dir;

	// Z80 to SoC
	data_register data_out(.clk(clk), .reset(~reset_b), .write_strobe(data_out_cs), .data_in(sync_z80_data_bus_in), .data_out(data_out_contents));
	data_register status_out(.clk(clk), .reset(~reset_b), .write_strobe(status_out_cs), .data_in(sync_z80_data_bus_in), .data_out(status_out_contents));

	// SoC to Z80
	data_register data_in(.clk(clk), .reset(~reset_b), .write_strobe(data_in_cs), .data_in(sync_z80_data_bus_in), .data_out(data_in_contents));
	data_register status_in(.clk(clk), .reset(~reset_b), .write_strobe(status_in_cs), .data_in(sync_z80_data_bus_in), .data_out(status_in_contents));

	assign base_address = 16'h80;

	always @(posedge clk) begin
		if (~reset_b) begin
			// Reset state here
			data_out_ready <= 1'b0;
			bus_dir <= 1'b0;
			status_out_cs <= 1'b0;
			status_in_cs <= 1'b0;
			data_out_cs <= 1'b0;
			data_in_cs <= 1'b0;
			sync_z80_data_bus_out <= 8'h00;
		end else begin
			// Sample slow incoming signals with our high speed clock
			// Helps avoid metastability, by keeping everything ticking along with the high speed clock
			sync_z80_data_bus_in <= z80_data_bus_in;
			data_out_cs <= (z80_address_bus == base_address) && ~z80_write_strobe_b;
			status_out_cs <= (z80_address_bus == base_address + 16'h0001) && ~z80_write_strobe_b;
			if ((z80_address_bus == base_address) && ~z80_read_strobe_b && ~data_out_ready) begin
				// Read Data In
				data_out_ready <= 1'b1;
				sync_z80_data_bus_out <= data_in_contents;
			end else if ((z80_address_bus == (base_address + 1)) && ~z80_read_strobe_b && ~data_out_ready) begin
				// Read Status
				data_out_ready <= 1'b1;
				sync_z80_data_bus_out <= status_in_contents;
			end else if (data_out_ready && z80_read_strobe_b) begin
				// Read strobe released - we can no longer drive the bus
				data_out_ready <= 1'b0;
			end
			// Only drive the Z80 bus when we're not in reset, and there's an active strobe, and it's one of our addresses
			bus_dir <= reset_b && data_out_ready;
		end
	end

	assign z80_bus_dir = bus_dir;
	assign z80_data_bus_out = sync_z80_data_bus_out;

endmodule
`default_nettype wire

// End of file
