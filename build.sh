#!/usr/bin/env bash

#
# Builds zube for a Terasic DE10-Lite
#
# Copyright (c) 2021, Jonathan 'theJPster' Pallant
#
# Licence: Apache-2.0
#

set -euo pipefail

PROJECT=zube

mkdir -p fpga_build

yosys -l fpga_build/yosys.log -p "read -sv ./src/${PROJECT}.v; synth_intel -family max10 -top ${PROJECT} -vqm fpga_build/${PROJECT}.vqm -vpr fpga_build/${PROJECT}.vpr; stat" src/*.v
# TODO: I think we need Quartus here...
