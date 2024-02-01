# Overview

This repository contains information, tools, and firmware for the Perceptics IP940
processor module.

See subdirectory READMEs for more information about the various artifacts.

# Perceptics IP940 processor module hardware

![picture of the board showing component placement and markings](/hardware/cpu_top.jpg)

This is a mezzanine board originally mounted on a 6U VME motherboard. A quantity
were obtained as surplus via eBay with ROMs marked "Vistakon". The ROM was
disassembled and the hardware reverse-engineered.

## Basic features

 - 25MHz or 33MHz 68040
 - 8MiB DRAM with KS84C31 or 12MiB DRAM with CPLD DRAM controller
 - 4x32-pin ROM sockets fitted with 27C040 EPROMs
 - 4x LEDs
 - 4x32-pin connector using standard .025" square pins with 0.1" spacing

Note that the memory map only calls out 8MiB of DRAM, as the firmware is shared
across the various board configurations.

Three revisions of the board have been seen:

 - Part number 111009, marked `REV 02` on the underside, with 8MiB of DRAM.
 - Part number 111594, marked `REV P0` the topside, with 12MiB of DRAM.
 - Part number 112975, marked `REV R1` on the topside, with 12MiB of DRAM.

The `P0` and `R1` boards have provision via W1 and W2 for the fitment of flash
ROMs, allowing in-system programming of the ROMs. This is not possible with the
`02` boards.

## LEDs

The four LEDs are marked on the VME motherboard's front panel as (left to right).

`040BUS`  `TIP`  `HALT`  `RESET`

The `040BUS` LED is driven by a signal that is always low when the 040 is running,
and so will always be lit during normal operation. The `TIP` LED is driven by the
'040 signal of the same name and indicates the processor is accessing the bus.

The HALT LED is driven by P3B.2 from the motherboard; pulling the pin low will turn
the LED on.

The RESET LED is lit when the `#RESET` signal is asserted, either by pressing
the reset pushbutton, or pulling P3D.13 low.

## Jumper settings

### W1 - ROM pin 1 select

position | connection | notes
:-------:|:----------:|-------
1-2      | `A21`
2-3      | `VCC`
2-4      | `A20`      | only on `P0`/`R1` boards

Default for 27CF040: 2-3
Setting for 39SF040: 2-4

### W2 - ROM pin 31 select

position | connection | notes
:-------:|:----------:|-------
1-2      | `A20`
2-3      | `VCC`
2-4      | `R/#W`     | only on `P0`/`R1` boards

Default for 27CF040: 1-2
Setting for 39SF040: 2-3 for read-only, 2-4 for writable

### W3 - unknown

The purpose of this jumper, only present on 8MiB boards, has not been determined.

Default: closed

### W4 - SC0, W5 - SC1

These jumpers allow the SCx signals to be tied low. These are not interesting unless
something needs to snoop the '040 cache.

Default: W4 open, W5 closed.

### W6 - unknown

The purpose of this jumper has not been determined. When installed it pulls U24.9 low.

Default: open

### W7 - watchdog in

When installed, W7 connects P3D.1 to U42.6 (MAX690 `WDI`), allowing the board to reset
if the external signal stops oscillating.

Default: open

## Memory Map

Extracted as text from original firmware and further updated; correlates with dissambly
of the startup code.

There is conflicting evidence in the code for the actual image memory address; the
image memory size check looks at 0x02b8_0000, but the image memory test code assumes
memory at 0x00b0_0000.

### Onboard
```
   EPROM: 0000 0000..007F FFFF      (8 MEGS)
    DRAM: 0100 0000..017F FFFF      (8 MEGS) <- possibly 12?
    MEMC: 0400 0000..04FF FFFF      (old boards only, low address bits are data)
```

### On VME motherboard, with chip selects from module

```
   QUART: 0210 0000..021F FFFF      `#BUSCE0`/`#BUSTA0`
```

### On VME motherboard, historical interest only

```
   IMAGE: 0?B0 0000..02BF FFFF      (may only be 512K)
940 REGS: 0200 0000..0200 000C      (in msbyte of lword)
   BBRAM: 0220 0000..0220 7FC0      (in lsbyte of lword)
   CLOCK: 0220 7FC4..0220 7FFF      (in lsbyte of lword)
VME 6000: 0240 0000..0240 0023      (in lsbyte of word)
     ADC: 0260 0000..026F FFFF      (every 8th byte)
VSC REGS: 0280 0000..028F FFFF
   VME16: 4000 0000..4000 FFFF
   VME24: 4100 0000..41FF FFFF
   VME32: 8000 0000..FFFF FFFF
```

### DRAM controller (MEMC)

This section applies only to boards with the KS84C31 DRAM controller; boards with
the CPLD controller have a serial EEPROM connected to the CPLD that likely provides
configuration information.

Startup code reads from 0x041b_d190 before touching memory and then pauses, allowing
the KS84C31 to complete initialization.

The pause is a single-instruction `dbf` loop with an initial count of 1665, after which DRAM is
immediately written to. Assuming a 150ns ROM read cycle this would be ~250µs.

Decoded for the KS84C31, assuming a full wiring of `CASn`/`RASn` to the address bus, 0x041b_d190 is
approximately:

```
                      EE
                      CC
                      AA
BBRRRRRRRRRRCCCCCCCCCCSS
1098765432109876543210ba
000110111101000110010000
   1   b   d   1   9   0
                      ++-> single access mode
                   +++---> refclk / 6
                  +------> internal / 30 divisor
               +++-------> `#RASx` selected by `B0`/`B1`, `#CASx` selected by `ECASx`
              +----------> 10ns setup time
             +-----------> 18ns column hold time
            +------------> no `#CASx` delay during writes
          ++-------------> 3T `#RASx`/`#CASx` precharge
        ++---------------> 4T `#DTACK` generation for new rows
      ++-----------------> 3T `#DTACK` generation for open page / burst
     +-------------------> 1WS on `#WAITIN`
    +--------------------> `#DTACK` triggered on `CLK` falling edge
   +---------------------> non-interleaved mode
  +----------------------> MBZ
 +-----------------------> address is latched
+------------------------> mode 0 (synchronous) operation
```
## Interrupts

There is no interrupt decoding on the board; `IPL0/1/2` are routed directly to the connector.

`#AVEC` is generated onboard by U24. The original firmware does not use vectored interrupts.

## Bus connector

P3 is a 4x32 connector accepting standard 0.25" square pins. See the schematic for pinout details.

### Standalone operation

For the board to run standalone, the following signal states are required.

 Signal      | Pin  |State | Notes
-------------|------|------|-----------
 `#BG`       | D.5  | low  | Bus Grant from (non-existent) arbiter.
 `#BB`       | D.4  | high | Bus Busy from (non-existent) master peripheral / arbiter.
 `#CDIS`     | B.26 | high | Cache disable input.
 `#MDIS`     | B.27 | high | MMU disable input.
 `#040BUS`   | B.1  | low  | Custom arbitration signal.
 `#VME_PAS`  | B.8  | high | Unused VME-related signal.
 `#VME_PBERR`| B.20 | high | Unused VME-related signal.
 `IPL0`      | D.26 | high | Needs a pull-up.
 `IPL1`      | D.27 | high | Needs a pull-up.
 `IPL2`      | D.28 | high | Needs a pull-up.

