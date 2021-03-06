"""
# Test Bench for JGP's Zero2ASIC project

This is the test bench for `data_register` module in `src/data_register.v`.
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
    dut.write_strobe <= 0
    dut.data_in <= 0x00

    # Strobe the reset line
    dut.reset <= 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)
    dut.reset <= 0;
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK * 2)

async def test_set_reg(dut, value):
    """
    Test putting values into the given register.
    """

    dut.data_in <= value
    dut.write_strobe <= 1
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.write_strobe <= 0
    dut.data_in <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)

async def test_get_reg(dut):
    """
    Test reading values from the given register.
    """

    dut.read_strobe <= 1
    value = dut.data_out.value
    await ClockCycles(dut.clk, FAST_CLOCKS_PER_SLOW_CLOCK)
    dut.read_strobe <= 0
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

    assert await test_get_reg(dut) == 0x00
    assert dut.not_empty == 0

    for x in range(0, 32):
        await test_set_reg(dut, x)
        assert dut.not_empty == 1
        assert await test_get_reg(dut) == x
        assert dut.not_empty == 0

    for x in range(0xA0, 0xAF):
        await test_set_reg(dut, x)
        assert dut.not_empty == 1
        await test_set_reg(dut, x + 1)
        assert dut.not_empty == 1
        assert await test_get_reg(dut) == x
        assert dut.not_empty == 1
        assert await test_get_reg(dut) == x + 1
        assert dut.not_empty == 0

    for x in range(0xB0, 0xB0 + dut.DEPTH.value):
        await test_set_reg(dut, x)
        assert dut.not_empty == 1
    for x in range(0xB0, 0xB0 + dut.DEPTH.value):
        assert dut.not_empty == 1
        assert await test_get_reg(dut) == x
    assert dut.not_empty == 0

# End of file
