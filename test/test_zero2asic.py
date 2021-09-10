"""
# Test Bench for JGP's Zero2ASIC project

This is the test bench for `zero2asic` module in `src/zero2asic.v`.
"""

__author__ = "Jonathan 'theJPster' Pallant"
__licence__ = "Apache 2.0"
__copyright__ = "Copyright 2021, Jonathan 'theJPster' Pallant"

import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

clocks_per_phase = 10

async def reset(dut):
    """
    Reset the dut (device under test - our verilog module)
    """
    dut.clk <= 0
    dut.reg1_cs_b <= 1
    dut.reg2_cs_b <= 1
    dut.write_strobe_b <= 1
    dut.read_strobe_b <= 1
    dut.data_bus <= 0x00

    dut.reset_b <= 0
    await ClockCycles(dut.clk, 5)
    dut.reset_b <= 1;
    await ClockCycles(dut.clk, 5)

async def test_set_reg1(dut, value):
    """
    Test putting values into register 1.
    """

    dut.data_bus <= value
    dut.reg1_cs_b <= 0
    dut.write_strobe_b <= 0
    await ClockCycles(dut.clk, 2)
    dut.reg1_cs_b <= 1
    dut.write_strobe_b <= 1
    dut.data_bus <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, 1)

async def test_get_reg1(dut):
    """
    Test reading values from register 1.
    """

    dut.reg1_cs_b <= 0
    dut.read_strobe_b <= 0
    await ClockCycles(dut.clk, 3)
    value = dut.data_bus.value
    await ClockCycles(dut.clk, 2)
    dut.reg1_cs_b <= 1
    dut.read_strobe_b <= 1
    await ClockCycles(dut.clk, 1)
    return value

async def test_set_reg2(dut, value):
    """
    Test putting values into register 2.
    """

    dut.data_bus <= value
    dut.reg2_cs_b <= 0
    dut.write_strobe_b <= 0
    await ClockCycles(dut.clk, 2)
    dut.reg2_cs_b <= 1
    dut.write_strobe_b <= 1
    dut.data_bus <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, 1)

async def test_get_reg2(dut):
    """
    Test reading values from register 2.
    """

    dut.reg2_cs_b <= 0
    dut.read_strobe_b <= 0
    await ClockCycles(dut.clk, 3)
    value = dut.data_bus.value
    await ClockCycles(dut.clk, 2)
    dut.reg2_cs_b <= 1
    dut.read_strobe_b <= 1
    await ClockCycles(dut.clk, 1)
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

    await test_set_reg1(dut, 0x10)
    assert await test_get_reg1(dut) == 0x10
    assert await test_get_reg2(dut) == 0x00

    await test_set_reg2(dut, 0xFF)
    assert await test_get_reg1(dut) == 0x10
    assert await test_get_reg2(dut) == 0xFF

    await test_set_reg1(dut, 0x01)
    assert await test_get_reg1(dut) == 0x01
    assert await test_get_reg2(dut) == 0xFF

    await test_set_reg2(dut, 0x55)
    assert await test_get_reg1(dut) == 0x01
    assert await test_get_reg2(dut) == 0x55

# End of file
