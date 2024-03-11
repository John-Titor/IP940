//
// Test / experiment program.
//

#include "defs.h"

    .text
    .org    0x0
    .globl  start

start:
    bsr     uart_init
    mputs   msg_start
    move.l  #vectors,%d0
    movec   %d0,%vbr
    movec   %vbr,%d0

    tst.b   TIMER_START
    tst.b   CPLD_REV_REG
    mputs   msg_timer
    move.w  #0x2000,%sr
    bra     .

exception:
    move.w  #0x2700,%sr
    mputs   msg_except
    move.w  %sp@(6),%d0         // format/vector code
    ror.w   #2,%d0              // index -> vector #
    bsr     putx8
    tst.b   TIMER_STOP
    rte

msg_start:      .asciz "\r\ntest...\r\n"
msg_timer:      .asciz "timer started\r\n"
msg_stop:       .asciz "\r\ndone."
msg_except:     .asciz "\r\nexception "
msg_newline:    .asciz "\r\n"

    .org    0x400
vectors:
    .dc.l   0
    .dc.l   0
    .dcb.l  62,exception
