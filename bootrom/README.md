# IP940 bootrom and tools

## loader

Simple bootstrap loader intended to be flashed at the bottom of
the IP940 ROM space. Supports download of S-records to DRAM, or
launching a second-stage bootstrap at 0x4000.

## flasher

Downloadable code that supports flashing SST39F040 flash ROMs when
the IP940 is appropriately jumpered. Will either flash sector 0 with
a new loader (max 16kiB), or sectors 1... with a payload up to 
2032kiB in size.

## S-record notes

Only S0/S3/S7 records are supported.

## Building

Build all parts with `make`.

Any relatively modern m68k-elf GCC can be used; adjust the Makefile
if required.
