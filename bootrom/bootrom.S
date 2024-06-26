//
// Lightweight bootrom for IP940.
//
// Flashed into the first sector of the ROMs. Supports booting a
// program flashed into sectors 1.. or uploaded to DRAM as S-records.
//

#include "defs.h"

//
// Vector table
//
    .text

    .org    0x0
    dc.l    DRAM_END-4          // top of RAM
    dc.l    _start              // entrypoint
    .dcb.l  62,exception        // we expect no exceptions

//
// Exception handler
//
// We expect no exceptions, so just print the vector number and PC.
//
exception:
    mputs   err_exception1
    move.w  %sp@(6),%d0         // format/vector code
    ror.w   #2,%d0              // index -> vector #
    bsr     putx8
    mputs   err_exception2
    move.l  %sp@(2),%d0
    bsr     putx32
    mputs   msg_newline
    bra     stop

//
// Reset handler
//
// Emulate a complete reset here; this should not be necessary
// per the 040 spec, but experimentation suggests that some parts
// are required.
//
    .globl  _start              // keep the linker happy
_start:
    move.w  #0x2700,%sr         // interrupts off
    clr.l   %d0
    movec   %d0,%vbr            // reset VBR
    cinva   %bc                 // clear caches
    movec   %d0,%tc             // turn off MMU
    pflusha                     // invalidate tlb
    movec   %d0,%srp            // reset pagetable root pointers
    movec   %d0,%urp
    movec   %d0,%dtt0           // reset transparent translation registers
    movec   %d0,%dtt1
    movec   %d0,%itt0
    movec   %d0,%itt1

//
// Configure the DRAM controller on 8M boards. We don't actually
// know whether we're an 8M or 12M board, so do this regardless.
//
    movel   0x41bd190,%d0       // load DRAM config
    movel   #1665,%d0           // delay loop
1:
    dbf     %d0,1b

//
// Init the console.
//
    bsr     uart_init
    mputs   msg_signon

//
// Check whether the app in flash at 0x4000 is bootable, and
// either wait out the autoboot delay or drop straight through
// to the S-record receiver.
//
check_autoboot:
    move.l  #APP_BASE,%a1       // base of app in flash
    move.l  %a1@,%d6            // app stack pointer
    cmp.l   #DRAM_BASE,%d6      // range-check against DRAM
    blt     1f
    cmp.l   #DRAM_END,%d6
    bgt     1f

    move.l  %a1@(4),%d5         // app entrypoint
    cmp.l   #APP_BASE,%d5       // range-check against app space
    blt     1f
    cmp.l   #APP_END,%d5
    bge     1f
    btst    #0,%d5              // instructions must be 2-aligned
    bne     1f

    mputs   msg_prompt          // show autoboot prompt
    bsr     getc_timeout
    tst.b   %d0
    bne     2f                  // got character, skip to upload

    mputs   app_go1             // print app entrypoint / stack
    move.l  %d6,%d0
    bsr     putx32
    mputs   app_go2
    move.l  %d5,%d0
    bsr     putx32
    mputs   msg_newline

    move.l  %d6,%sp             // and go run it
    move.l  %d5,%a2
    jmp     %a2@

1:
    mputs   msg_no_app          // nothing to boot
2:
    mputs   msg_srecords        // prompt for upload

//
// Loop waiting for the start of an S-record.
//
//  d7 - accumulated checksum
//
srec_loop:
    bsr     getc                // wait for character
srec_loop1:
    cmp.b   #'S',%d0            // 'S' for an S-record
    bne     srec_loop

1:
    bsr     getc                // get s-record type
    cmp.b   #'S',%d0
    beq     1b                  // handle duplicate 'S'
    cmp.b   #'3',%d0
    beq     srec_3              // handle S3
    cmp.b   #'7',%d0
    beq     srec_7              // handle S7
    cmp.b   #'0',%d0
    beq     srec_loop           // ignore S0
    cmp.b   #'4',%d0
    beq     srec_loop           // ignore S4
    cmp.b   #'5',%d0
    beq     srec_loop           // ignore S5
    cmp.b   #'6',%d0
    beq     srec_loop           // ignore S6

    fatal8  %d0,err_srec_unsup

//
// Handle an S3 record.
//
//  d6 - remaining data bytes
//  a6 - destination address for next data
//
srec_3:
    clr.b   %d7                 // reset checksum accumulator
    bsr     getb                // get line length
    cmp.b   #6,%d0              // ensure it's sane
    blt     srec_bad_len        // ... no
    sub.b   #6,%d0              // subtract address & checksum bytes & one for dbf
    clr.w   %d6
    move.b  %d0,%d6             // ... and save for later
    bsr     get_addr            // get destination address
    cmp.l   #DRAM_BASE,%d0      // range check against DRAM
    blt     srec_bad_addr
    cmp.l   #DRAM_END,%d0
    bgt     srec_bad_addr
    move.l  %d0,%a6             // ... and save for later
1:
    bsr     getb                // get byte
    move.b  %d0,%a6@+           // ... and put to memory
    dbf     %d6,1b              // go get another byte

    bsr     srec_check_sum      // get the checksum byte and verify
    mputs   srec_progress       // emit progress marker
    bra     srec_loop           // ... go get another record

//
// Handle an S7 record.
//
//  a6 - entrypoint
//
srec_7:
    clr.b   %d7                 // reset checksum accumulator
    bsr     getb                // get line length
    cmp.b   #5,%d0              // must be 5
    bne     srec_bad_len        // ... but it's not
    bsr     get_addr            // get entrypoint address
    cmp.l   #DRAM_BASE,%d0      // range check against DRAM
    blt     srec_bad_addr
    cmp.l   #DRAM_END,%d0
    bgt     srec_bad_addr
    btst    #0,%d0              // instructions must be 2-aligned
    bne     srec_bad_addr
    move.l  %d0,%a6
    bsr     srec_check_sum      // get the checksum byte and verify
    mputs   srec_go
    cpusha  %bc                 // clean/invalidate caches to ensure coherency
    jmp     %a6@                // ... and call the entrypoint

//
// S-record length not sensible.
//
srec_bad_len:
    fatal32 %d0,err_srec_len

//
// S-record address not sensible.
//
srec_bad_addr:
    fatal32 %d0,err_srec_addr

//
// Validate the end-of-line checksum.
//
srec_check_sum:
    bsr     getb                // get sum
    cmp.b   #0xff,%d7           // accumulator + 1s complement = 0xff
    bne     1f                  // ... mismatch
    rts
1:
    fatal8  %d7,err_srec_sum

msg_signon:     .asciz "\r\n\r\n** IP940 bootstrap rel 6\r\n"
msg_prompt:     .asciz "Hit any key to cancel autoboot...\r\n"
msg_no_app:     .asciz "No app in flash.\r\n"
msg_srecords:   .asciz "Send S-records for DRAM upload..."
msg_newline:    .asciz "\r\n"
err_exception1: .asciz "Unhandled exception "
err_exception2: .asciz " @ "
app_go1:        .asciz "\r\nStarting app with stack "
app_go2:        .asciz " entrypoint "
srec_progress:  .asciz "."
srec_go:        .asciz "\r\nUpload complete, jumping to loaded code...\r\n"
err_srec_sum:   .asciz " S-record checksum mismatch\r\n"
err_srec_unsup: .asciz " invalid S-record type"
err_srec_len:   .asciz " invalid S-record length"
err_srec_addr:  .asciz " invalid S-record address"

    .align  4
