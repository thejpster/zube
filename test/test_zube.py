"""
# Test Bench for JGP's Zero2ASIC project

This is the test bench for `zube` module in `src/zube.v`.
"""

__author__ = "Jonathan 'theJPster' Pallant"
__licence__ = "Apache 2.0"
__copyright__ = "Copyright 2021, Jonathan 'theJPster' Pallant"

import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotbext.wishbone.driver import WishboneMaster, WBOp
import random

HIGHSPEED_CLOCK = 50000000
LOWSPEED_CLOCK = 8000000
FAST_CLOCKS_PER_SLOW_CLOCK = HIGHSPEED_CLOCK // LOWSPEED_CLOCK

async def reset(dut):
    """
    Reset the dut (device under test - our verilog module)
    """

    # Defaults for all input signals
    dut.clk <= 0
    dut.z80_address_bus <= 0x0000
    dut.z80_write_strobe_b <= 1
    dut.z80_read_strobe_b <= 1
    dut.z80_data_bus_in <= BinaryValue("zzzzzzzz")

    # Strobe the reset line
    dut.reset_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)
    dut.reset_b <= 1;
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)

async def test_wb_set(wbs, addr, value):
    """
    Test putting values into the given wishbone address.
    """
    await wbs.send_cycle([WBOp(addr, value)])

async def test_wb_get(wbs, addr):
    """
    Test getting values from the given wishbone address.
    """
    res_list = await wbs.send_cycle([WBOp(addr)])
    rvalues = [entry.datrd for entry in res_list]
    return rvalues[0]

async def test_z80_set(dut, addr, value):
    """
    Test putting values into the given address.
    """

    dut.z80_address_bus <= addr
    dut.z80_data_bus_in <= value
    dut.z80_write_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.z80_write_strobe_b <= 1
    dut.z80_data_bus_in <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)

async def test_z80_get(dut, addr):
    """
    Test getting values from the given address.
    """

    dut.z80_address_bus <= addr
    dut.z80_read_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    value = dut.z80_data_bus_out.value
    assert dut.z80_bus_dir == 1
    dut.z80_read_strobe_b <= 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    assert dut.z80_bus_dir == 0
    return value

@cocotb.test()
async def test_all(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.clk, 10, units="us")

    cocotb.fork(clock.start())

    signals_dict = {
        "cyc":  "cyc_in",
        "stb":  "stb_in",
        "we":   "we_in",
        "adr":  "addr_in",
        "datwr":"data_in",
        "datrd":"data_out",
        "ack":  "ack_out"
    }
    wbs = WishboneMaster(dut, "wb", dut.clk, width=32, timeout=10, signals_dict=signals_dict)

    await reset(dut)

    # Set up our memory addresses for both sides
    wb_z80base_addr = 0x3000_0000
    wb_data_addr = 0x3000_0004
    wb_status_addr = 0x3000_0008

    z80_data_addr = await test_wb_get(wbs, wb_z80base_addr)
    z80_status_addr = z80_data_addr + 1

    # Check we can read/write registers

    # Drive registers from the Z80 side
    await test_z80_set(dut, z80_data_addr, 0x10)
    assert await test_wb_get(wbs, wb_data_addr) == 0x10
    assert await test_wb_get(wbs, wb_status_addr) == 0x00

    await test_z80_set(dut, z80_status_addr, 0xFF)
    assert await test_wb_get(wbs, wb_data_addr) == 0x10
    assert await test_wb_get(wbs, wb_status_addr) == 0xFF

    await test_z80_set(dut, z80_data_addr, 0x01)
    assert await test_wb_get(wbs, wb_data_addr) == 0x01
    assert await test_wb_get(wbs, wb_status_addr) == 0xFF

    await test_z80_set(dut, z80_status_addr, 0x55)
    assert await test_wb_get(wbs, wb_data_addr) == 0x01
    assert await test_wb_get(wbs, wb_status_addr) == 0x55

    # Read some registers from the Z80 side
    assert await test_z80_get(dut, z80_data_addr) == 0x00
    assert await test_z80_get(dut, z80_status_addr) == 0x00

    await test_wb_set(wbs, wb_data_addr, 0x55)
    assert await test_z80_get(dut, z80_data_addr) == 0x55
    assert await test_z80_get(dut, z80_status_addr) == 0x00

    await test_wb_set(wbs, wb_status_addr, 0xAA)
    assert await test_z80_get(dut, z80_data_addr) == 0x55
    assert await test_z80_get(dut, z80_status_addr) == 0xAA

    await test_wb_set(wbs, wb_data_addr, 0x00)
    assert await test_z80_get(dut, z80_data_addr) == 0x00
    assert await test_z80_get(dut, z80_status_addr) == 0xAA

    await test_wb_set(wbs, wb_status_addr, 0xFF)
    assert await test_z80_get(dut, z80_data_addr) == 0x00
    assert await test_z80_get(dut, z80_status_addr) == 0xFF

# End of file
