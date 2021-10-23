#!/usr/bin/env bash

#
# Runs the cocotb tests on zube
#
# Copyright (c) 2021, Jonathan 'theJPster' Pallant
#
# Licence: Apache-2.0
#

set -euo pipefail

COCOTB_PREFIX=$(cocotb-config --prefix)

export COCOTB_REDUCED_LOG_FMT=1
export PYTHONPATH=test:${PYTHONPATH:-}

rm -rf sim_build
mkdir -p sim_build

# Build and test top-level `zube` module
iverilog -o sim_build/sim.vvp -s zube -s dump -g2012 src/zube.v src/data_register.v test/dump_zube.v
MODULE=test.test_zube vvp -M ${COCOTB_PREFIX}/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
! grep failure results.xml

# Build and test `data_register`
iverilog -o sim_build/sim.vvp -s data_register -s dump -g2012 src/data_register.v test/dump_data_register.v
MODULE=test.test_data_register vvp -M ${COCOTB_PREFIX}/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
! grep failure results.xml

echo Finished

# End of file
