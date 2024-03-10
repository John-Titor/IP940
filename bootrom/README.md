# IP940 bootrom and tools

## bootrom.S

Simple bootstrap loader intended to be flashed at the bottom of
the IP940 ROM space. Supports download of S-records to DRAM, or
launching a second-stage bootstrap at 0x4000.

## flasher.S

Downloadable code that supports flashing SST39F040 flash ROMs when
the IP940 is appropriately jumpered. Will either flash sector 0 with
a new loader (max 16kiB), or sectors 1... with a payload up to 
2032kiB in size.

Flashing proceeds in reverse order, so an incomplete flash will
result in the bootrom refusing to load the program.

## S-record notes

Only S0/S3/S7 records are supported.

## Building

Build all parts with `make`.

Any relatively modern m68k-elf GCC can be used; adjust the Makefile
if required.


## Booting operating systems that expect RAM at 0

Some candidate operating systems (EmuTOS for example) expect RAM at 0. Since
the IP940 has ROM at 0, the MMU has to be employed.

The target memory layout is:

DRAM 0x0000_0000 - 0x00bd_ffff -> 0x0102_0000 - 0x01bf_ffff
I/O  0x0200_0000 - 0x02ff_ffff -> 0x0200_0000 - 0x02ff_ffff

Assuming 8K pages, this requires:
 - Root table (128 entries, 512B)
 - 1 pointer table covering 0-0x01ff_ffff (128 entries, 512B)
 - 48 page tables covering 0-0x00bd_ffff (32 entries/128B ea, 6144B)
 - DTT0 configured for I/O covering the 16M starting at 0x0200_0000 (FC2 ignored)
 - ITT0/ITT1/DTT1 disabled
 - URP and SRP pointed at the table
 - VBR set to zero

One page is reserved at the bottom of DRAM to host this, with 7168B used.
The page is not mapped to reduce the chance of accidental corruption.
