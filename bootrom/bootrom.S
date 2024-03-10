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
    dc.l    start               // entrypoint
    dc.l    exception           // access fault
    dc.l    exception           // address error
    dc.l    exception           // illegal instruction
    dc.l    exception           // divide by zero
    dc.l    exception           // CHK/CHK2
    dc.l    exception           // TRAPcc/TRAPV
    dc.l    exception           // privilege violation
    dc.l    exception           // trace
    dc.l    exception           // line A
    dc.l    exception           // line F

//
// Exception handler
//
// We expect no exceptions, so just print the index and PC.
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
1:
    bra     1b

//
// Reset handler
//
    .globl  start               // keep the linker happy
start:
    move.w  #0x2700,%sr         // interrupts off
    clr.l   %d0
    movec   %d0,%vbr            // reset VBR
    cinva   %bc                 // clear caches
    movec   %d0,%tc             // turn off MMU
    pflusha                     // invalidate tlb
    movec   %d0,%srp            // reset pagetable root pointers
    movec   %d0,%urp
    move.l  #0x0001c020,%d0     // DTT0, 0-0x02000000 cacheable, copy-back (RAM/ROM)
    movec   %d0,%dtt0
    move.l  #0x00ffc060,%d0     // DTT1, default uncachable
    movec   %d0,%dtt1
    move.l  #0x00ffc000,%d0     // ITT0, default cacheable, write-through
    movec   %d0,%itt0
    clr.l   %d0                 // disable ITT1
    movec   %d0,%itt1
//    move.l  #0x8000,%d0         // instruction cache on
//    movec   %d0,%cacr

//
// Configure the DRAM controller on 8M boards.
//
    movel   0x41bd190,%d0       // load DRAM config
    movel   #1665,%d0           // delay loop
1:
    dbf     %d0,1b

//
// Init the console
//
    bsr     uart_init
    mputs   signon

//
// loop reading S-records
//
// register usage:
//  d7 - accumulated checksum
//
srec_loop:
    bsr     getc                // wait for character
    cmp.b   #'X',%d0            // 'X' to execute code at 0x4000
    beq     boot_app
    cmp.b   #'x',%d0            // 'x' to execute code at 0x4000
    beq     boot_app
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
// boot the application in flash at 0x4000
//
boot_app:
    move.l  #APP_BASE,%a1       // base of app in flash
    move.l  %a1@,%d0            // app stack pointer
    cmp.l   #DRAM_BASE,%d0      // range-check against DRAM
    blt     2f
    cmp.l   #DRAM_END,%d0
    bgt     2f
    move.l  %d0,%d6             // ... save for later

    mputs   app_go1
    bsr     putx32

    move.l  %a1@(4),%d0         // app entrypoint
    cmp.l   #APP_BASE,%d0       // range-check against app space
    blt     3f
    cmp.l   #APP_END,%d0
    bge     3f
    move.l  %d0,%d5             // ... save for later

    btst    #0,%d0              // instructions must be 2-aligned
    bne     3f
    mputs   app_go2
    bsr     putx32
    mputs   msg_newline

    move.l  %d6,%sp
    move.l  %d5,%a2
    jmp     %a2@

2:
    fatal32 %d0,err_app_stack
3:
    fatal32 %d0,err_app_entry

//
// handle an S3 record
//
// register usage:
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
// handle an S7 record
//
// register usage:
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
// S-record length not sensible
//
srec_bad_len:
    fatal32 %d0,err_srec_len

//
// S-record address not sensible
//
srec_bad_addr:
    fatal32 %d0,err_srec_addr

//
// handle the end-of-line checksum
//
srec_check_sum:
    bsr     getb                // get sum
    cmp.b   #0xff,%d7           // accumulator + 1s complement = 0xff
    bne     1f                  // ... mismatch
    rts
1:
    fatal8  %d7,err_srec_sum

signon:         .asciz "\r\n\r\nIP940 bootstrap rel 2\r\n 'X' to execute code at 0x4000 or send S-records..."
msg_newline:    .asciz "\r\n"
err_exception1: .asciz "Unhandled exception "
err_exception2: .asciz " @ "
app_go1:        .asciz "\r\nStarting app with stack "
app_go2:        .asciz " entrypoint "
err_app_stack:  .asciz " app stack invalid"
err_app_entry:  .asciz " app entrypoint invalid"
srec_progress:  .asciz "."
srec_go:        .asciz "\r\nUpload complete, jumping to loaded code...\r\n"
err_srec_sum:   .asciz " S-record checksum mismatch\r\n"
err_srec_unsup: .asciz " invalid S-record type"
err_srec_len:   .asciz " invalid S-record length"
err_srec_addr:  .asciz " invalid S-record address"

    .align  4