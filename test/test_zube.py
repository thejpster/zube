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
    dut.z80_ioreq_b <= 1
    dut.z80_m1 <= 1
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
    dut.z80_ioreq_b <= 0
    dut.z80_write_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.z80_ioreq_b <= 1
    dut.z80_write_strobe_b <= 1
    dut.z80_data_bus_in <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)

async def test_z80_get(dut, addr):
    """
    Test getting values from the given address.
    """

    dut.z80_address_bus <= addr
    dut.z80_ioreq_b <= 0
    dut.z80_read_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    value = dut.z80_data_bus_out.value
    bus_dir = dut.z80_bus_dir
    assert bus_dir == 1, f"bus_dir should be 1, was {bus_dir}"
    dut.z80_ioreq_b <= 1
    dut.z80_read_strobe_b <= 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    bus_dir = dut.z80_bus_dir
    assert bus_dir == 0, f"bus_dir should be 0, was {bus_dir}"
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
    wb_control_addr = 0x3000_0008
    wb_status_addr = 0x3000_000C

    z80_data_addr = await test_wb_get(wbs, wb_z80base_addr)
    z80_control_addr = z80_data_addr + 1
    z80_status_addr = z80_data_addr + 2

    # Check we can read/write registers

    # Drive the data register from the Z80 side
    await test_z80_set(dut, z80_data_addr, 0x10)
    # Is it flagged as written?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x01, f"status was {status}, not 0x01"
    # Can we get the contents?
    data = await test_wb_get(wbs, wb_data_addr)
    assert data == 0x10, f"data was {data}, not 0x10"
    # Is the other register still empty?
    control = await test_wb_get(wbs, wb_control_addr)
    assert control == 0x00, f"control was {control}, not 0x00"
    # Have the flags gone?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"

    # Drive the control register from the Z80 side
    await test_z80_set(dut, z80_control_addr, 0x55)
    # Is it flagged as written?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x02, f"status was {status}, not 0x02"
    # Can we get the contents?
    control = await test_wb_get(wbs, wb_control_addr)
    assert control == 0x55, f"control was {control}, not 0x55"
    # Is the other register still the same?
    data = await test_wb_get(wbs, wb_data_addr)
    assert data == 0x10, f"data was {data}, not 0x10"
    # Have the flags gone now?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"

    # Drive both registers from the Z80 side
    await test_z80_set(dut, z80_data_addr, 0xF0)
    await test_z80_set(dut, z80_control_addr, 0xAA)
    # Are they flagged as written?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x03, f"status was {status}, not 0x03"
    # Can we get the contents?
    data = await test_wb_get(wbs, wb_data_addr)
    assert data == 0xF0, f"data was {data}, not 0xF0"
    control = await test_wb_get(wbs, wb_control_addr)
    assert control == 0xAA, f"control was {control}, not 0xAA"
    # Have the flags gone now?
    status = await test_wb_get(wbs, wb_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"

    # Drive a register from the WB side
    await test_wb_set(wbs, wb_data_addr, 0x10)
    # Is it flagged as written?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x04, f"status was {status}, not 0x04"
    # Can we get the contents?
    data = await test_z80_get(dut, z80_data_addr)
    assert data == 0x10, f"data was {data}, not 0x10"
    # Is the other register still empty?
    control = await test_z80_get(dut, z80_control_addr)
    assert control == 0x00, f"control was {control}, not 0x00"
    # Have the flags gone?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"

    # Drive the other register from the WB side
    await test_wb_set(wbs, wb_control_addr, 0x84)
    # Is it flagged as written?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x08, f"status was {status}, not 0x08"
    # Can we get the contents?
    control = await test_z80_get(dut, z80_control_addr)
    assert control == 0x84, f"control was {control}, not 0x84"
    # Is the other register still the same?
    data = await test_z80_get(dut, z80_data_addr)
    assert data == 0x10, f"data was {data}, not 0x10"
    # Have the flags gone?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"


    # Drive both registers from the WB side
    await test_wb_set(wbs, wb_data_addr, 0x31)
    await test_wb_set(wbs, wb_control_addr, 0x32)
    # Are they flagged as written?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x0C, f"status was {status}, not 0x0C"
    # Can we get the contents?
    data = await test_z80_get(dut, z80_data_addr)
    assert data == 0x31, f"data was {data}, not 0x31"
    control = await test_z80_get(dut, z80_control_addr)
    assert control == 0x32, f"control was {control}, not 0x32"
    # Have the flags gone?
    status = await test_z80_get(dut, z80_status_addr)
    assert status == 0x00, f"status was {status}, not 0x00"

# End of file
