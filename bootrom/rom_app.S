//
// Test payload to run from flash app area.
//

#include "defs.h"

    .text
    .org    0x0

    // vectors/header
    dc.l    DRAM_END            // initial stack
    dc.l    _start              // entrypoint

//
// Entrypoint
//
    .globl  _start
_start:
    mputs   msg_start
1:
    bra     1b

msg_start:  .asciz "\nIP940 flash 2 payload running...\r\n"
    .align  4
