# Overview

This repository contains information, tools, and firmware for the Perceptics IP940
processor module.

See subdirectory READMEs for more information about the various artifacts.

# Perceptics IP940 processor module hardware

![picture of the CPU board showing component placement and markings](/hardware/cpu_top.jpg)

This is a mezzanine board originally mounted on a 6U VME motherboard. A quantity
were obtained as surplus via eBay with ROMs marked "Vistakon". The ROM was
disassembled and the hardware reverse-engineered.

## Basic features

 - 25MHz or 33MHz 68040
 - 12MiB RAM with CPLD or KS84C31 (older versions) DRAM controller
 - 4x32-pin ROM sockets, 27C040 EPROMs (jumperable for 4Mb flash)
 - 4x LEDs
 - 4x32-pin connector using standard .025" sqare pins on 0.1" spacing

Note that the memory map only calls out 8MiB of DRAM, but each data line is
connected to 3 1Mx4 parts and the memory controller decodes A[0:23].

## LEDs

The four LEDs are marked on the VME mainboard's front panel as (left to right).

`040BUS`, `TIP`, `HALT`, `RESET`

The #040BUS LED is driven by a signal that is always low when the 040 is running,
and so will always be lit during normal operation. The #TIP LED is driven by the
'040 signal of the same name and indicates processor activity.

The HALT LED is driven by P3B.2 from the mainboard; pull the pin low to turn
the LED on.

The RESET LED is lit when the #RESET signal is asserted, either by pressing
the reset pushbutton, or pulling P3D.13 low.

## Jumper settings

### W1 - ROM pin 1 select

1-2: A21
2-3: VCC
2-4: A20

Default for 27CF040: 2-3
Setting for 39SF040: 2-4

### W2 - ROM pin 31 select

The presence of R/!W here strongly suggests that flash parts can be used.

1-2: A20
2-3: VCC
2-4: R/!W

Default for 27CF040: 1-2
Setting for 39SF040: 2-3 for read-only, 2-4 for writable

### W4 - SC0, W5 - SC1

These jumpers allow the SCx signals to be tied low. These are not interesting unless
something needs to snoop the '040 cache.

Default: W4 open, W5 closed.

### W6 - unknown

The purpose of this jumper has not been determined. When installed it pulls U24.9 low.

Default: open

### W7 - watchdog in

When installed, W7 connects P3D.1 to U42.6 (MAX690 WDI), allowing the board to reset
if the external signal stops oscillating.

Default: open

## Memory Map

Extracted as text from original firmware and further updated; correlates with dissambly
of the startup code.

There is conflicting evidence in the code for the actual image memory address; the
image memory size check looks at 0x02b8_0000, but the image memory test code assumes
memory at 0x00b0_0000.

### Onboard

   EPROM: 0000 0000..007F FFFF      (8 MEGS)
    DRAM: 0100 0000..017F FFFF      (8 MEGS) <- possibly 12?
    MEMC: 0400 0000..04FF FFFF      (old boards only, low address bits are data)

### On VME carrier, with chip selects

   QUART: 0210 0000..021F FFFF      #BUSCE0/#BUSTA0

### On VME carrier, historical interest only

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

### DRAM controller (MEMC)

This is only present on older boards; newer boards have a serial EEPROM connected to
the memory controller, possibly containing configuration information. 

## Interrupts

There is no interrupt decoding on the board; IPL0/1/2 are routed directly to the connector.

AVEC is generated onboard by U24. The original firmware does not use vectored interrupts.

## Bus connector

P3 is a 4x32 connector accepting standard 0.25" square pins. See the schematic for pinout details.

### Standalone operation

For the board to run standalone, the following signal states are required.

| Signal      | Pin  |State | Notes
+-------------+------+------+-----------
| #BG         | D.5  | low  | Bus Grant from (non-existent) arbiter.
| #BB         | D.4  | high | Bus Busy from (non-existent) master peripheral / arbiter.
| #CDIS       | B.26 | high | Cache disable input.
| #MDIS       | B.27 | high | MMU disable input.
| #040BUS     | B.1  | low  | Custom arbitration signal.
| #VME_PAS    | B.8  | high | Unused VME-related signal.
| #VME_PBERR  | B.20 | high | Unused VME-related signal.
| IPL0        | D.26 | high | Needs a pull-up.
| IPL1        | D.27 | high | Needs a pull-up.
| IPL2        | D.28 | high | Needs a pull-up.

