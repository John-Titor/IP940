/*
 * First-stage bootloader for IP940.
 *
 * TODO:
 *  - CF boot.
 */

#include <stdbool.h>
#include <stddef.h>
#include "ip940_lib.h"

#define STR(_x) #_x
#define XSTR(_x) STR(_x)
static const char *banner =
    "\n**********************\n"
    "** IP940 ROM bootstrap\n"
    "**\n"
    "** version   : " XSTR(GITHASH) "\n";

static bool flash_supported;
static uint32_t dram_end;

static inline bool contained(uint32_t _x, uint32_t _base, uint32_t _limit) {
    return (((_x) >= (_base)) && ((_x) < (_limit)));
}

static void
autoboot_CF(void)
{
    print("** CF card   : ");
    // check for CF card
    print("not detected\n");
    return;
    // check for filesystem
    // check for \IP940.SYS
    // read header (what?) and validate (how?)
    // load file
    // run
}

static void
autoboot_ROM(void)
{
    const uint32_t *app_vecs = (const uint32_t *)APP_BASE;

    // An app is valid if the initial stack pointer is
    // somewhere in DRAM, and the initial PC is even and
    // somewhere in the app space.
    if (contained(app_vecs[0], DRAM_BASE, dram_end + 1) &&
        contained(app_vecs[1], APP_BASE, APP_END) &&
        ((app_vecs[1] & 1) == 0)) {
        print("++ press any key to cancel ROM autoboot...\n");
        if (waitc(3 * TIMER_HZ)) {
            return;
        }
        interrupt_disable();
        print("++ jumping to ROM application (sp=%x pc=%x)\n", app_vecs[0], app_vecs[1]);
        __asm__ volatile (
            "   move.l %0,%%sp  \n"
            "   jmp    (%1)     \n"
            :
            : "a" (app_vecs[0]), "a" (app_vecs[1])
            : "memory"
        );
    }
    print("!! no program in ROM (%x/%x).\n", app_vecs[0], app_vecs[1]);
}

enum {
    ST_OLD_BOOTBLOCK,
    ST_APP,
    ST_UPLOAD,
    ST_BOOTBLOCK,
    ST_MAX,
};
static const struct srec_config_t {
    uint32_t    input_base;     // address must be >= this
    uint32_t    input_limit;    // address must be < this
    uint32_t    flash_offset;   // add to buffer offset to derive address to flash
    uint8_t     flags;
#define FLG_REQUIRE_FLASH   (1<<0)
    uint8_t     mode;
} srec_configs[] = {
    {0,             APP_BASE,       0,          FLG_REQUIRE_FLASH,  ST_OLD_BOOTBLOCK},
    {APP_BASE,      APP_END,        APP_BASE,   FLG_REQUIRE_FLASH,  ST_APP},
    {DRAM_BASE,     LOADER_BASE,    0,          0,                  ST_UPLOAD},
    {LOADER_BASE,   LOADER_END,     0,          0,                  ST_BOOTBLOCK},
    {0},
};
static const struct srec_config_t *srec_config;

static uint32_t srec_bufaddr;
static uint32_t srec_buf_start;
static uint32_t srec_buf_end;
static uint32_t srec_entrypoint;
static uint8_t srec_sum;

static uint8_t
srecord_getx8(void)
{
    uint8_t v = getx8();
    srec_sum += v;
    return v;
}

static uint32_t
srecord_getx32(void)
{
    uint32_t v = srecord_getx8();
    v = (v << 8) | srecord_getx8();
    v = (v << 8) | srecord_getx8();
    return (v << 8) | srecord_getx8();
}

static bool
srecord_check_sum(const char *type)
{
    // get checksum and validate
    (void)srecord_getx8();
    if (srec_sum != 0xff) {
        print("\n!! S0 checksum invalid (%d)\n", srec_sum);
        return false;
    }
    return true;
}

static bool
srecord_s0(void)
{
    srec_sum = 0;

    // get line length and validate
    uint8_t len = srecord_getx8();
    if ((len < 3) || (len > 200)) {
        print("\n!! S0 length invalid (%d)\n", len);
        return false;
    }

    // discard data
    while (--len) {
        (void)srecord_getx8();
    }

    return srecord_check_sum("S0");
}

static bool
srecord_s3(void)
{
    srec_sum = 0;

    // get line length and validate
    uint8_t len = srecord_getx8();
    if ((len < 6) || (len > 200)) {
        print("\n!! S3 length invalid (%d)\n", len);
        return false;
    }
    len -= 5;

    // get the line address
    uint32_t addr = srecord_getx32();

    // first time aroumd use the address to determine what we are receiving
    if (srec_config == NULL) {
        for (int i = 0; i < ST_MAX; i++) {
            if (contained(addr,
                          srec_configs[i].input_base,
                          srec_configs[i].input_limit) &&
                contained(addr + len,
                          srec_configs[i].input_base,
                          srec_configs[i].input_limit)) {
                srec_config = &srec_configs[i];
                if (!flash_supported && (srec_config->flags & FLG_REQUIRE_FLASH)) {
                    print("!! no flash ROM on this system\n");
                    return false;
                }
                break;
            }
        }
    }
    // validate the address / length fall within a legal region
    if ((srec_config == NULL) ||
        !contained(addr,
                  srec_config->input_base,
                  srec_config->input_limit) ||
        !contained(addr + len,
                  srec_config->input_base,
                  srec_config->input_limit)) {
        print("\n!! S3 address invalid (%x)\n", addr);
        return false;
    }

    // track the portion of the buffer that's been written
    uint32_t buf_offset = addr - srec_config->input_base;
    if (buf_offset < srec_buf_start) {
        srec_buf_start = buf_offset;
    }
    if ((buf_offset + len) > srec_buf_end) {
        srec_buf_end = buf_offset + len;
    }

    // copy S-record data to buffer
    uint8_t *buf_ptr = (uint8_t *)(srec_bufaddr + buf_offset);
    while (len--) {
        *buf_ptr++ = srecord_getx8();
    }

    putc('.');
    return srecord_check_sum("S3");
}

static bool
srecord_s7(void)
{
    srec_sum = 0;

    // get line length and validate
    uint8_t len = srecord_getx8();
    if (len != 5) {
        print("!! S7 length invalid (%d)\n", len);
        return false;
    }

    // get address and validate
    uint32_t addr = srecord_getx32();
    if ((srec_config == NULL) ||
        !contained(addr,
                   srec_config->input_base,
                   srec_config->input_limit) ||
        (addr & 1)) {
        print("!! S7 address invalid (%x)\n");
        return false;
    }

    srec_entrypoint = addr;
    putc('\n');
    return srecord_check_sum("S7");
}

static bool
srecord_receive(void)
{
    srec_config = NULL;
    srec_bufaddr = DRAM_BASE;
    srec_buf_start = 0;
    srec_buf_end = 0;
    srec_entrypoint = 0;
    bool discard = true;

    // get data and entrypoint
    print("++ ready for S-records\n");
    for (;;) {
        if (getc() != 'S') {
            continue;
        }
        char c = getc();
        if (c == '0') {
            if (!srecord_s0()) {
                return false;
            }
            discard = false;
        }
        if (!discard) {
            switch (c) {
            case '3':
                if (!srecord_s3()) {
                    return false;
                }
                break;
            case '7':
                if (!srecord_s7()) {
                    return false;
                }
                return true;
            case '4':
            case '5':
            case '6':
            default:
                break;
            }
        }
    }
}

static bool
flash_program(void)
{
    switch (srec_config->mode) {
    case ST_OLD_BOOTBLOCK:
    case ST_BOOTBLOCK:
        print("++ flash bootblock? ");
        if (!askyn(5 * TIMER_HZ)) {
            return true;
        }
        break;
    case ST_APP:
        break;
    default:
        return false;
    }

    // pad to sector boundaries
    while (srec_buf_start % FLASH_SECTOR_SIZE) {
        srec_buf_start--;
        *(volatile uint8_t *)(srec_bufaddr + srec_buf_start) = 0xff;
    }
    while (srec_buf_end % FLASH_SECTOR_SIZE) {
        *(volatile uint8_t *)(srec_bufaddr + srec_buf_end) = 0xff;
        srec_buf_end++;
    }

    print("++ flashing %x...%x ",
          srec_config->flash_offset + srec_buf_start,
          srec_config->flash_offset + srec_buf_end - 1);

    // erase/flash each sector in turn
    for (uint32_t buf_offset = srec_buf_start; buf_offset < srec_buf_end; buf_offset += FLASH_SECTOR_SIZE) {
        const uint32_t flash_addr = srec_config->flash_offset + buf_offset;
        const uint32_t buf_addr = srec_bufaddr + buf_offset;

        if (!flash_program_page((uint32_t *)flash_addr, (uint32_t *)buf_addr)) {
            print("\n!! FAIL (%x)\n", flash_addr);
            return false;
        }
        print(".");
    }
    print("\n++ OK\n");
    return true;
}

static bool
handle_upload(void) 
{
    switch (srec_config->mode) {
    case ST_OLD_BOOTBLOCK:
        // must flash reset stack/entrypoint
        if (srec_buf_start != 0) {
            print("!! bootblock start address invalid\n");
            return false;
        }
        // we want to flash, not run
        srec_entrypoint = 0;
        break;
    case ST_APP:
        // we want to flash, not run
        srec_entrypoint = 0;
        break;
    case ST_UPLOAD:
        break;
    case ST_BOOTBLOCK:
        // must be able to obtain reset vector
        if (srec_buf_start != 0) {
            print("!! bootblock start address invalid\n");
            return false;
        }
        print("++ run uploaded bootblock? ");
        if (askyn(0)) {
            // synthesize entrypoint from reset vector
            srec_entrypoint = ((uint32_t *)(srec_bufaddr))[1] + srec_bufaddr;
        } else {
            // we want to flash, not run
            srec_entrypoint = 0;
        }
        break;
    default:
        return false;
    }

    // if running, go now
    if (srec_entrypoint) {
        print("++ jumping to loaded program (pc=%x)\n", srec_entrypoint);
        interrupt_disable();
        __asm__ volatile (
            "   jmp    (%0) \n"
            :
            : "a" (srec_entrypoint)
            : "memory"
        );
    }

    // otherwise, flash
    return flash_program();
}

__attribute__((noreturn))
void main(void)
{
    print(banner);

    // detect 8/12M boards by checking for flashable ROM
    flash_supported = flash_check_rom_id();
    dram_end = flash_supported ? DRAM_END_MAX : DRAM_END;
    print("** DRAM      : %dMiB\n", flash_supported ? 12 : 8);
    print("** Flash ROM : %s\n", flash_supported ? "2048KiB" : "not detected");

    // try to auto-boot from CF
    autoboot_CF();

    // try to auto-boot from ROM
    autoboot_ROM();

    // upload / flash loop
    for (;;) {

        // wait for s-record upload
        if (srecord_receive()) {
            handle_upload();
        }
    }
}
