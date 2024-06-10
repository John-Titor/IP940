#
# Build the IP940 bootrom and tools.
#

TOOLPREFIX		 = m68k-elf-
CC			 = $(TOOLPREFIX)gcc
OBJCOPY			 = $(TOOLPREFIX)objcopy
BUILDDIR		 = build
GITHASH			:= $(shell git describe --always --dirty=-modified)

CFLAGS			 = -Os \
			   -m68040 \
			   -DGITHASH=$(GITHASH) \
			   -ffreestanding \
			   -nostartfiles \
			   -nostdlib

INCLUDES		 = defs.h

BOOTROM_SRCS		 = bootrom.S utils.S
BOOTROM_ELF		 = $(BUILDDIR)/bootrom.elf
BOOTROM_SREC		 = $(BUILDDIR)/bootrom.s19
BOOTROM_BIN		 = $(BUILDDIR)/bootrom.bin
BOOTROM_PARTS		 = $(BUILDDIR)/bootrom0.bin \
			   $(BUILDDIR)/bootrom1.bin \
			   $(BUILDDIR)/bootrom2.bin \
			   $(BUILDDIR)/bootrom3.bin

BOOT_SRCS		 = ip940_boot.c ip940_lib.c
BOOT_DEPS		 = ip940_lib.h bootrom.ld
BOOT_ELF		 = $(BUILDDIR)/boot.elf
BOOT_SREC		 = $(BUILDDIR)/boot.s19
BOOT_BIN		 = $(BUILDDIR)/boot.bin
BOOT_PARTS		 = $(BUILDDIR)/boot0.bin \
			   $(BUILDDIR)/boot1.bin \
			   $(BUILDDIR)/boot2.bin \
			   $(BUILDDIR)/boot3.bin

ROM_APP_SRCS		 = rom_app.S utils.S
ROM_APP_ELF		 = $(BUILDDIR)/rom_app.elf
ROM_APP_SREC		 = $(BUILDDIR)/rom_app.s19

FLASHER_SRCS		 = flasher.S utils.S
FLASHER_SREC		 = $(BUILDDIR)/flasher.s19

TEST_SRCS		 = test.S utils.S
TEST_SREC		 = $(BUILDDIR)/test.s19


.PHONY: all
#.INTERMEDIATE: $(BOOTROM_BIN) $(BOOTROM_ELF) $(ROM_APP_ELF)
all: $(BOOTROM_PARTS) $(BOOTROM_SREC) $(BOOT_PARTS) $(BOOT_SREC) $(FLASHER_SREC) $(ROM_APP_SREC) $(TEST_SREC)

$(BUILDDIR)/%.s19: $(BUILDDIR)/%.elf
	$(OBJCOPY) -O srec --srec-forceS3 $< $@

$(BUILDDIR)/%.bin: $(BUILDDIR)/%.elf
	$(OBJCOPY) -O binary $< $@

################################################################################

$(BOOTROM_PARTS): $(BOOTROM_BIN)
	$(OBJCOPY) -I binary --byte=0 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/bootrom0.bin
	$(OBJCOPY) -I binary --byte=1 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/bootrom1.bin
	$(OBJCOPY) -I binary --byte=2 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/bootrom2.bin
	$(OBJCOPY) -I binary --byte=3 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/bootrom3.bin

$(BOOTROM_ELF): $(BOOTROM_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,-Ttext=0 $(BOOTROM_SRCS)

################################################################################

$(BOOT_PARTS): $(BOOT_BIN)
	$(OBJCOPY) -I binary --byte=0 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/boot0.bin
	$(OBJCOPY) -I binary --byte=1 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/boot1.bin
	$(OBJCOPY) -I binary --byte=2 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/boot2.bin
	$(OBJCOPY) -I binary --byte=3 --interleave=4 --interleave-width=1 $< $(BUILDDIR)/boot3.bin

$(BOOT_ELF): $(BOOT_SRCS) $(BOOT_DEPS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -T bootrom.ld $(BOOT_SRCS)

################################################################################

$(ROM_APP_ELF): $(ROM_APP_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,-Ttext=0x00004000 $(ROM_APP_SRCS)

$(FLASHER_SREC): $(FLASHER_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,--oformat,srec -Wl,-Ttext=0x01000000 $(FLASHER_SRCS)

$(TEST_SREC): $(TEST_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,--oformat,srec -Wl,-Ttext=0x01000000 $(TEST_SRCS)

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
