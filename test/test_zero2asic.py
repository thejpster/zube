"""
# Test Bench for JGP's Zero2ASIC project

This is the test bench for `zero2asic` module in `src/zero2asic.v`.
"""

__author__ = "Jonathan 'theJPster' Pallant"
__licence__ = "Apache 2.0"
__copyright__ = "Copyright 2021, Jonathan 'theJPster' Pallant"

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

clocks_per_phase = 10

async def reset(dut):
    """
    Reset the dut (device under test - our verilog module)
    """
    dut.clk <= 0
    dut.cs <= 0
    dut.data_in <= 0
    dut.reset <= 1

    await ClockCycles(dut.clk, 5)
    dut.reset <= 0;
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_all(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.clk, 10, units="us")

    cocotb.fork(clock.start())

    await reset(dut)
    assert dut.reset == 0
    assert dut.cs == 0
    assert dut.data_in == 0

    # output should be low at start
    assert dut.data_out == 0
