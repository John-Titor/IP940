/*
 * Minimal library for IP940 boot code.
 */

#include <stdbool.h>
#include <stdarg.h>
#include <stddef.h>

#include "ip940_lib.h"

// stdio //////////////////////////////////////////////////////////////////////

// OX16C954 quad UART on baseboard
#define QUART_BASE      0x02110000
#define QUART_THR       *((volatile uint8_t *)(QUART_BASE+(0x00<<2)+3))
#define QUART_RHR       *((volatile uint8_t *)(QUART_BASE+(0x00<<2)+3))
#define QUART_DLL       *((volatile uint8_t *)(QUART_BASE+(0x00<<2)+3))
#define QUART_DLM       *((volatile uint8_t *)(QUART_BASE+(0x01<<2)+3))
#define QUART_FCR       *((volatile uint8_t *)(QUART_BASE+(0x02<<2)+3))
#define QUART_EFR       *((volatile uint8_t *)(QUART_BASE+(0x02<<2)+3))
#define QUART_LCR       *((volatile uint8_t *)(QUART_BASE+(0x03<<2)+3))
#define QUART_LSR       *((volatile uint8_t *)(QUART_BASE+(0x05<<2)+3))
#define QUART_ICR       *((volatile uint8_t *)(QUART_BASE+(0x05<<2)+3))
#define QUART_SPR       *((volatile uint8_t *)(QUART_BASE+(0x07<<2)+3))

static void
quart_init(void)
{
    QUART_FCR = 1;          // enable FIFO, 550/extended mode
    QUART_LCR = 0xbf;       // enable extended registers, divisor latch
    QUART_EFR = 0x50;       // enable 950 mode, auto RTS
    QUART_LCR = 0x80;       // enable divisor latch
    QUART_DLM = 0;
    QUART_DLL = 5;          // divisor / 5
    QUART_LCR = 0x03;       // clear divisor latch, set n81
    QUART_SPR = 1;          // select CPR
    QUART_ICR = 29;         // prescale 3.625
}

void
putc(char c)
{
    if (c == '\n') {
        putc('\r');
    }
    while ((QUART_LSR & (1 << 5)) == 0) {}
    QUART_THR = c;

    // wait for FIFO drain on newline
    while ((c == '\n') && ((QUART_LSR & 0x40) == 0)) {}
}

static void
putx8(uint8_t x)
{
    static const char xtab[] = "0123456789abcdef";

    putc(xtab[(x >> 4) & 0xf]);
    putc(xtab[x & 0xf]);
}

static void
putx32(uint32_t x)
{
    putx8(x >> 24);
    putx8(x >> 16);
    putx8(x >>  8);
    putx8(x);
}

static void
putd(uint32_t x)
{
    uint32_t div = 1000000000LU;
    bool need_zero = false;

    do {
        if (x >= div) {
            putc('0' + (x / div));
            x = x % div;
            need_zero = true;
        } else if (need_zero || (div == 1)) {
            putc('0');
        }
        div /= 10;
    } while (div > 0);
}

void
print(const char *fmt, ...)
{
    const char *p = fmt;
    bool formatting = false;
    va_list ap;

    va_start(ap, fmt);
    while (*p) {
        const char c = *p++;
        if (!formatting) {
            if (c == '%') {
                formatting = true;
            } else {
                putc(c);
            }
            continue;
        }
        switch (c) {
        case 'd':
            putd(va_arg(ap, uint32_t));
            break;
        case 'b':
            putc('0');
            putc('x');
            putx8(va_arg(ap, uint32_t));
            break;
        case 'x':
            putc('0');
            putc('x');
            putx32(va_arg(ap, uint32_t));
            break;
        case 's':
            print(va_arg(ap, char *));
            break;
        }
        formatting = false;
    }
    va_end(ap);
}

static bool
checkc(void)
{
    return (QUART_LSR & 1) == 1;
}

int
getc(void)
{
    while (!checkc()) {
    }
    return QUART_RHR;
}

bool
waitc(uint32_t ticks)
{
    while (checkc()) {
        (void)getc();
    }
    if (ticks) {
        timer_start(ticks);
    }
    while (!checkc()) {
        if (ticks && (timer_count == 0)) {
            return false;
        }
    }
    return true;
}

bool
askyn(uint32_t ticks)
{
    print("(Y/N) ");
    for (;;) {
        if (!waitc(ticks)) {
            print("timeout \n");
            return false;
        }
        switch (getc()) {
        case 'y':
        case 'Y':
            print("Y\n");
            return true;
        case 'n':
        case 'N':
            print("N\n");
            return false;
        }
    }
}

static uint32_t
getx4(void)
{
    const char c = getc();
    switch (c) {
    case '0'...'9':
        return c - '0';
    case 'a' ... 'f':
        return c - 'a' + 10;
    case 'A' ... 'F':
        return c - 'A' + 10;
    }
    return 0;
}

uint32_t
getx8(void)
{
    uint8_t r = getx4();
    return (r << 4) | getx4();
}

uint32_t
getx32(void)
{
    uint32_t r = getx8();
    r = (r << 8) | getx8();
    r = (r << 8) | getx8();
    return (r << 8) | getx8();
}

// timer //////////////////////////////////////////////////////////////////////

volatile uint32_t timer_count;
#define TIMER_STOP  *(volatile uint8_t *)0x0210003b
#define TIMER_START *(volatile uint8_t *)0x0210003f

__attribute__((interrupt))
void
vector_ipl4(void)
{
    // 50Hz timer
    if (timer_count != 0) {
        if (--timer_count == 0) {
            TIMER_STOP = 1;
        }
    }
}

__attribute__((interrupt))
void
vector_ipl6(void)
{
    // ignore the 200Hz timer
}

void
timer_start(uint32_t ticks)
{
    timer_stop();
    if (ticks > 0) {
        timer_count = ticks;
    }
    TIMER_START = 1;
}

void
timer_stop(void)
{
    TIMER_STOP = 1;
}

// flash //////////////////////////////////////////////////////////////////////

// SST39F040 magic numbers
#define UNLOCK_CODE_1   0xaaaaaaaa
#define UNLOCK_ADDR_1   *(volatile int32_t *)0x00015554
#define UNLOCK_CODE_2   0x55555555
#define UNLOCK_ADDR_2   *(volatile int32_t *)0x0000aaa8
#define CMD_PROGRAM     0xa0a0a0a0
#define CMD_ERASE       0x80808080
#define CMD_SECTOR      0x30303030
#define CMD_ID          0x90909090
#define CMD_ID_EXIT     0xf0f0f0f0
#define CMD_ADDR        *(volatile int32_t *)0x00015554
#define VENDOR_SST      0xbfbfbfbf
#define DEVICE_39F040   0xb7b7b7b7

#define BLANK           0xffffffff
#define FLASH_SIZE      0x00200000
#define SECTOR_SIZE     0x4000

bool
flash_check_rom_id(void)
{
    bool state = interrupt_disable();
    UNLOCK_ADDR_1 = UNLOCK_CODE_1;
    UNLOCK_ADDR_2 = UNLOCK_CODE_2;
    CMD_ADDR = CMD_ID;
    nop_nop();
    uint32_t id0, id1;
    __asm__ volatile (
        "    move.l 0x0,%0  \n"
        "    move.l 0x4,%1  \n"
        : "=d" (id0), "=d" (id1)
        :
        : "memory"
    );
    CMD_ADDR = CMD_ID_EXIT;
    interrupt_enable(state);

    return ((id0 == VENDOR_SST) && (id1 == DEVICE_39F040));
}

bool
flash_program_page(volatile uint32_t *addr, uint32_t *buf)
{
    bool state = interrupt_disable();
    bool result = false;
    uint32_t timeout;
    do {
        UNLOCK_ADDR_1 = UNLOCK_CODE_1;
        UNLOCK_ADDR_2 = UNLOCK_CODE_2;
        CMD_ADDR = CMD_ERASE;
        UNLOCK_ADDR_1 = UNLOCK_CODE_1;
        UNLOCK_ADDR_2 = UNLOCK_CODE_2;
        *addr = CMD_SECTOR;
        for (timeout = 1666666; timeout > 0; timeout--) {
            if (*addr == BLANK) {
                break;
            }
        }
        if (!timeout) {
            break;
        }

        if (buf != NULL) {
            for (uint32_t x = 0; x < (SECTOR_SIZE / sizeof(*addr)); x += 1) {
                const uint32_t val = *(buf + x);
                if (val != BLANK) {
                    volatile uint32_t * const ptr = (addr + x);
                    UNLOCK_ADDR_1 = UNLOCK_CODE_1;
                    UNLOCK_ADDR_2 = UNLOCK_CODE_2;
                    CMD_ADDR = CMD_PROGRAM;
                    *ptr = val;
                    for (timeout = 133; timeout > 0; timeout--) {
                        if (*ptr == val) {
                            break;
                        }
                    }
                    if (!timeout) {
                        break;
                    }
                }
            }
        }
        result = true;
    } while(0);

    interrupt_enable(state);
    return result;
}

// exceptions /////////////////////////////////////////////////////////////////

typedef struct __attribute__((packed)) {
    uint16_t sr;
    uint32_t pc;
    uint16_t format:4;
    uint16_t vector:12;
    union {
        struct {
            uint32_t address;
        } format_0x2;
        struct {
            uint32_t effective_address;
        } format_0x3;
        struct {
            uint32_t effective_address;
            uint32_t faulting_pc;
        } format_0x4;
        struct {
            uint32_t effective_address;
            uint16_t ssw;
            uint16_t writeback_3_status;
            uint16_t writeback_2_status;
            uint16_t writeback_1_status;
            uint32_t fault_address;
            uint32_t writeback_3_address;
            uint32_t writeback_3_data;
            uint32_t writeback_2_address;
            uint32_t writeback_2_data;
            uint32_t writeback_1_address;
            uint32_t writeback_1_data;
            uint32_t push_data_1;
            uint32_t push_data_2;
            uint32_t push_data_3;
        } format_0x7;
        struct {
            uint16_t ssw;
            uint32_t fault_address;
            uint16_t :16;
            uint16_t output_buffer;
            uint16_t :16;
            uint16_t input_buffer;
            uint16_t :16;
            uint16_t instruction_buffer;
            uint16_t internal[16];
        } format_0x8;
        struct {
            uint32_t instruction_address;
            uint16_t internal[4];
        } format_0x9;
        struct {
            uint16_t internal_0;
            uint16_t ssw;
            uint16_t instruction_pipe_c;
            uint16_t instruction_pipe_b;
            uint32_t data_fault_address;
            uint16_t internal_1;
            uint16_t internal_2;
            uint32_t data_output_buffer;
            uint16_t internal_3;
            uint16_t internal_4;
        } format_0xa;
        struct {
            uint16_t internal_0;
            uint16_t ssw;
            uint16_t instruction_pipe_c;
            uint16_t instruction_pipe_b;
            uint32_t data_fault_address;
            uint16_t internal_1;
            uint16_t internal_2;
            uint32_t data_output_buffer;
            uint16_t internal_3[4];
            uint32_t stage_b_address;
            uint16_t internal_4[2];
            uint32_t data_input_buffer;
            uint16_t internal_5[3];
            uint16_t version:4;
            uint16_t internal_6:12;
            uint16_t internal_7[18];
        } format_0xb;
        struct {
            uint32_t faulted_address;
            uint32_t data_buffer;
            uint32_t current_pc;
            uint16_t internal_xfer_count;
            uint16_t subformat:2;
            uint16_t ssw:14;
        } format_0xc;
    };
} frame_t;

void
_sleh(frame_t *frame)
{
    print("Exception %d @ %x\n", frame->vector / 4, frame->pc);
    for (;;) {
        stop();
    }
}

__asm__(
    "   .align 2                            \n"
    "   .type _fleh @function               \n"
    "   .globl _fleh                        \n"
    "_fleh:                                 \n"
    "   movem.l %d0-%d1/%a0-%a1,%sp@-       \n" /* save caller-saved registers    */    \
    "   move.l  %sp,%d0                     \n" /* get stack pointer              */    \
    "   add.l   #24,%d0                     \n" /* index past saved regs          */    \
    "   move.l  %d0,%sp@-                   \n" /* push address of hardware frame */    \
    "   bsr     _sleh                       \n" /* _sleh(frameptr)                */    \
    "   addq.l  #4, %sp                     \n" /* fix stack                      */    \
    "   movem.l %sp@+,%d0-%d1/%a0-%a1       \n" /* restore caller-saved registers */    \
    "   rte                                 \n"                                         \
    );

__attribute__((interrupt))
void
vector_unhandled(void)
{
    print("Unhandled interrupt");
    for (;;) {
        stop();
    }
}

void vector_ipl1(void)                      __attribute__((weak, alias("vector_unhandled")));
void vector_ipl2(void)                      __attribute__((weak, alias("vector_unhandled")));
void vector_ipl3(void)                      __attribute__((weak, alias("vector_unhandled")));
void vector_ipl5(void)                      __attribute__((weak, alias("vector_unhandled")));
void vector_ipl7(void)                      __attribute__((weak, alias("vector_unhandled")));

// startup ////////////////////////////////////////////////////////////////////

__attribute__((noreturn))
void
_start2(void)
{
    // get the console going
    quart_init();

    // enable interrupts
    interrupt_enable(true);

    // run application code
    main();
}

//
// Entry from reset vector.
//
__asm__ (
    "   .align  2                   \n"
    "   .type   _reset @function    \n"
    "   .global _reset              \n"
    "_reset:                        \n" // reset entrypoint
    "    lea     %pc@(_vectors),%a0 \n" // copy text/data to run address
    "    lea     _vectors,%a1       \n"
    "    lea     _edata,%a2         \n"
    "1:                             \n"
    "    move.l  %a0@+,%a1@+        \n"
    "    cmp.l   %a1,%a2            \n"
    "    bne     1b                 \n"
    "    move.l  #_start,%a0        \n"
    "    jmp     (%a0)              \n" // jump to _start
    );


//
// Entry when uploaded, or after _reset has copied us to DRAM.
//
__asm__ (
    "   .align  2                   \n"
    "   .type   _start @function    \n"
    "   .global _start              \n"
    "_start:                        \n" // reset entrypoint
    "    move.w  #0x2700,%sr        \n" // interrupts off
    "    clr.l   %d0                \n"
    "    movec   %d0,%cacr          \n" // turn off caches
    "    cinva   %bc                \n" // clear caches
    "    movec   %d0,%tc            \n" // turn off MMU
    "    pflusha                    \n" // invalidate tlb
    "    movec   %d0,%srp           \n" // reset pagetable root pointers
    "    movec   %d0,%urp           \n"
    "    movec   %d0,%dtt0          \n" // reset transparent translation registers
    "    movec   %d0,%dtt1          \n"
    "    movec   %d0,%itt0          \n"
    "    movec   %d0,%itt1          \n"
    "    movel   0x41bd190,%d0      \n" // load DRAM config
    "    movel   #1665,%d0          \n" // delay loop
    "1:                             \n"
    "    dbf     %d0,1b             \n"
    "    lea     _sbss,%a0          \n" // zero bss
    "    lea     _ebss,%a1          \n"
    "2:                             \n"
    "    clr.l   %a0@+              \n"
    "    cmp.l   %a0,%a1            \n"
    "    bne     2b                 \n"
    "    lea     _vectors,%a0       \n"
    "    move.l  %a0@,%sp           \n" // read SP from vector table
    "    movec   %a0,%vbr           \n" // set VBR
    "    move.l  #_start2,%a0       \n"
    "    jmp     (%a0)              \n" // jump to C at the copied address
    );
