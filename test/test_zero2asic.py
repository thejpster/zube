import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

clocks_per_phase = 10

async def reset(dut):

    dut.clk <= 0
    dut.cs <= 0
    dut.data_in <= 0
    dut.reset <= 1

    await ClockCycles(dut.clk, 5)
    dut.reset <= 0;
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_all(dut):
    clock = Clock(dut.clk, 10, units="us")

    cocotb.fork(clock.start())

    await reset(dut)
    assert dut.clk == 0
    assert dut.reset == 0
    assert dut.cs == 0
    assert dut.data_in == 0

    # output should be low at start
    assert dut.data_out == 0
