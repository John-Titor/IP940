//
// Test payload to run from flash app area.
//

#include "defs.h"

    .text
    .org    0x0

    // vectors/header
    dc.l    DRAM_END            // initial stack
    dc.l    start               // entrypoint

//
// Entrypoint
//
    .globl  start
start:
    mputs   msg_start
1:
    bra     1b

msg_start:  .asciz "\nIP940 flash payload running...\r\n"
    .align  4
