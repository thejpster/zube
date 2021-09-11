# theJPster's Zero to ASIC Entry

My entry for MPW2 on the Zero to ASIC Training Course.

Currently we have two 8-bit registers on an 8-bit data bus. There are read/write strobes (active on the falling edge), and an address bus which we decode to get the chip selects. This should be suitable for use on an 8080/Z80 bus, with appropriate level shifters.

* The top level module is zero2asic, `src/zero2asic.v`
* The cocotb tests are in `test/test_zero2asic.v`
* You can run the cocotb tests with `./test.sh`
* You can harden using openLANE with `./harden.sh`
* You can load `zero2asic.qpf` in Quartus Studio

