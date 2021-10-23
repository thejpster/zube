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
	parameter   [31:0]  CONTROL_ADDRESS = BASE_ADDRESS + 8,
	parameter   [31:0]  STATUS_ADDRESS  = BASE_ADDRESS + 12
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
	// goes low when this is an I/O access
	input wire z80_ioreq_b,
	// goes high for valid IOREQ, low for INTACK (which we ignore)
	input wire z80_m1,
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
	// outgoing data
	output reg [31:0] wb_data_out,

	// IRQ to ASIC when registers are read/written.
	output reg irq_out

	// Note: There is no support for interrupts on the Z80 side!
	);

	// Buffered data bus. Sampled with the high speed clock.
	reg[7:0] sync_z80_data_bus_in;

	// Buffered address bus. Sampled with the high speed clock.
	reg[7:0] sync_z80_address_bus;

	// A Z80 I/O Read Strobe, synched to the high-speed clock
	reg sync_io_read;
	// sync_io_read but delayed
	reg sync_io_read_delayed;
	// A Z80 I/O Write Strobe, synched to the high-speed clock
	reg sync_io_write;
	// sync_io_write but delayed
	reg sync_io_write_delayed;

	// A WB Read Strobe, synched to the high-speed clock
	wire wb_read;
	// A WB Write Strobe, synched to the high-speed clock
	wire wb_write;

	// Notes when OUT registers have data in them
	reg data_out_ready;
	reg control_out_ready;

	// Records when we are driving the Z80 data bus. Also used to ensure the
	// value we drive on to the data bus is sampled on the first falling edge
	// of IOREQ and doesn't subsequently change (even if we get a wishbone
	// write in the next cycle).
	reg data_bus_driven;

	// Z80 I/O base address. We listen to this address for *Data*, and the
	// next one for *Control* and the one after for *Status*. Can be set over
	// the Wishbone bus.
	reg[7:0] z80_base_address;

	// What's in the Data Out Register
	wire[7:0] data_out_contents;

	// What's in the Data In Register
	wire[7:0] data_in_contents;

	// What's in the Control In Register
	wire[7:0] control_in_contents;

	// What's in the Control Out Register
	wire[7:0] control_out_contents;

	// Do our four registers have any data in them?
	wire [3:0] ready_signals;

	assign wb_read = wb_stb_in && wb_cyc_in && ~wb_we_in;
	assign wb_write = wb_stb_in && wb_cyc_in && wb_we_in;

	// Z80 to ASIC
	data_register data_out(
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(sync_io_write && (sync_z80_address_bus == z80_base_address)),
		.read_strobe(wb_read && (wb_addr_in == DATA_ADDRESS)),
		.data_in(sync_z80_data_bus_in),
		.data_out(data_out_contents),
		.ready(ready_signals[0])
	);

	data_register control_out(
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(sync_io_write && (sync_z80_address_bus == (z80_base_address + 1))),
		.read_strobe(wb_read && (wb_addr_in == CONTROL_ADDRESS)),
		.data_in(sync_z80_data_bus_in),
		.data_out(control_out_contents),
		.ready(ready_signals[1])
	);

	// ASIC to Z80
	data_register data_in(
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(wb_write && (wb_addr_in == DATA_ADDRESS)),
		.read_strobe(sync_io_read && (sync_z80_address_bus == z80_base_address)),
		.data_in(wb_data_in[7:0]),
		.data_out(data_in_contents),
		.ready(ready_signals[2])
	);

	data_register control_in(
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(wb_write && (wb_addr_in == CONTROL_ADDRESS)),
		.read_strobe(sync_io_read && (sync_z80_address_bus == (z80_base_address + 1))),
		.data_in(wb_data_in[7:0]),
		.data_out(control_in_contents),
		.ready(ready_signals[3])
	);

	always @(posedge clk) begin
		if (~reset_b) begin
			// Reset state here
			data_bus_driven <= 0;
			sync_z80_data_bus_in <= 0;
			sync_z80_address_bus <= 0;
			sync_io_read <= 0;
			sync_io_read_delayed <= 0;
			sync_io_write <= 0;
			sync_io_read_delayed <= 0;
			irq_out <= 0;
			z80_data_bus_out <= 8'h00;
			z80_base_address = 16'h80;
		end else begin
			// Sample slow incoming signals with our high speed clock
			// Helps avoid metastability, by keeping everything ticking along with the high speed clock
			sync_z80_data_bus_in <= z80_data_bus_in;
			sync_z80_address_bus <= z80_address_bus;
			sync_io_read <= z80_m1 && ~z80_ioreq_b && ~z80_read_strobe_b;
			sync_io_write <= z80_m1 && ~z80_ioreq_b && ~z80_write_strobe_b;
			sync_io_read_delayed <= sync_io_read;
			sync_io_write_delayed <= sync_io_write;

			// Check for Z80 reads/writes - everything here should use the
			// sync signals, not the async signals.

			if ((sync_z80_address_bus == z80_base_address) && sync_io_write && ~sync_io_write_delayed) begin
				// Fresh Z80 write
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address + 1) && sync_io_write && ~sync_io_write_delayed) begin
				// Fresh Z80 write
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address) && sync_io_read && ~data_bus_driven) begin
				// The Z80 is reading from Data IN
				data_bus_driven <= 1;
				z80_data_bus_out <= data_in_contents;
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address + 1) && sync_io_read && ~data_bus_driven) begin
				// The Z80 is reading from Control IN
				data_bus_driven <= 1;
				z80_data_bus_out <= control_in_contents;
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address + 2) && sync_io_read && ~data_bus_driven) begin
				// The Z80 is reading from Status
				data_bus_driven <= 1;
				z80_data_bus_out <= {4'h0, ready_signals};
			end else begin
				// IRQ is just a single cycle
				irq_out <= 0;
				// Are we done with the bus?
				if (data_bus_driven && ~sync_io_read) begin
					// Read strobe released - we can no longer drive the bus
					data_bus_driven <= 0;
				end
			end

			// Check for wishbone reads/writes

			// Write Z80 base address
			if (wb_write && wb_addr_in == Z80_ADDRESS) begin
				z80_base_address <= wb_data_in[7:0];
			end

			// Check for wishbone reads

			if (wb_read) begin
				case (wb_addr_in)
					Z80_ADDRESS: begin
						wb_data_out <= {24'b0, z80_base_address};
					end
					DATA_ADDRESS: begin
						wb_data_out <= {24'b0, data_out_contents};
					end
					CONTROL_ADDRESS: begin
						wb_data_out <= {24'b0, control_out_contents};
					end
					STATUS_ADDRESS: begin
						wb_data_out <= {28'b0, ready_signals};
					end
				endcase
			end

			// Always ack wishbone bus immediately
			wb_ack_out <= (wb_stb_in && ((wb_addr_in == Z80_ADDRESS) || (wb_addr_in == DATA_ADDRESS) || (wb_addr_in == CONTROL_ADDRESS) || (wb_addr_in == STATUS_ADDRESS)));

		end
	end

	// Tell the external buffer when we want to drive the bus
	assign z80_bus_dir = data_bus_driven && ~z80_read_strobe_b;

endmodule
`default_nettype wire

// End of file
