# theJPster's Zero to ASIC Entry

My entry for MPW3 on the Zero to ASIC Training Course.

This project is an 8080/Z80 peripheral bus interface. It is designed to 
connect to the 8080 bus, e.g. as available in the RC2040 microcomputer, 
ZX Spectrum, etc.

It is designed to be fully-flexible so it can be used for all kinds of 
projects. Given the right firmware on the ASIC's PicoRV32 core I imagine you
can implement:

* A UART (using the ASIC's UART peripheral)
* A maths accelerator (the RV32IMC has a 32-bit hardware multiplier)
* An SD Card interface (using the housekeeping SPI)
* A GPIO interface
* Many more useful things!

## Functionality

### Z80 Side

The ASIC exposes three I/O addresses on the Z80 bus. These let you access two
read-only FIFOs and two write-only FIFOs. There is also a *Status*
register showing the state of each FIFO.

| Address      | Direction | Register    |
|:-------------|:----------|:------------|
| Z80_BASE     | Write     | Data OUT    |
| Z80_BASE     | Read      | Data IN     |
| Z80_BASE + 1 | Write     | Control OUT |
| Z80_BASE + 1 | Read      | Control IN  |
| Z80_BASE + 2 | Read      | Status      |

The term *OUT* means Z80-to-ASIC. The term *IN* means ASIC-to-Z80. Sorry, ASIC
programmers - this is designed to make sense from the Z80 point of view.

### PicoRV32 Side

The ASIC also sits on four addresses on the Wishbone bus. These let you access
two read-only FIFOs and two write-only FIFOs. There is also a *Status*
register showing the state of each FIFO, plus a read/write register for
setting the Base I/O Address on the Z80 side.

| Address        | Direction  | Register         |
|:---------------|:-----------|:-----------------|
| WISH_BASE      | Read/Write | Z80 Base Address |
| WISH_BASE + 4  | Write      | Data IN          |
| WISH_BASE + 4  | Read       | Data OUT         |
| WISH_BASE + 8  | Write      | Control IN       |
| WISH_BASE + 8  | Read       | Control OUT      |
| WISH_BASE + 12 | Read       | Status           |

### Intended Use

* The PicoRV32 sets the 8-bit "I/O base address" for the three Z80 registers (the Wishbone base address is fixed at 0x3000_0000).
* The ASIC sits on the 8080 16-bit address bus (or, the bottom eight bits of it) and the 8-bit data bus.
* When a Z80 write occurs to a FIFO:
    * the 8 bit data is stored
    * the 'not empty' bit (and possibly the 'full' bit) will be set in the *Status* register
    * an IRQ is raised on the PicoRV32, which can then read one or both FIFOs
* When a Z80 read occurs on a FIFO:
    * The contents of the register is provided
    * the 'full' bit (and possibly the 'not empty' bit) will be cleared in the *Status* register
    * an IRQ is raised on the PicoRV32, which can then read one or both FIFOs

The meaning of the bits in two *Data* FIFOs and the two *Control* FIFOs is set entirely by the PicoRV32 firmware.

The meaning of the bits in the *Status* register is as follows:

| Bit | Meaning                  |
|:----|:-------------------------|
| 0   | Data OUT is not empty    |
| 1   | Control OUT is not empty |
| 2   | Data IN is not empty     |
| 3   | Control IN is not empty  |
| 4   | Data OUT is full         |
| 5   | Control OUT is full      |
| 6   | Data IN is full          |
| 7   | Control IN is full       |

Note the *Status* register is read-only and its contents can only be changed
by reading/writing the relevant FIFOs. That means that a read of
the *Status* register won't clear the *Status* register.

It is an error to read from a FIFO when the 'not empty' bit is unset (i.e. the
FIFO is empty). It is also an error to write to a FIFO when the 'full' bit is
set (i.e. the FIFO is full).

## Example

Here's an example of some (mythical) UART firmware for the PicoRV32:

```
Z80: Write 0x01 to Control OUT   -- Tell ASIC to enable UART mode
ASIC: Zube IRQ
ASIC: Read 0x02 from Status      -- Control OUT has data
ASIC: Read 0x01 from Control OUT -- Enable UART mode
Z80: Write 0x65 to Data OUT      -- Send '0x65' to ASIC
Z80: Write 0x66 to Data OUT      -- Send '0x66' to ASIC
ASIC: Zube IRQ
ASIC: Read 0x01 from Status      -- Data OUT has data
ASIC: Read 0x65 from Data OUT    -- ASIC copies value to UART peripheral
ASIC: Read 0x01 from Status      -- Data OUT has data
ASIC: Read 0x66 from Data OUT    -- ASIC copies value to UART peripheral
ASIC: Read 0x00 from Status      -- Data OUT has no more data
Z80: Read 0x00 from Status       -- No UART data ready
Z80: Read 0x00 from Status       -- No UART data ready
ASIC: UART IRQ
ASIC: Write 0x20 to Data IN      -- Store UART data received
Z80: Read 0x04 from Status       -- See that UART data is ready
Z80: Read 0x20 from Data IN      -- Read data received from UART
Z80: Read 0x00 from Status       -- No more UART data ready
Z80: Read 0x00 from Status       -- No more UART data ready
```

## Z80 bus

We need 22 pins in order to sit on the Z80 bus and act as an I/O peripheral.

| GPIO   | Net Name             | Direction | Description                            |
|:-------|:---------------------|:----------|:---------------------------------------|
| 15..8  | `z80_address_bus`    | Input     | Bottom 8-bits of Z80 Address Bus       |
| 23..16 | `z80_data_bus`       | Bi-Dir    | Z80 Data Bus                           |
| 24     | `z80_bus_dir`        | Output    | High when ASIC drives the Z80 Data Bus |
| 25     | `z80_read_strobe_b`  | Input     | Low when Z80 performing read           |
| 26     | `z80_write_strobe_b` | Input     | Low when Z80 performing write          |
| 27     | `z80_m1`             | Input     | High when Z80 performing read/write    |
| 28     | `z80_ioreq_b`        | Input     | Low when Z80 performing I/O Request    |

Note, there are no wait-states - hopefully the ASIC can always respond within
instantly! There's also no support for Memory Requests (`/MEMRQ`), only I/O
Requests (`/IORQ`). We avoid GPIOs 7..0 so we don't clash with other ASIC
functions.

### Interfacing

You will require a bi-directional bus driver to interface with the 5V bus from
a 1.8V (or similar) ASIC. When `z80_bus_dir` is high, `z80_data_bus` should
be driven on to the data bus. A 74AC245 or similar would be traditional -
connect the ASIC to the `A` side and the Z80 to the `B` side. `/OE` can be
tied low, and `T/R` can be tied to `z80_bus_dir`.

NOTE: This ASIC has only been simulated. It has not been tested with real
hardware. If you connect this to an actual Z80, or any other hardware, you do
so at your own risk! No warranty is given or implied.

## Code Layout

* The top level module is zube, `src/zube.v`
* The Caravel compatible container is, `src/zube_wrapper.v`. This just does
  some I/O routing to connect Zube's pins up to the Caravel GPIO bus.
* The 'data register' (a one-entry FIFO) is in `src/data_register.v`
* The cocotb tests are in `test/test_*.py`
* You can run the cocotb tests with `./test.sh`
* You can harden using openLANE with `./harden.sh`

## Wrapper

This project can be used standalone, but was designed to be
used inside the zero2asic project's Multi Project Environment.
This wraps multiple projects together into one entry onto MPW3.

Every entry submitted to MPW3 has:

* A top module called `user_project_wrapper`
* A 32-bit Wishbone slave port
* A 128-bit logic analyser (in/out/enable)
* 38 GPIO pins (in/out/enable)
* An "independent" clock
* Two IRQs

We don't use the bottom 8 GPIO pins, nor the top two GPIO pins, to avoid
collisions with other ASIC functionality.

## Licence

This project is licensed under the [Apache 2.0 licence](./LICENSE).
