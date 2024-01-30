#
# Build the IP940 bootrom and tools.
#

TOOLPREFIX		 = m68k-elf-
CC			 = $(TOOLPREFIX)gcc
OBJCOPY			 = $(TOOLPREFIX)objcopy
BUILDDIR		 = build

CFLAGS			 = -m68040 \
			   -ffreestanding \
			   -nostartfiles \
			   -nostdlib \
			   -e start

INCLUDES		 = defs.h

LOADER_SRCS		 = loader.S utils.S
LOADER_ELF		 = $(BUILDDIR)/loader.elf
LOADER_SREC		 = $(BUILDDIR)/loader.s19
LOADER_BIN		 = $(BUILDDIR)/loader.bin
LOADER_PARTS		 = $(BUILDDIR)/byte0.bin \
			   $(BUILDDIR)/byte1.bin \
			   $(BUILDDIR)/byte2.bin \
			   $(BUILDDIR)/byte3.bin

FLASHER_SRCS		 = flasher.S utils.S
FLASHER_SREC		 = $(BUILDDIR)/flasher.s19

ROM_APP_SRCS		 = rom_app.S utils.S
ROM_APP_ELF		 = $(BUILDDIR)/rom_app.elf
ROM_APP_SREC		 = $(BUILDDIR)/rom_app.s19


.PHONY: all
all: $(LOADER_PARTS) $(LOADER_SREC) $(FLASHER_SREC) $(ROM_APP_SREC)

$(LOADER_PARTS): $(LOADER_BIN)
	$(OBJCOPY) -I binary --byte=0 --interleave=4 --interleave-width=1 $(LOADER_BIN) $(BUILDDIR)/byte0.bin
	$(OBJCOPY) -I binary --byte=1 --interleave=4 --interleave-width=1 $(LOADER_BIN) $(BUILDDIR)/byte1.bin
	$(OBJCOPY) -I binary --byte=2 --interleave=4 --interleave-width=1 $(LOADER_BIN) $(BUILDDIR)/byte2.bin
	$(OBJCOPY) -I binary --byte=3 --interleave=4 --interleave-width=1 $(LOADER_BIN) $(BUILDDIR)/byte3.bin

$(LOADER_SREC): $(LOADER_ELF)
	$(OBJCOPY) -O srec --srec-forceS3 $(LOADER_ELF) $@

$(LOADER_BIN): $(LOADER_ELF)
	$(OBJCOPY) -O binary $(LOADER_ELF) $@

$(LOADER_ELF): $(LOADER_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,-Ttext=0 $(LOADER_SRCS)

$(FLASHER_SREC): $(FLASHER_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,--oformat,srec -Wl,-Ttext=0x01000000 $(FLASHER_SRCS)

$(ROM_APP_SREC): $(ROM_APP_ELF)
	$(OBJCOPY) -O srec --srec-forceS3 $(ROM_APP_ELF) $@

$(ROM_APP_ELF): $(ROM_APP_SRCS) $(INCLUDES)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -Wl,-Ttext=0x00004000 $(ROM_APP_SRCS)

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
