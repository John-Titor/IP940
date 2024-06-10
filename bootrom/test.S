//
// Test / experiment program.
//

#include "defs.h"

    .text
    .org    0x0
    .globl  _start

_start:
    bsr     uart_init
    mputs   msg_start
    move.l  #vectors,%d0
    movec   %d0,%vbr

    move.l  #0x018000000,%d0
    bsr     putx32

    bra     .

exception:
    mputs   msg_except
    move.w  %sp@(6),%d0         // format/vector code
    ror.w   #2,%d0              // index -> vector #
    bsr     putx8
    bra     .

msg_start:      .asciz "\r\ntest...\r\n"
msg_except:     .asciz "\r\nexception "
msg_newline:    .asciz "\r\n"

    .org    0x400
vectors:
    .dc.l   0
    .dc.l   0
    .dcb.l  62,exception
