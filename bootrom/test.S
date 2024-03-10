//
// Test / experiment program.
//

#include "defs.h"

	.text
	.org	0x0
	.globl	start

start:
	bsr		uart_init
	mputs	msg_start
1:
	bsr		getc
	bsr		putc
	bra		1b

null_exception:
	// just because we got an error, don't give up now...
	rte

fatal_exception:
	mputs	msg_except
    move.w  %sp@(6),%d0         // format/vector code
    ror.w   #2,%d0              // index -> vector #
    bsr     putx8
	bra		.

msg_start:	.asciz "\r\ntest..."
msg_except:	.asciz "\r\nexception "

	.org	0x100
vectors:
    dc.l    0
    dc.l    0
//    dc.l    null_exception            // access fault
    dc.l    fatal_exception            // access fault
    dc.l    fatal_exception           // address error
    dc.l    fatal_exception           // illegal instruction
    dc.l    fatal_exception           // divide by zero
    dc.l    fatal_exception           // CHK/CHK2
    dc.l    fatal_exception           // TRAPcc/TRAPV
    dc.l    fatal_exception           // privilege violation
    dc.l    fatal_exception           // trace
    dc.l    fatal_exception           // line A
    dc.l    fatal_exception           // line F