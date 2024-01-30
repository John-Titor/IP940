//
// Definitions for IP940 test programs
//

    .equ DRAM_BASE,     0x01000000
    .equ DRAM_END,      0x01800000
    .equ APP_BASE,      0x00004000
    .equ APP_END,       0x00200000
    .equ QUART_BASE,    0x02100000
#define QUART_REG(_x)   (QUART_BASE + (_x << 2) +3)
    .equ QUART_MRA,     QUART_BASE+(0x00<<2)+3
    .equ QUART_SRA,     QUART_BASE+(0x01<<2)+3
    .equ QUART_CSRA,    QUART_BASE+(0x01<<2)+3
    .equ QUART_MISR1,   QUART_BASE+(0x02<<2)+3
    .equ QUART_CRA,     QUART_BASE+(0x02<<2)+3
    .equ QUART_RHRA,    QUART_BASE+(0x03<<2)+3
    .equ QUART_THRA,    QUART_BASE+(0x03<<2)+3
    .equ QUART_IPCR1,   QUART_BASE+(0x04<<2)+3
    .equ QUART_ACR1,    QUART_BASE+(0x04<<2)+3
    .equ QUART_ISR1,    QUART_BASE+(0x05<<2)+3
    .equ QUART_IMR1,    QUART_BASE+(0x05<<2)+3
    .equ QUART_CTU1,    QUART_BASE+(0x06<<2)+3
    .equ QUART_CTL1,    QUART_BASE+(0x07<<2)+3
    .equ QUART_MRB,     QUART_BASE+(0x08<<2)+3
    .equ QUART_SRB,     QUART_BASE+(0x09<<2)+3
    .equ QUART_CSRB,    QUART_BASE+(0x09<<2)+3
    .equ QUART_CRB,     QUART_BASE+(0x0a<<2)+3
    .equ QUART_RHRB,    QUART_BASE+(0x0b<<2)+3
    .equ QUART_THRB,    QUART_BASE+(0x0b<<2)+3
    .equ QUART_IVR1,    QUART_BASE+(0x0c<<2)+3
    .equ QUART_IP1,     QUART_BASE+(0x0d<<2)+3
    .equ QUART_OPCR1,   QUART_BASE+(0x0d<<2)+3
    .equ QUART_SCC1,    QUART_BASE+(0x0e<<2)+3
    .equ QUART_SOPBC1,  QUART_BASE+(0x0e<<2)+3
    .equ QUART_STC1,    QUART_BASE+(0x0f<<2)+3
    .equ QUART_COPBC1,  QUART_BASE+(0x0f<<2)+3

// functions in utils.S
    .globl  getc
    .globl  getb
    .globl  get_addr
    .globl  puts
    .globl  putx32
    .globl  putx16
    .globl  putx8
    .globl  fatal
    .globl  fatal_param32
    .globl  fatal_param8

// emit a string, trashes a0
.macro mputs str
    lea     \str,%a0
    bsr     puts
.endm

// print message and halt
.macro mfatal str
    lea     \str,%a1
    bra     fatal
.endm

// print 8b hex value, message, and halt
.macro fatal8 val str
    move.b  \val,%d0
    lea     \str,%a1
    bra     fatal_param8
.endm

// print 32b hex value, message, and halt
.macro fatal32 val str
    move.l  \val,%d0
    lea     \str,%a1
    bra     fatal_param32
.endm
