
format.bin: format.asm include/bios.inc include/kernel.inc
	asm02 -L -b format.asm
	rm -f format.build

clean:
	rm -f format.lst
	rm -f format.bin

