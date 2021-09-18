# theJPster's Zero to ASIC Entry

My entry for MPW3 on the Zero to ASIC Training Course.

This project is an 8080/Z80 peripheral bus interface. It is designed to 
connect to the 8080 bus, e.g. as available in the RC2040 microcomputer, 
ZX Spectrum, etc.

It is designed to be fully-flexible so it can be used for all kinds of 
projects. Given the right firmware on the SoC's PicoRV32 core I imagine you
can implement:

* A UART (using the SoC's UART peripheral)
* A maths accelerator (the RV32IMC has a 32-bit hardware multiplier)
* An SD Card interface (using the housekeeping SPI)
* A GPIO interface

It works like this:

* The PicoRV32 sets the "start address" and "end address".
* The SoC sits on the 8080 16-bit address bus and 8-bit data bus.
* When a write occurs in the given range:
    * the 8-bit register address is latched
    * the 8 bit data is latched
    * an IRQ is raised on the PicoRV32
* When a read occurs in the given range:
    * the 8-bit register address is latched
    * the wait-state pin is set
    * an IRQ is raised on the PicoRV32
    * the PicoRV32 can write back an 8-bit value
    * the wait-state pin is cleared

Only I/O writes are supported - it doesn't make sense to emulate memory
as the address range is so limited.

## 8080 bus

We need 22 pins to sit on the 8080 bus.

### Inputs

* `A[7..0]`: Address Bus (8-bits)
* `RD`: Read Strobe
* `WR`: Write Strobe
* `IORQ`: I/O Request Strobe
* `M1`: 8080 state (must be high)

This is 12 pins.

### Input/Outputs

* `D[7..0]`: Data Bus Input (8-bits)

This is 8 pins.

### Outputs

* `OEB`: Data Bus Output Enable
* `WAIT`: Wait State Enable

This is 2 pins.

### Interfacing

You will require a bi-directional bus driver to interface with the 5V 
bus from a 1.8V (or similar) SoC. When `OEB` is high, `D[7..0]` should 
be drive on to the data bus.

## Code Layout

* The top level module is zubetop, `src/zube_top.v`
* The 8080 bus interface is in `src/busif.v`
* The cocotb tests are in `test/test_busif.v`
* You can run the cocotb tests with `./test.sh`
* You can harden using openLANE with `./harden.sh`

## Wrapper

This project sits inside the zube project's Multi Project 
Environment. This wraps multiple projects together into one entry onto MPW3.

Every entry submitted to MPW3 has:

* A top module called `user_project_wrapper`
* A 32-bit Wishbone slave port
* A 128-bit logic analyser (in/out/enable)
* 38 GPIO pins (in/out/enable)
* An "independent" clock
* Two IRQs
