//
// Definitions for IP940 boot ROM and support tools.
//

// Memory
    .equ APP_BASE,          0x00004000  // start of non-bootloader ROM space
    .equ APP_END,           0x00200000  // end of ROM
    .equ DRAM_BASE,         0x01000000
    .equ DRAM_END,          0x01800000  // 8M board compatibility

// Registers
    .equ TIMER_STOP,        0x0210003b  // any access stops CPLD timers
    .equ TIMER_START,       0x0210003f  // any access starts CPLD timers
    .equ CPLD_REV_REG,      0x021000ff  // initial CPLD revision 1
    .equ EXPANSION_BASE,    0x02130000  // base address for expansion decode

// CF interface on baseboard
    .equ CF_BASE,           0x02100040
    .equ CF_DATA,           CF_BASE+0x02        // 16b data
    .equ CF_DATA8,          CF_BASE+0x03        // 8b data
    .equ CF_ERROR,          CF_BASE+(0x01<<2)+3
    .equ CF_FEATURE,        CF_BASE+(0x01<<2)+3
    .equ CF_SECTOR_COUNT,   CF_BASE+(0x02<<2)+3
    .equ CF_LBA_0,          CF_BASE+(0x03<<2)+3
    .equ CF_LBA_1,          CF_BASE+(0x04<<2)+3
    .equ CF_LBA_2,          CF_BASE+(0x05<<2)+3
    .equ CF_LBA_3,          CF_BASE+(0x06<<2)+3
    .equ CF_STATUS,         CF_BASE+(0x07<<2)+3
    .equ CF_COMMAND,        CF_BASE+(0x07<<2)+3

// OX16C954 quad UART on baseboard
    .equ QUART_BASE,        0x02110000
    .equ QUART_THR,         QUART_BASE+(0x00<<2)+3
    .equ QUART_RHR,         QUART_BASE+(0x00<<2)+3
    .equ QUART_DLL,         QUART_BASE+(0x00<<2)+3
    .equ QUART_DLM,         QUART_BASE+(0x01<<2)+3
    .equ QUART_FCR,         QUART_BASE+(0x02<<2)+3
    .equ QUART_EFR,         QUART_BASE+(0x02<<2)+3
    .equ QUART_LCR,         QUART_BASE+(0x03<<2)+3
    .equ QUART_LSR,         QUART_BASE+(0x05<<2)+3
    .equ QUART_ICR,         QUART_BASE+(0x05<<2)+3
    .equ QUART_SPR,         QUART_BASE+(0x07<<2)+3

// functions in utils.S
    .globl  uart_init
    .globl  getc
    .globl  putc
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
