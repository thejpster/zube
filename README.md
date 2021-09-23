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

## Functionality

The SoC exposes two I/O addresses on the Z80 bus - DATA and STATUS. These
correspond to two outbound mailboxes, and two inbound mailboxes.

| Address      | Direction | Register   |
|:-------------|:----------|:-----------|
| Z80_BASE     | Write     | Data OUT   |
| Z80_BASE     | Read      | Data IN    |
| Z80_BASE + 1 | Write     | Status OUT |
| Z80_BASE + 1 | Read      | Status IN  |

The term *OUT* means Z80-to-SoC. The term *IN* means SoC-to-Z80.

The SoC also sits on two addresses on the Wishbone bus:

| Address       | Direction | Register   |
|:--------------|:----------|:-----------|
| WISH_BASE     | Write     | Data IN    |
| WISH_BASE     | Read      | Data OUT   |
| WISH_BASE + 1 | Write     | Status IN  |
| WISH_BASE + 1 | Read      | Status OUT |

* The PicoRV32 sets the 16-bit "start address" for the two Z80 registers (the wishbone address is fixed).
* The SoC sits on the 8080 16-bit address bus and 8-bit data bus.
* When a Z80 write occurs to a mailbox:
    * the 8 bit data is latched
    * an IRQ is raised on the PicoRV32, which can then read the mailbox
* When a Z80 read occurs on a mailbox:
    * The contents of the register is provided
    * an IRQ is raised on the PicoRV32, which can then write to the mailbox again

The meaning of the bits in the "Status OUT" and "Status IN" registers is defined by firmware on the PicoRV32.

## Example

Here's an example of some (mythical) UART firmware for the PicoRV32:

```
Z80: Write 0x01 to Status OUT  -- Tell SoC to enable UART mode
SoC: Read 0x01 from Status OUT -- Enable UART mode
Z80: Write 0x65 to Data OUT    -- Send '0x65' to SoC
SoC: Read 0x65 from Data OUT   -- SoC copies value to UART peripheral
Z80: Read 0x00 from Status     -- No UART data ready
Z80: Read 0x00 from Status     -- No UART data ready
SoC: Write 0x20 to Data IN     -- Store UART data received
SoC: Write 0x01 to Status IN   -- Note UART data ready
Z80: Read 0x01 from Status IN  -- See that UART data ready
Z80: Read 0x20 from Data IN    -- Read data received from UART
SoC: Write 0x00 to Status IN   -- Note no more UART data ready
Z80: Read 0x00 from Status IN  -- See that no more UART data ready
```

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
