
all: format.bin

lbr: format.lbr

clean:
	rm -f format.lst
	rm -f format.bin
	rm -f format.lbr

format.bin: format.asm include/bios.inc include/kernel.inc
	asm02 -L -b format.asm
	rm -f format.build

format.lbr: format.bin
	rm -f format.lbr
	lbradd format.lbr format.bin

