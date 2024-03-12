//
// Utility functions for IP940 bootrom and support tools.
//

#include "defs.h"

    .text
	.align	2

// Init the OX16C954 quad UART channel A
// 115200n81, 16950 mode
uart_init:
    move.b  #1,QUART_FCR        // enable FIFO, 550/extended mode
    move.b  #0xbf,QUART_LCR     // enable extended registers, divisor latch
    move.b  #0x50,QUART_EFR     // enable 950 mode, auto RTS
    move.b  #0x80,QUART_LCR     // enable divisor latch
    move.b  #0,QUART_DLM
    move.b  #13,QUART_DLL       // divisor /13 -> 115200
    move.b  #0x03,QUART_LCR     // clear divisor latch, set n81
    move.b  #1,QUART_SPR        // select CPR
    move.b  #11,QUART_ICR       // prescale 1.375
    rts

// get a character from the UART, return in d0.b
// XXX todo - ~100k iterations is a couple seconds with the
//            caches off, might be nice to support a timeout
getc:
    btst.b  #0,QUART_LSR
    beq     getc
    move.b  QUART_RHR,%d0
    rts

// get a character from the UART, return in d0.b
// times out after a couple of seconds and returns 0
getc_timeout:
    move.l  #100000,%d0
1:
    subq.l  #1,%d0
    btst.b  #0,QUART_LSR
    bne     2f
    cmp.l   #0,%d0
    bne     1b
    rts
2:
    move.b  QUART_RHR,%d0
    rts

// write the character in d0.b to the UART
putc:
    btst.b  #5,QUART_LSR
    beq     putc
    move.b  %d0,QUART_THR
    rts

// get an address as eight hex digits, returns in d0, trashes d1
get_addr:
    bsr     getb
    asl.l   #8,%d0
    bsr     getb
    asl.l   #8,%d0
    bsr     getb
    asl.l   #8,%d0
    bsr     getb
    rts

// get a byte as two hex digits, return in d0.b, trashes d1
// XXX could keep first half in higher part of d0 to avoid touching d1
getb:
    clr.l   %d1                 // scratch
    bsr     getx                // get MS hex nibble
    asl.b   #4,%d0              // shift
    move.b  %d0,%d1             // ... to scratch
    bsr     getx                // get LS hex nibble
    add.b   %d1,%d0             // add to form value
    add.b   %d0,%d7             // track sum of values
    rts

// expect a hex digit and convert to a value, return in d0.b
getx:
    bsr     getc
    cmp.b   #'0',%d0            // check for 0-9
    blt     2f
    cmp.b   #'9',%d0
    bgt     1f
    sub.b   #48,%d0             // convert to value
    rts
1:
    cmp.b   #'A',%d0            // check for A-F
    blt     2f
    cmp.b   #'F',%d0
    bgt     2f
    sub.b   #55,%d0             // convert to value
    rts
2:
    lea     hex_char_err,%a1
    bra     fatal_param8

// print the 0-terminated string in a0
puts:
    tst.b   %a0@
    bne     1f
    rts
1:
    move.b  %a0@+,%d0
    bsr     putc
    bra     puts

// print hex number in d0, trashes d1
putx32:
    swap    %d0
    bsr     putx16
    swap    %d0
putx16:
    rol.w   #8,%d0
    bsr     putx8
    rol.w   #8,%d0
putx8:
    rol.b   #4,%d0
    bsr     putx
    rol.b   #4,%d0
putx:
    move.b  %d0,%d1
    and.b   #0xf,%d1
    cmp.b   #10,%d1
    bge     1f
    add.b   #48,%d1
    bra     2f
1:
    add.b   #55,%d1
2:
    exg     %d0,%d1
    bsr     putc
    exg     %d0,%d1
    rts

// fatal error handler, message in a1
fatal:
    lea     fatal_err,%a0
    bsr     puts
    move.l  %a1,%a0
    bsr     puts
    bra     stop

// fatal error handler with 8-bit parameter, message in a1, parameter in d0
fatal_param8:
    lea     fatal_err,%a0
    move.b  %d2,%d0
    bsr     puts
    move.l  %d0,%d2
    bsr     putx8
    move.l  %a1,%a0
    bsr     puts
    bra     stop

// fatal error handler with 32-bit parameter, message in a1, parameter in d0
fatal_param32:
    move.l  %d0,%d2
    lea     fatal_err,%a0
    bsr     puts
    move.l  %d2,%d0
    bsr     putx32
    move.l  %a1,%a0
    bsr     puts
    bra     stop

// stop forever
stop:
    stop    #0x2700
    bra     stop

hex_char_err:   .asciz " invalid hex character"
fatal_err:      .asciz "\r\nFATAL: "

