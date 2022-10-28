# Your project name. Will be the name of the executable

all: cbios.asm diskheader.cim bootsector.cim cpm22.cim cbios.cim
	zmac  --od . --oo cim -l -m bootsector.asm > bootsector.lst
	zmac  -8 --dri --od . --oo cim -l -m cbios.asm > cbios.lst
	cat diskheader.cim bootsector.cim cpm22.cim cbios.cim > bootblock.bin
	mkfs.cpm -f wang -b bootblock.bin disk.img
	cpmcp -f wang disk.img ~/work/Weirdos/Zork/ZORK1.* 0:
	cpmcp -f wang disk.img ~/work/Z80SBC/cpm22-b/*.com 0:
	cpmcp -f wang disk.img ~/work/Weirdos/MBASIC.COM 0:
	cpmcp -f wang disk.img ~/work/Weirdos/STARTREK.BAS 0:

	
.PHONY: clean

clean:
	rm -f $(PROJECT_NAME)

