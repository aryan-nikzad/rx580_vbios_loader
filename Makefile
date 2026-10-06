# make   -> vbios_loader.efi   (PE1..3 = output of: python3 tools/extract_pe.py romN.rom peN.efi)
ROM1 ?= roms/xfx_xxx_8gb_samsung.rom
ROM2 ?= roms/xfx_xxx_8gb_hynix_w90.rom
ROM3 ?= roms/xfx_xxx_4gb.rom
PE1 ?= pe/xfx_xxx_8gb_samsung.efi
PE2 ?= pe/xfx_xxx_8gb_hynix_w90.efi
PE3 ?= pe/xfx_xxx_4gb.efi
CFLAGS = -I/usr/include/efi -I/usr/include/efi/x86_64 -fpic -fshort-wchar \
 -fno-stack-protector -fno-stack-check -mno-red-zone -maccumulate-outgoing-args \
 -ffreestanding -Wall -DEFI_FUNCTION_WRAPPER -DROM1='"$(ROM1)"' -DROM2='"$(ROM2)"' -DROM3='"$(ROM3)"' -DPE1='"$(PE1)"' -DPE2='"$(PE2)"' -DPE3='"$(PE3)"'
vbios_loader.efi: vbios_loader.so
	objcopy -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
	 -j .rel -j .rela -j '.rel*' -j '.rela*' -j .reloc \
	 --target=efi-app-x86_64 $< $@
vbios_loader.so: vbios_loader.o atomlib/atom.o atom_support.o
	ld -shared -Bsymbolic -L/usr/lib -T/usr/lib/elf_x86_64_efi.lds /usr/lib/crt0-efi-x86_64.o \
	 vbios_loader.o atomlib/atom.o atom_support.o -o $@ -lefi -lgnuefi
vbios_loader.o: vbios_loader.c $(ROM1) $(ROM2) $(ROM3) $(PE1) $(PE2) $(PE3)
	gcc $(CFLAGS) -c vbios_loader.c -o $@
atomlib/atom.o: atomlib/atom.c atomlib/amdgpu.h
	gcc -O2 -fpic -fshort-wchar -fno-stack-protector -mno-red-zone -ffreestanding -w -Iatomlib/inc -Iatomlib -include atomlib/amdgpu.h -c $< -o $@
atom_support.o: atom_support.c
	gcc $(CFLAGS) -c $< -o $@
clean:; rm -f *.o atomlib/*.o *.so vbios_loader.efi

# decompressed GOP driver for a ROM (needs: pip install uefi_firmware)
pe/%.efi: roms/%.rom tools/extract_pe.py
	python3 tools/extract_pe.py $< $@
