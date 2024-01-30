//
// ROM flasher
//

#include "defs.h"

    // SST39F040 magic numbers
    .equ    UNLOCK_CODE_1,  0xaaaaaaaa
    .equ    UNLOCK_ADDR_1,  0x00015554
    .equ    UNLOCK_CODE_2,  0x55555555
    .equ    UNLOCK_ADDR_2,  0x0000aaa8
    .equ    CMD_PROGRAM,    0xa0a0a0a0
    .equ    CMD_ERASE,      0x80808080
    .equ    CMD_SECTOR,     0x30303030
    .equ    CMD_ID,         0x90909090
    .equ    CMD_ID_EXIT,    0xf0f0f0f0
    .equ    CMD_ADDR,       0x00015554
    .equ    VENDOR_SST,     0xbfbfbfbf
    .equ    DEVICE_39F040,  0xb7b7b7b7

    .equ    FLASH_SIZE,     0x00200000
    .equ    SECTOR_SIZE,    0x4000

//
// Entrypoint
//
    .text
    .org    0x0
    .globl  start
start:
    mputs   msg_start

    bsr     check_flash_id
    bsr     get_srecords        // sets buffer end pointer in a5
    bsr     erase_flash
    bsr     program_flash

    mputs   msg_reset
1:
    bra     1b

//
// check the flash vendor / device ID
//
check_flash_id:
    move.l  #UNLOCK_CODE_1,UNLOCK_ADDR_1
    move.l  #UNLOCK_CODE_2,UNLOCK_ADDR_2
    move.l  #CMD_ID,CMD_ADDR    // switch flash to software ID mode

    move.l  0x0,%d0             // read vendor code
    cmp.l   #VENDOR_SST,%d0
    beq     1f
    fatal32 %d0,err_vendor
1:
    move.l  0x4,%d0             // read device code
    cmp.l   #DEVICE_39F040,%d0
    beq     2f
    fatal32 %d0,err_device
2:
    move.l  #CMD_ID_EXIT,CMD_ADDR   // return to normal mode
    rts

//
// receive s-records from the serial port, copy into DRAM buffer
//
get_srecords:
    lea     FLASH_SIZE,%a4      // lowest buffer address seen
    lea     0,%a5               // highest buffer address seen

    lea     flash_buf,%a0       // zero the flash buffer
    move.l  %a0,%a1
    add.l   #FLASH_SIZE,%a1
    clr.l   %d0
1:
    move.l  %d0,%a0@+
    cmp.l   %a1,%a0
    blt     1b

    mputs   msg_srec            // ready for S-records
srec_loop:
    bsr     getc                // wait for start of record
    cmp.b   #'S',%d0
    bne     srec_loop

    bsr     getc                // get s-record type
    cmp.b   #'3',%d0
    beq     srec_3              // handle S3
    cmp.b   #'7',%d0
    beq     srec_7              // handle S7
    cmp.b   #'0',%d0
    beq     srec_loop           // ignore S0

    fatal8  %d0 err_srec_unsup  // not something we expect

//
// handle an S3 record
//  d0-d1/a0 - scratch
//  d5 - buffer offset
//  d6 - remaining data byte count
//  d7 - s-record checksum accumulator
//  a4 - updated with the lowest address seen
//  a5 - updated with the highest address seen
//  a6 - buffer pointer
//
srec_3:
    clr.b   %d7                 // reset checksum accumulator

    clr.l   %d0
    bsr     getb                // get line length
    cmp.b   #6,%d0              // ensure it's sane
    blt     srec_bad_len        // ... no
    sub.l   #5,%d0              // subtract address & checksum bytes leaving data length
    move.l  %d0,%d6             // ... and save for later

    bsr     get_addr            // get destination address
    cmp.l   #FLASH_SIZE,%d0     // range check against flash area (XXX should add length...)
    bgt     srec_bad_addr       // ... bad
    move.l  %d0,%d5             // ... save for later

    cmp.l   %d0,%a4             // compare with previous lowest address
    blt     1f                  // ... not lower
    move.l  %d0,%a4             // ... update

1:
    add.l   %d6,%d0             // get end of record data
    cmp.l   %d0,%a5             // compare with previous highest address
    bgt     2f                  // ... not higher
    move.l  %d0,%a5             // ... update

2:
    lea     flash_buf,%a6       // offset into flash buffer
    add.l   %d5,%a6             // ... and init write pointer
    subq.l  #1,%d6              // adjust for dbf
3:
    bsr     getb                // get byte
    move.b  %d0,%a6@+           // ... save to buffer
    dbf     %d6,3b              // go get another byte

    bsr     srec_check_sum      // get the checksum byte and verify

    move.b  #'.',QUART_THRA     // emit progress marker
    bra     srec_loop           // ... go get another record

//
// handle an S7 record - end of upload
//  d0-d1/a0-a1 - scratch
//  a4 - lowest program address
//  a5 - highest program address
//
srec_7:
    clr.b   %d7                 // reset checksum accumulator

    bsr     getb                // get line length
    cmp.b   #5,%d0              // must be 5
    bne     srec_bad_len        // ... but it's not

    bsr     get_addr            // get entrypoint address
    cmp.l   #FLASH_SIZE,%d0
    bgt     srec_bad_addr
    btst    #0,%d0              // instructions must be 2-aligned
    bne     srec_bad_addr
    bsr     srec_check_sum      // get the checksum byte and verify

    cmp.l   #0,%a4              // flashing the loader?
    bne     1f                  // ... no, perhaps app
    cmp.l   #FLASH_SIZE,%a5     // must fit within the first sector
    ble     2f
    fatal32 %a5,err_loader_len  // ... not
1:
    cmp.l   #SECTOR_SIZE,%a4    // flashing the app?
    beq     2f                  // ... yes
    fatal32 %a4,err_flash_addr  // ... no, this is an error
2:
    move.l  %a5,%d0             // adjust highest flash address
    add.l   #3,%d0              // round up to 4B
    and.l   #0xfffffffc,%d0     // ... since flash is programed 32b-wide
    move.l  %d0,%a5

    cmp.l   %a5,%a4
    blt     4f
    fatal32 %a5,err_flash_len
4:
    mputs   msg_done
    rts

//
// handle the end-of-line checksum
//
srec_check_sum:
    bsr     getb                // get sum
    cmp.b   #0xff,%d7           // accumulator + 1s complement = 0xff
    bne     1f                  // ... mismatch
    rts
1:
    fatal8  %d7 err_srec_sum

//
// S-record length not sensible
//
srec_bad_len:
    fatal8  %d0,err_srec_len

//
// S-record address not sensible
//
srec_bad_addr:
    fatal32 %d0,err_srec_addr

//
// erase flash that will be programmed
//  d0-d1/a0 - scratch
//  d2,d3 - timeout counters
//  a1 - sector address
//  a4 - start of program in flash
//  a5 - end of program in flash
//
erase_flash:
    mputs   msg_erase

    move.l  %a4,%a1             // start of program
1:
    move.l  #UNLOCK_CODE_1,UNLOCK_ADDR_1
    move.l  #UNLOCK_CODE_2,UNLOCK_ADDR_2
    move.l  #CMD_ERASE,CMD_ADDR  // generic erase command
    move.l  #UNLOCK_CODE_1,UNLOCK_ADDR_1
    move.l  #UNLOCK_CODE_2,UNLOCK_ADDR_2
    move.l  #CMD_SECTOR,%a1@    // sector erase subcommand and sector address

    move.w  #25,%d2             // 25ms
2:
    move.w  #6666,%d3           // 1ms / 150µs access time = 6666 read cycles
3:
    move.l  %a1@,%d0
    cmp.l   #0xffffffff,%d0     // erase complete (data matches expected value)?
    beq     4f                  // ... yes, done with this sector
    dbf     %d3,3b
    dbf     %d2,2b

    fatal32 %a1,err_erase       // erase timed out
4:
    add.l   #SECTOR_SIZE,%a1    // next sector
    cmp.l   %a5,%a1             // done?
    blt     1b                  // ... not yet

    mputs   msg_done
    rts

//
// program / verify flash
//
//  d0-d1/a0 - scratch
//  d2 - data word
//  d3 - timeout counter
//  a1 - destination address
//  a2 - source address
//  a4 - start of program in flash
//  a5 - end of program in flash
//
program_flash:
    mputs   msg_program

    move.l  %a5,%a1             // work backwards from the end
    subq.l  #4,%a1
    lea     flash_buf,%a2
    add.l   %a1,%a2             // ... and the top of the DRAM buffer
1:
    move.l  #UNLOCK_CODE_1,UNLOCK_ADDR_1
    move.l  #UNLOCK_CODE_2,UNLOCK_ADDR_2
    move.l  #CMD_PROGRAM,CMD_ADDR // configure flash for byte program
    move.l  %a2@,%d2            // get word to program
    move.l  %d2,%a1@            // write word to flash

    move.w  #200,%d3            // 20µs worst-case program time / 150ns access time = 133 read cycles
2:
    cmp.l   %a1@,%d2            // program complete (data matches expected value)?
    beq     3f                  // ... yes, done with this word
    dbf     %d3, 2b             // ... no, keep polling

    fatal32 %a1,err_program     // program timed out
3:
    subq.l  #4,%a1
    subq.l  #4,%a2
    cmp.l   %a4,%a1
    bge     1b

    mputs   msg_done
    rts


msg_start:      .asciz "\nIP940 ROM flash tool rel 1\r\n"
msg_srec:       .asciz "Ready for S-records..."
msg_erase:      .asciz "Erasing sectors...\r\n"
msg_program:    .asciz "Writing..."
msg_verify:     .asciz "Verifying..."
msg_done:       .asciz "done\r\n"
msg_reset:      .asciz "Reset to run uploaded program.\r\n"
err_vendor:     .asciz " flash vendor not supported"
err_device:     .asciz " flash device not supported"
err_srec_unsup: .asciz " invalid S-record type"
err_srec_sum:   .asciz " S-record checksum mismatch"
err_srec_len:   .asciz " invalid S-record length"
err_srec_addr:  .asciz " invalid S-record address"
err_loader_len: .asciz " loader is too large for sector 0"
err_flash_addr: .asciz " program must start at 0x0000 or 0x40000"
err_flash_len:  .asciz " program is empty"
err_erase:      .asciz " flash erase failed"
err_program:    .asciz " flash program failed"

dbg_addr:       .asciz " address\r\n"
dbg_data:       .asciz " data\r\n"
dbg_tic:        .asciz " -\r\n"

    .align  4

    .bss
flash_buf:
    ds.b        FLASH_SIZE