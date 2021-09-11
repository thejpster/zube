# theJPster's Zero to ASIC Entry

My entry for MPW2 on the Zero to ASIC Training Course.

Currently we have two 8-bit registers on an 8-bit data bus. There are read/write strobes (active on the falling edge), and a chip select pin for each register - suitable for us on an 8080 bus with external address decoding.

* The top level module is zero2asic, `src/zero2asic.v`
* The cocotb tests are in `test/test_zero2asic.v`
* You can run the cocotb tests with `./test.sh`
* You can harden using openLANE with `./harden.sh`
