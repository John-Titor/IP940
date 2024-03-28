# Overview

This repository contains information, tools, and firmware for the Perceptics IP940
processor module and projects developed around it.

See subdirectory READMEs for more information about the various artifacts.

# Perceptics IP940 processor module hardware

![picture of the board showing component placement and markings](/hardware/cpu_top.jpg)

This is a mezzanine board originally mounted on a 6U VME motherboard. A quantity
were obtained as surplus via eBay with ROMs marked "Vistakon". The ROM was
disassembled and the hardware reverse-engineered.

## Basic features

 - 33MHz 68040
 - 8MiB DRAM with KS84C31 or 12MiB DRAM with CPLD DRAM controller
 - 4x32-pin ROM sockets fitted with 27C040 EPROMs
 - 4x LEDs
 - 4x32-pin connector using standard .025" square pins with 0.1" spacing

Three revisions of the board have been seen:

 - Part number 111009, marked `REV 02` on the underside, with 8MiB of DRAM.
 - Part number 111594, marked `REV P0` the topside, with 12MiB of DRAM.
 - Part number 112975, marked `REV R1` on the topside, with 12MiB of DRAM.

The `P0` and `R1` boards have provision via W1 and W2 for the fitment of flash
ROMs, allowing in-system programming of the ROMs. This is not possible with the
`02` boards, which lack the bidirectional data buffers as well as the write
enable.

## Open-source motherboard

An open-source motherboard for IP940 is in development. More details can be found at
https://www.retrobrewcomputers.org/doku.php?id=builderpages:plasmo:68040:ip940:ip940base.

## LEDs

The four LEDs are marked on the VME motherboard's front panel as (left to 
right):

 - `040BUS` driven by a signal that is always low when the 040 is running,
   always lit during normal operation.
 - `TIP` driven by the '040 signal of the same name, indicates the processor
   is accessing the bus.
 - `HALT` driven by P3B.2 from the motherboard; pulling the pin low will turn
   the LED on.
 - `RESET` lit when the `#RESET` signal is asserted, either by pressing the
   reset pushbutton, or pulling P3D.13 low.

## Jumper settings

### W1 - ROM pin 1 select

position | connection | notes
:-------:|:----------:|-------
1-2      | `A21`
2-3      | `VCC`      | default for 27CF040
2-4      | `A20`      | for 39SF040, only on `P0`/`R1` boards

### W2 - ROM pin 31 select

position | connection | notes
:-------:|:----------:|-------
1-2      | `A20`
2-3      | `VCC`      | default for 27CF040
2-4      | `R/#W`     | for 39SF040, only on `P0`/`R1` boards

### W3 - unknown

The purpose of this jumper, only present on `02` boards, has not been
determined.

Default: closed

### W4 - SC0, W5 - SC1

These jumpers allow the SCx signals to be tied low. These are not interesting
unless something needs to snoop the '040 cache.

Default: W4 open, W5 closed.

### W6 - unknown

The purpose of this jumper has not been determined. When installed it pulls
U24.9 (`P0`/`R1` boards) low.

Default: open

### W7 - watchdog in

When installed, W7 connects P3D.1 to U42.6 (MAX690 `WDI`), allowing the board
to reset if the external signal stops oscillating.

Default: open

## Memory Map

Originally extracted as text from original firmware and further updated; 
correlates with dissambly of the startup code.

### Onboard

#### `REV 02` boards
```
   EPROM: 0000 0000..007F FFFF      2M onboard, option for 4M with W1 in 1-2.
    DRAM: 0100 0000..017F FFFF      8M onboard
    MEMC: 0400 0000..04FF FFFF      Used to configure the KS84C31 DRAM controller
```

#### `REV P0` and `REV R1` boards
```
   EPROM: 0000 0000..007F FFFF      2M onboard, option for 4M with W1 in 1-2.
    DRAM: 0100 0000..01BF FFFF      12M onboard
```

### Expansion connector chip selects
```
 #BUSCE0:   0x008x_xxxx
 #BUSCE0:   0x00cx_xxxx
 #BUSCE0:   0x02xx_xxxx
 #BUSCE1:   ???
 #BUSCE2:   ???
```

### DRAM controller (MEMC)

This section applies only to `REV 02` boards with the KS84C31 DRAM controller.
Boards with the CPLD controller have a serial EEPROM connected to the CPLD that
likely provides configuration information.

Startup code reads from 0x041b_d190 before touching memory and then pauses,
allowing the KS84C31 to complete initialization.

The pause is a single-instruction `dbf` loop with an initial count of 1665,
after which DRAM is immediately written to. Initialization time does not appear
to be specified in the KS84C31 datasheet.

Decoded for the KS84C31, assuming a full wiring of `CASn`/`RASn` to the address
bus, 0x041b_d190 is approximately:

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

There is no interrupt decoding on the board; `IPL0/1/2` are routed directly to
the connector.

`#AVEC` is generated onboard by U24 for all interrupt acknowledge cycles. The
board does not support vectored interrupts.

## Bus connector

P3 is a 4x32 connector accepting standard 0.25" square pins. See the schematic
for pinout details.

### Standalone operation

For the board to run standalone, the following signal states are required.

 Signal      | Pin  |State | Notes
-------------|------|------|-----------
 `#BG`       | D.5  | low  | Bus Grant from (non-existent) arbiter.
 `#BB`       | D.4  | high | Bus Busy from (non-existent) arbiter.
 `#CDIS`     | B.26 | high | Cache disable input.
 `#MDIS`     | B.27 | high | MMU disable input.
 `#040BUS`   | B.1  | low  | Custom arbitration signal.
 `#VME_PAS`  | B.8  | high | Unused VME-related signal.
 `#VME_PBERR`| B.20 | high | Unused VME-related signal.
 `IPL0`      | D.26 | high | Needs a pull-up.
 `IPL1`      | D.27 | high | Needs a pull-up.
 `IPL2`      | D.28 | high | Needs a pull-up.

