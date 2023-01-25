
format.bin: format.asm include/bios.inc include/kernel.inc
	asm02 -L -b format.asm

clean:
	-rm -f format.lst
	-rm -f format.bin

