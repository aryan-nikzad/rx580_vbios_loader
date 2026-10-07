Please consider using this: https://github.com/aryan-nikzad/rx580_vbios_loader_git , this one here is not maintained anymore












RX 580 vBIOS loader  -  UEFI app that brings up an AMD Polaris GPU whose SPI ROM chip is dead
=============================================================================================

QUICK START (Linux, Ubuntu-style /boot/efi)
  1. Keep the card's BIOS switch on the DEAD chip.
  2. sudo sh install_linux.sh        (copies the loader + vbioses\ to the EFI partition and makes it the first boot entry)
  3. Reboot. Menu appears, AUTO starts after 5 s, then your normal OS boots.
  Without Linux: copy vbios_loader.efi and the vbioses\ folder to the same folder on the EFI partition and start the .efi
  first (UEFI shell, GRUB "chainloader", or a firmware boot entry).

WHAT IT DOES
  - Runs the ROM's ASIC_Init tables with a built-in AtomBIOS interpreter (atomlib/atom.c, the Linux amdgpu code, MIT,
    (c) AMD) that has timeouts, so it never hangs.
  - EMULATES THE CHIP'S SPI READ PORT AND COPY ENGINE FROM THE ROM FILE (the key fix, see below).
  - Publishes the ROM as ACPI VFCT + PciIo->RomImage so Linux finds a vBIOS.
  - Sets BIOS_SCRATCH_7 "init complete" (Linux then skips POST) and makes sure the SMC does not look running (Linux would
    otherwise do a "PCI CONFIG reset" and throw the init away).
  - If the GPU is already initialised and trained (e.g. the working chip is selected) it leaves the GPU alone.

THE KEY FINDING (why a dead ROM chip breaks everything)
  A full ROM dump is 256 KB but the BIOS images only fill ~119 KB. At offset 0x37000 sits the memory-controller (MC)
  microcode: [version, n_io=24, ucode_dwords=0x1F87, total][24 x (IO_DEBUG index,value)][ucode] - byte-identical to
  linux-firmware's polaris10_mc.bin payload. During ASIC_Init (table MC_SEQ_Control):
     SMC_IND[0xC0600010 ROM_INDEX] = 0x37000
     52 x read SMC_IND[0xC0600014 ROM_DATA]  -> header + the 24 pairs, written to MC_SEQ_IO_DEBUG (0xA91/0xA92)
     regs 0xC064=0x20C (src: ROM_DATA stream) 0xC066=0x28CC (dst: MC_SEQ_SUP_PGM) 0xC0E8=0x7C007E1C (count 0x7E1C)
        -> a hardware copy engine streams the 32,284-byte ucode from the chip into MC_SEQ_SUP_PGM
     MC_SEQ_SUP_CNTL = 8, 4, 1 -> the sequencer starts, trains the GDDR5, MC_SEQ_MISC9 -> 11000707
  With a dead chip every one of those reads/copies returns garbage, so training never finishes (MISC9 stays 0000FF07).
  The loader serves ROM_INDEX/ROM_DATA and the copy engine from the ROM FILE. ROM files must therefore be FULL 256 KB
  dumps. If a ROM file has no MC block, the block from another ROM file is used (works best for the same ucode version).

MENU KEYS
  UP/DOWN+ENTER run one ROM | AUTO (default, 5 s) tries ROMs in file-name order, remembers the one that works
  V VFCT-only | R forget remembered ROM | ESC skip | E engine (built-in interpreter / firmware GOP driver)
  F force init even if the GPU already looks initialised | P register snapshot after init (diagnostic, can freeze the PC)
  D dump all GPU registers (+ MC IO_DEBUG) to \regdump_memXXXXXXXX.bin on the EFI partition

IF SOMETHING GOES WRONG
  \loader_trace.txt (EFI partition) is flushed after every line: after a hard freeze its last line is where it stopped.
  POST codes on port 0x80 (Q-Code display): 10 ROM start, 11 GPU found, 12 VFCT, 20 ASIC_Init, 21 ROM_INDEX set,
  22/23 copy engine start/done, 30 stuck poll handled, 40 ASIC_Init done, 50 snapshot, 60 prepare_for_os, 70 success,
  Dx register-dump chunk, E0 IO_DEBUG dump.
  Reference values of a trained card (from a working chip): MC_SEQ_MISC9 11000707, SUP_CNTL 27800001, CMD 00030000,
  STATUS_M 00010300, TRAIN_WAKEUP_CNTL C00000E0, MC_SEQ_SUP_PGM 0003FF00.

ROMS (vbioses\)
  000_YOUR_ORIGINAL_*.rom  = the dump from the card itself (XFX 1682:c580, Samsung SMD2, 113-58085SMD2-M81), sorts first.
  00a..00g = your other backups, 01..24 = ROMs from other RX 580 cards (trimmed: no MC block).
  Do not trim ROM files. A freeze while dumping registers: the VCE block (regs 0x8000-0x8FFF) is skipped on purpose.

BUILD (needs gnu-efi):  make        (pe/ files: python3 tools/extract_pe.py rom out.efi, needs pip uefi_firmware)
