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
    dut.address_bus <= 0x0000
    dut.write_strobe_b <= 1
    dut.read_strobe_b <= 1
    dut.data_bus_in <= 0x00

    # Strobe the reset line
    dut.reset_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)
    dut.reset_b <= 1;
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)

async def test_set_reg(dut, addr, value):
    """
    Test putting values into the given address.
    """

    dut.address_bus <= addr
    dut.data_bus_in <= value
    dut.write_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.write_strobe_b <= 1
    dut.data_bus_in <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)

async def test_get_reg(dut, addr):
    """
    Test reading values from the given address.
    """

    dut.address_bus <= addr
    dut.read_strobe_b <= 0
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    value = dut.data_bus_out.value
    assert dut.bus_dir == 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.read_strobe_b <= 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    return value

@cocotb.test()
async def test_all(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.clk, 10, units="us")

    cocotb.fork(clock.start())

    await reset(dut)

    # Check we can read/write registers
    reg1_address = dut.BASE_ADDRESS.value
    reg2_address = reg1_address + 1

    await test_set_reg(dut, reg1_address, 0x10)
    assert await test_get_reg(dut, reg1_address) == 0x10
    assert await test_get_reg(dut, reg2_address) == 0x00

    await test_set_reg(dut, reg2_address, 0xFF)
    assert await test_get_reg(dut, reg1_address) == 0x10
    assert await test_get_reg(dut, reg2_address) == 0xFF

    await test_set_reg(dut, reg1_address, 0x01)
    assert await test_get_reg(dut, reg1_address) == 0x01
    assert await test_get_reg(dut, reg2_address) == 0xFF

    await test_set_reg(dut, reg2_address, 0x55)
    assert await test_get_reg(dut, reg1_address) == 0x01
    assert await test_get_reg(dut, reg2_address) == 0x55

# End of file
