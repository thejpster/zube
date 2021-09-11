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

    # Defaults for all input signals
    dut.clk <= 0
    dut.address_bus <= 0x0000
    dut.write_strobe_b <= 1
    dut.read_strobe_b <= 1
    dut.data_bus <= 0x00

    # Strobe the reset line
    dut.reset_b <= 0
    await ClockCycles(dut.clk, 5)
    dut.reset_b <= 1;
    await ClockCycles(dut.clk, 5)

async def test_set_reg(dut, addr, value):
    """
    Test putting values into the given address.
    """

    dut.address_bus <= addr
    dut.data_bus <= value
    dut.write_strobe_b <= 0
    await ClockCycles(dut.clk, 2)
    dut.write_strobe_b <= 1
    dut.data_bus <= BinaryValue("zzzzzzzz")
    await ClockCycles(dut.clk, 1)

async def test_get_reg(dut, addr):
    """
    Test reading values from the given address.
    """

    dut.address_bus <= addr
    dut.read_strobe_b <= 0
    await ClockCycles(dut.clk, 3)
    value = dut.data_bus.value
    await ClockCycles(dut.clk, 1)
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
