/*
 * Minimal library for IP940
 */

#include <stdbool.h>
#include <stdint.h>

// magic numbers
#define APP_BASE        0x00004000	// app base in flash
#define APP_END         0x00200000	// top of flash
#define DRAM_BASE       0x01000000	// base of DRAM
#define DRAM_END        0x01800000	// end of DRAM (8M boards)
#define DRAM_END_MAX    0x01c00000	// end of DRAM (12M boards)
#define LOADER_BASE     (DRAM_END - (20 * 1024))
#define LOADER_END      (DRAM_END)

#define FLASH_SECTOR_SIZE	0x4000	// flash sector / erase size

#define TIMER_HZ		50

// Registers
#define CPLD_REV_REG	0x021000ff  // initial CPLD revision 1
#define EXPANSION_BASE	0x02130000  // base address for expansion decode

// symbols from the linker script
extern uint32_t	_sdata, _edata, _sbss, _ebss, _vectors;

// functions
__attribute__((noreturn)) extern void main(void);
extern void lib_init();
extern void putc(char c);
extern void puts(const char *s);
extern int getc(void);
extern bool waitc(uint32_t ticks);
extern bool askyn(uint32_t ticks);
extern uint32_t getx8(void);
extern uint32_t getx32(void);
extern void print(const char *fmt, ...);
extern void timer_start(uint32_t ticks);
extern void timer_stop(void);
extern volatile uint32_t timer_count;
extern bool flash_check_rom_id(void);
extern bool flash_program_page(volatile uint32_t *addr, uint32_t *buf);

static inline void
set_vbr(const void *vector_base) {
    uintptr_t value = (uintptr_t)vector_base;
    __asm__ volatile (
        "movec %0, %%vbr"
        :
        : "d" (value)
        : "memory"
        );
}

static inline uint32_t
get_vbr()
{
    uint32_t result;
    __asm__ volatile (
        "movec %%vbr, %0"
        : "=d" (result)
        :
        : "memory"
    );
    return result;
}

static inline uint16_t
get_sr()
{
    uint16_t result;
    __asm__ volatile (
        "move.w %%sr, %0"
        : "=d" (result)
        :
        : "memory"
    );
    return result;
}

static inline void
set_sr(uint16_t value)
{
    __asm__ volatile (
        "move.w %0, %%sr"
        :
        : "d" (value)
        : "memory"
    );
}

static inline bool
interrupt_disable()
{
    bool state = ((get_sr() & 0x0700) == 0);
    set_sr(0x2700);
    return state;
}

static inline void
interrupt_enable(bool enable)
{
    if (enable) {
        set_sr(0x2000);
    }
}

static inline void
nop_nop(void)
{
	__asm__ volatile (
	    "    nop	\n"
	    "    nop	\n"
	);
}

__attribute__((noreturn))
static inline void
stop(void) {
    for (;;) {
        __asm__ volatile (
            "stop #0x2700"
            :
            :
            : "memory"
            );
    }
}
