#!/bin/sh

PROJECT=zero2asic

COCOTB_PREFIX=$(cocotb-config --prefix)

export COCOTB_REDUCED_LOG_FMT=1
export PYTHONPATH=test:${PYTHONPATH}

rm -rf sim_build
mkdir -p sim_build
iverilog -o sim_build/sim.vvp -s ${PROJECT} -s dump -g2012 src/${PROJECT}.v test/dump_${PROJECT}.v
MODULE=test.test_${PROJECT} vvp -M ${COCOTB_PREFIX}/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
! grep failure results.xml
