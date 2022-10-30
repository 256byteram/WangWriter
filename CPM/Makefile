all: cbios.asm cpm22.asm bootsector.asm diskheader.cim
	zmac --od . --oo cim -l -m bootsector.asm > bootsector.lst
	zmac -8 --dri --od . --oo cim -l -m cbios.asm > cbios.lst
	zmac -8 --dri --od . --oo cim -l -m cpm22.asm > cpm22.lst
	cat diskheader.cim bootsector.cim cpm22.cim cbios.cim > bootblock.bin
	dd if=/dev/zero of=disk.img bs=256 count=1280
	mkfs.cpm -f wang -b bootblock.bin disk.img
	cpmcp -f wang disk.img ~/work/Weirdos/Zork/ZORK1.* 0:
	cpmcp -f wang disk.img ~/work/Z80SBC/cpm22-b/*.com 0:
	cpmcp -f wang disk.img ~/work/Weirdos/MBASIC.COM 0:
	cpmcp -f wang disk.img ~/work/Weirdos/STARTREK.BAS 0:

	
.PHONY: clean

clean:
	rm -f $(PROJECT_NAME)

