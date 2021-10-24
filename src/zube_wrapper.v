/*
 * Zero 2 ASIC submission, by Jonathan Pallant.
 *
 * Copyright (c) 2021 Jonathan 'theJPster' Pallant
 *
 * Licence: Apache-2.0
 *
 * This is a wrapper for `zube`, so that it fits neatly into the
 * `user_project_wrapper.v` of caravel. In particular,
 * we have to flip eight `~Output Enable (OEB)` bits according to
 * the value of `z80_bus_dir`, as `user_project_wrapper.v` cannot contain
 * anything synthesisable.
 */

`default_nettype none
module zube_wrapper #(
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
    inout vdda1,    // User area 1 3.3V supply
    inout vdda2,    // User area 2 3.3V supply
    inout vssa1,    // User area 1 analog ground
    inout vssa2,    // User area 2 analog ground
    inout vccd1,    // User area 1 1.8V supply
    inout vccd2,    // User area 2 1.8v supply
    inout vssd1,    // User area 1 digital ground
    inout vssd2,    // User area 2 digital ground
`endif

    /**
     * Clock and Reset
     */

    // High speed (wishbone) clock
    input wire clk,

    // Goes low when module is in reset
    input wire reset_b,

    /**
     * GPIO
     */

    // Input
    input wire[27:0] io_in,
    `ifdef FORMAL
    // Output
    output wire[27:0] io_out,
    // ~Output Enable
    output wire[27:0] io_oeb,
    `else
    // Output
    inout wire[27:0] io_out,
    // ~Output Enable
    inout wire[27:0] io_oeb,
    `endif

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
    output wire wb_ack_out,
    // outgoing data
    output wire [31:0] wb_data_out,

    // IRQ to SoC when registers have been written or read.
    output wire irq_out

    // Note: There is no support for interrupts on the Z80 side!
    );

    zube zube0 (
`ifdef USE_POWER_PINS
        .vdda1(vdda1),  // User area 1 3.3V power
        .vdda2(vdda2),  // User area 2 3.3V power
        .vssa1(vssa1),  // User area 1 analog ground
        .vssa2(vssa2),  // User area 2 analog ground
        .vccd1(vccd1),  // User area 1 1.8V power
        .vccd2(vccd2),  // User area 2 1.8V power
        .vssd1(vssd1),  // User area 1 digital ground
        .vssd2(vssd2),  // User area 2 digital ground
`endif

        .clk(clk),
        .reset_b(reset_b),
        .z80_address_bus(io_in[7:0]),
        .z80_data_bus_in(io_in[15:8]),
        .z80_data_bus_out(io_out[15:8]),
        .z80_bus_dir(io_out[16]),
        .z80_read_strobe_b(io_in[17]),
        .z80_write_strobe_b(io_in[18]),
        .z80_m1(io_in[19]),
        .z80_ioreq_b(io_in[20]),
        .wb_cyc_in(wb_cyc_in),
        .wb_stb_in(wb_stb_in),
        .wb_we_in(wb_we_in),
        .wb_addr_in(wb_addr_in),
        .wb_data_in(wb_data_in),
        .wb_ack_out(wb_ack_out),
        .wb_data_out(wb_data_out),
        .irq_out(irq_out)
    );

    // Z80 Address bus
    assign io_oeb[7:0] = 8'hFF;
    // Z80 Data bus
    assign io_oeb[15:8] = io_out[16] ? 8'h00 : 8'hFF;
    // Z80 Control pins
    assign io_oeb[20:16] = 5'b11110;
    // Set unused outputs low
    assign io_out[7:0] = 8'b0;
    assign io_out[27:21] = 7'b0;

endmodule
`default_nettype wire
