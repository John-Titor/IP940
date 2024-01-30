//
// Utility functions for IP940 bootrom.
//

#include "defs.h"

    .text
	.align	2

// get a character from the UART, return in d0.b
getc:
1:
    btst.b  #0,QUART_SRA
    beq     1b
    move.b  QUART_RHRA,%d0
//    move.b  %d0,QUART_THRA
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
1:
    tst.b   %a0@
    bne     2f
    rts
2:
    btst.b  #2,QUART_SRA
    beq     2b
    move.b  %a0@+,QUART_THRA
    bra     1b

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
    btst.b  #2,QUART_SRA
    beq     2b
    move.b  %d1,QUART_THRA
    rts

// fatal error handler, message in a1
fatal:
    lea     fatal_err,%a0
    bsr     puts
    move.l  %a1,%a0
    bsr     puts
1:
    bra     1b

// fatal error handler with 8-bit parameter, message in a1, parameter in d0
fatal_param8:
    lea     fatal_err,%a0
    bsr     puts
    bsr     putx8
    move.l  %a1,%a0
    bsr     puts
1:
    bra     1b

// fatal error handler with 32-bit parameter, message in a1, parameter in d0
fatal_param32:
    lea     fatal_err,%a0
    bsr     puts
    bsr     putx32
    move.l  %a1,%a0
    bsr     puts
1:
    bra     1b

hex_char_err:   .asciz " invalid hex character"
fatal_err:      .asciz "\r\nFATAL: "

