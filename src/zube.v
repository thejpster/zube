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

	// IRQ to ASIC when FIFOs are read/written on the Z80 side.
	output reg irq_out

	// Note: There is no support for interrupts to the Z80!
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
	reg wb_old_read;
	assign wb_read = wb_stb_in && wb_cyc_in && ~wb_we_in;

	// A WB Write Strobe, synched to the high-speed clock
	wire wb_write;
	reg wb_old_write;
	assign wb_write = wb_stb_in && wb_cyc_in && wb_we_in;

	// Records when we are driving the Z80 data bus. Also used to ensure the
	// value we drive on to the data bus is sampled on the first falling edge
	// of IOREQ and doesn't subsequently change (even if we get a wishbone
	// write in the next cycle).
	reg data_bus_driven;

	// Z80 I/O base address. Our three Z80 I/O addresses are consecutive, and
	// start with this value. Can by set over Wishbone by writing to
	// the address `Z80_ADDRESS`.
	reg[7:0] z80_base_address;

	// Give our four mailboxes a number

	// Data OUT (Z80 to ASIC box #1)
	localparam REG_DATA_OUT = 0;

	// Control OUT (Z80 to ASIC box #2)
	localparam REG_CONTROL_OUT = 1;

	// Data IN (ASIC to Z80 to box #1)
	localparam REG_DATA_IN = 2;

	// Control IN (ASIC to Z80 to box #2)
	localparam REG_CONTROL_IN = 3;

	// What's in the four FIFOs
	wire [7:0] contents [3:0];

	// Do our four FIFOs have any data in them?
	wire [3:0] ready_signals;

	// Are our four FIFOs full?
	wire [3:0] full_signals;

	// Z80 to ASIC
	data_register #(.DEPTH_BITS(5)) data_out (
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(sync_io_write && (sync_z80_address_bus == z80_base_address)),
		.read_strobe(wb_read && (wb_addr_in == DATA_ADDRESS)),
		.data_in(sync_z80_data_bus_in),
		.data_out(contents[REG_DATA_OUT]),
		.not_empty(ready_signals[REG_DATA_OUT]),
		.full(full_signals[REG_DATA_OUT])
	);

	data_register #(.DEPTH_BITS(3)) control_out (
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(sync_io_write && (sync_z80_address_bus == (z80_base_address + 1))),
		.read_strobe(wb_read && (wb_addr_in == CONTROL_ADDRESS)),
		.data_in(sync_z80_data_bus_in),
		.data_out(contents[REG_CONTROL_OUT]),
		.not_empty(ready_signals[REG_CONTROL_OUT]),
		.full(full_signals[REG_CONTROL_OUT])
	);

	// ASIC to Z80
	data_register #(.DEPTH_BITS(5)) data_in (
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(wb_write && (wb_addr_in == DATA_ADDRESS)),
		.read_strobe(sync_io_read && (sync_z80_address_bus == z80_base_address)),
		.data_in(wb_data_in[7:0]),
		.data_out(contents[REG_DATA_IN]),
		.not_empty(ready_signals[REG_DATA_IN]),
		.full(full_signals[REG_DATA_IN])
	);

	data_register #(.DEPTH_BITS(3)) control_in (
		.clk(clk),
		.reset(~reset_b),
		.write_strobe(wb_write && (wb_addr_in == CONTROL_ADDRESS)),
		.read_strobe(sync_io_read && (sync_z80_address_bus == (z80_base_address + 1))),
		.data_in(wb_data_in[7:0]),
		.data_out(contents[REG_CONTROL_IN]),
		.not_empty(ready_signals[REG_CONTROL_IN]),
		.full(full_signals[REG_CONTROL_IN])
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
			wb_old_read <= 0;
			wb_old_write <= 0;
		end else begin
			// Sample slow incoming signals with our high speed clock
			// Helps avoid metastability, by keeping everything ticking along with the high speed clock
			sync_z80_data_bus_in <= z80_data_bus_in;
			sync_z80_address_bus <= z80_address_bus;
			sync_io_read <= z80_m1 && ~z80_ioreq_b && ~z80_read_strobe_b;
			sync_io_write <= z80_m1 && ~z80_ioreq_b && ~z80_write_strobe_b;
			sync_io_read_delayed <= sync_io_read;
			sync_io_write_delayed <= sync_io_write;
			wb_old_read <= wb_read;
			wb_old_write <= wb_write;

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
				z80_data_bus_out <= contents[REG_DATA_IN];
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address + 1) && sync_io_read && ~data_bus_driven) begin
				// The Z80 is reading from Control IN
				data_bus_driven <= 1;
				z80_data_bus_out <= contents[REG_CONTROL_IN];
				irq_out <= 1;
			end else if ((sync_z80_address_bus == z80_base_address + 2) && sync_io_read && ~data_bus_driven) begin
				// The Z80 is reading from Status
				data_bus_driven <= 1;
				z80_data_bus_out <= {full_signals, ready_signals};
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
			if (wb_write && ~wb_old_write && wb_addr_in == Z80_ADDRESS) begin
				z80_base_address <= wb_data_in[7:0];
			end

			// Check for wishbone reads

			if (wb_read && ~wb_old_read) begin
				case (wb_addr_in)
					Z80_ADDRESS: begin
						wb_data_out <= {24'b0, z80_base_address};
					end
					DATA_ADDRESS: begin
						wb_data_out <= {24'b0, contents[REG_DATA_OUT]};
					end
					CONTROL_ADDRESS: begin
						wb_data_out <= {24'b0, contents[REG_CONTROL_OUT]};
					end
					STATUS_ADDRESS: begin
						wb_data_out <= {24'b0, full_signals, ready_signals};
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
