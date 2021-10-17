/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ns
module zube #(
	// Wishbone base address
	parameter   [31:0]  BASE_ADDRESS    = 32'h3000_0000,
	parameter   [31:0]  Z80_ADDRESS     = BASE_ADDRESS,
	parameter   [31:0]  DATA_ADDRESS    = BASE_ADDRESS + 4,
	parameter   [31:0]  STATUS_ADDRESS  = BASE_ADDRESS + 8
) (
	/**
	 * Power Pins (only for gate-level simulation)
	 */

`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

	/**
	 * Clock and Reset
	 */

	// High speed (wishbone) clock
	input wire clk,

	// Goes low when module is in reset
	input wire reset_b,

	/**
	 * Z80 bus
	 */

	// goes low when address + data contain a write transaction
	input wire z80_write_strobe_b,
	// goes low when address contains a address being read
	input wire z80_read_strobe_b,
	// the bottom eight bits of the address bus
	input wire [7:0] z80_address_bus,
	// incoming data bus
	input wire [7:0] z80_data_bus_in,
	// outgoing data bus (to the external bus transceiver)
	output reg [7:0] z80_data_bus_out,
	// set high when the bus transceiver should drive the bus
	output wire z80_bus_dir,

	/**
	 * Wishbone bus
	 */

	// indicates that a valid bus cycle is in progress
	input wire wb_cyc_in,
	// indicates a valid data transfer cycle
	input wire wb_stb_in,
	// indicates whether the current local bus cycle is a READ or WRITE cycle.
	// The signal is negated during READ cycles, and is asserted during WRITE
	// cycles.
	input wire wb_we_in,
	// the address being read/written
	input wire [31:0] wb_addr_in,
	// incoming data bus
	input wire [31:0] wb_data_in,
	// indicates the termination of a normal bus cycle by this device.
	output reg wb_ack_out,
	// reject incoming request
	output wire wb_stall_out,
	// outgoing data
	output reg [31:0] wb_data_out,

	// IRQ to SoC when Data register has been written. Cleared on read.
	output reg irq_data_out,
	// IRQ to SoC when Status register has been written. Cleared on read.
	output reg irq_status_out

	// Note: There is no support for interrupts on the Z80 side!
	);

	// Buffered data bus. Sampled with the high speed clock.
	reg[7:0] sync_z80_data_bus_in;

	// Write to Status OUT from Z80
	reg status_out_write_stb;
	// Write to Status IN from SoC
	reg status_in_write_stb;
	// Write to Data OUT from Z80
	reg data_out_write_stb;
	// Write to Data IN from Soc
	reg data_in_write_stb;

	// Signals when we can drive the Z80 data bus
	reg data_out_ready;

	// Z80 I/O base address
	reg[7:0] z80_base_address;

	// What's in the Data Out Register
	wire[7:0] data_out_contents;

	// What's in the Data In Register
	wire[7:0] data_in_contents;

	// What's in the Status In Register
	wire[7:0] status_in_contents;

	// What's in the Status Out Register
	wire[7:0] status_out_contents;

	// Z80 to SoC
	data_register data_out(.clk(clk), .reset(~reset_b), .write_strobe(data_out_write_stb), .data_in(sync_z80_data_bus_in), .data_out(data_out_contents));
	data_register status_out(.clk(clk), .reset(~reset_b), .write_strobe(status_out_write_stb), .data_in(sync_z80_data_bus_in), .data_out(status_out_contents));

	// SoC to Z80
	data_register data_in(.clk(clk), .reset(~reset_b), .write_strobe(data_in_write_stb), .data_in(wb_data_in[7:0]), .data_out(data_in_contents));
	data_register status_in(.clk(clk), .reset(~reset_b), .write_strobe(status_in_write_stb), .data_in(wb_data_in[7:0]), .data_out(status_in_contents));

	// Never hold up the Wishbone bus
	assign wb_stall_out = 0;

	always @(posedge clk) begin
		if (~reset_b) begin
			// Reset state here
			data_out_ready <= 1'b0;
			status_out_write_stb <= 1'b0;
			status_in_write_stb <= 1'b0;
			data_out_write_stb <= 1'b0;
			data_in_write_stb <= 1'b0;
			irq_data_out <= 1'b0;
			irq_status_out <= 1'b0;
			z80_data_bus_out <= 8'h00;
			z80_base_address = 16'h80;
		end else begin
			// Sample slow incoming signals with our high speed clock
			// Helps avoid metastability, by keeping everything ticking along with the high speed clock
			sync_z80_data_bus_in <= z80_data_bus_in;

			data_out_write_stb <= (z80_address_bus == z80_base_address) && ~z80_write_strobe_b;
			status_out_write_stb <= (z80_address_bus == z80_base_address + 16'h0001) && ~z80_write_strobe_b;

			// Check for Z80 reads/writes

			if ( data_out_write_stb && z80_write_strobe_b ) begin
				// A write to Data OUT has finished (because z80_write_strobe_b is high)
				irq_data_out <= 1'b1;
			end else if ( status_out_write_stb && z80_write_strobe_b ) begin
				// A write to Status OUT has finished (because z80_write_strobe_b is high)
				irq_status_out <= 1'b1;
			end else if ((z80_address_bus == z80_base_address) && ~z80_read_strobe_b && ~data_out_ready) begin
				// The Z80 is reading from Data IN
				data_out_ready <= 1'b1;
				z80_data_bus_out <= data_in_contents;
			end else if ((z80_address_bus == (z80_base_address + 1)) && ~z80_read_strobe_b && ~data_out_ready) begin
				// The Z80 is reading from Status IN
				data_out_ready <= 1'b1;
				z80_data_bus_out <= status_in_contents;
			end else if (data_out_ready && z80_read_strobe_b) begin
				// Read strobe released - we can no longer drive the bus
				data_out_ready <= 1'b0;
			end

			// Check for wishbone reads/writes

			// Write Z80 base address
			if (wb_stb_in && wb_cyc_in && wb_we_in && !wb_stall_out && wb_addr_in == Z80_ADDRESS) begin
				z80_base_address <= wb_data_in[7:0];
			end
			// Let register grab data off the wishbone bus
			data_in_write_stb <= wb_stb_in && wb_cyc_in && wb_we_in && !wb_stall_out && (wb_addr_in == DATA_ADDRESS);
			status_in_write_stb <= wb_stb_in && wb_cyc_in && wb_we_in && !wb_stall_out && (wb_addr_in == STATUS_ADDRESS);

			// Check for wishbone reads

			if (wb_stb_in && wb_cyc_in && !wb_we_in && !wb_stall_out) begin
				case (wb_addr_in)
					Z80_ADDRESS: begin
						wb_data_out <= {24'b0, z80_base_address};
					end
					DATA_ADDRESS: begin
						wb_data_out <= {24'b0, data_out_contents};
						irq_data_out <= 1'b0;
					end
					STATUS_ADDRESS: begin
						wb_data_out <= {24'b0, status_out_contents};
						irq_status_out <= 1'b0;
					end
				endcase
			end

			// Always ack wishbone bus immediately
			wb_ack_out <= (wb_stb_in && !wb_stall_out && ((wb_addr_in == Z80_ADDRESS) || (wb_addr_in == DATA_ADDRESS) || (wb_addr_in == STATUS_ADDRESS)));

		end
	end

	// Only drive the Z80 bus when we're not in reset, and there's an active strobe, and it's one of our addresses
	assign z80_bus_dir = data_out_ready;

endmodule
`default_nettype wire

// End of file
