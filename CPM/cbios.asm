; CBIOS for WangWriter
;
; Portions by Digital Research
;
	maclib Z80
	maclib DISKDEF

;	utility macro to compute sector mask
smask	macro	hblk
;;	compute log2(hblk), return @x as result
;;	(2 ** @x = hblk on return)
@y	set	hblk
@x	set	0
;;	count right shifts of @y until = 1
	rept	8
	if	@y = 1
	exitm
	endif
;;	@y is not 1, shift right one position
@y	set	@y shr 1
@x	set	@x + 1
	endm
	endm

msize	equ	48		;cp/m version memory size in kilobytes
;
;	"bias" is address offset from 3400h for memory systems
;	than 16k (referred to as"b" throughout the text)
;
bias	equ	(msize-20)*1024
ccp	equ	3400h+bias	;base of ccp
bdos	equ	ccp+806h	;base of bdos
bios	equ	ccp+1600h	;base of bios
cdisk	equ	0004h		;current disk number 0=a,... l5=p
iobyte	equ	0003h		;intel i/o byte
;
	org	bios		;origin of this program
nsects	equ	($-ccp)/128	;warm start sector count

buffer	equ	0

consd	equ	buffer	; console data
conss	equ	8	; console status
consc	equ	8	; console control

rxd	equ	1	; receive flag mask
txd	equ	2	; transmit flag mask
devack	equ	4	; device changed flag

bs	equ	8
cr	equ	13
lf	equ	10

fdcctrl	equ	0Ah	; Control port (TC)
fdcdata	equ	0Bh	; Data port
fdcstat	equ	0Ch	; Status port
irqstat	equ	031h	; IRQ status fro FDC

porta	equ	030h	; PORTA for keyboard
portb	equ	031h	; PORTB for disk and keyboard control
cmda	equ	032h	; Command for PORTA
cmdb	equ	033h	; Command for PORTB

blksiz	equ	2048		;CP/M allocation size
hstsiz	equ	256		;host disk sector size
hstsph	equ	16		;sectors per head
hsthpc	equ	2		;heads per cylinder
hstspt	equ	hstsph*hsthpc	;host disk sectors/trk
hstblk	equ	hstsiz/128	;CP/M sects/host buff
cpmspt	equ	hstblk*hstspt	;CP/M sectors/track
secmsk	equ	hstblk-1	;sector mask
	smask	hstblk		;compute sector mask
secshf	equ	@x		;log2(hstblk)
;
wrall:	equ	0		;write to allocated
wrdir:	equ	1		;write to directory
wrual:	equ	2		;write to unallocated


;
;	jump vector for individual subroutines
;
	jmp	boot	;cold start
wboote:	jmp	wboot	;warm start
	jmp	const	;console status
	jmp	conin	;console character in
	jmp	conout	;console character out
	jmp	list	;list character out
	jmp	punch	;punch character out
	jmp	reader	;reader character out
	jmp	home	;move head to home position
	jmp	seldsk	;select disk
	jmp	settrk	;set track number
	jmp	setsec	;set sector number
	jmp	setdma	;set dma address
	jmp	read	;read disk
	jmp	write	;write disk
	jmp	listst	;return list status
	jmp	sectran	;sector translate


;
;	end of fixed tables
;
;	individual subroutines to perform each function
boot:	lxi	sp, stack
	mvi	a, 01h		;CRT is the default device
	sta	iobyte		;clear the iobyte
	xra	a		;zero in the accum
	sta	cdisk		;select disk zero
	sta	hstact		;host buffer inactive
	sta	unacnt		;clear unalloc count
	lxi	d,mesg		; Signon message
	call	print
	jmp	gocpm		;initialize and go to cp/m
;
wboot:	;simplest case is to read the disk until all sectors loaded
	lxi	sp, 80h		;use space below buffer for stack
	mvi	c, 0		;select disk 0
	call	seldsk
	call	home		;go to track 00
;
	mvi	b, nsects	;b counts * of sectors to load
	mvi	c, 0		;c has the current track number
	mvi	d, 2		;d has the next sector to read
;	note that we begin by reading track 0, sector 2 since sector 1
;	contains the cold start loader, which is skipped in a warm start
	lxi	h, ccp		;base of cp/m (initial load point)
	mvi	c, 0	; start at sector 1, head 0, track 0
	lxi	d, 1
	mvi	b, (0FFFFh-ccp)/hstsiz
rdloop	mov	a, e
	sta	hstsec
	mov	a, d
	sta	hsttrk
	mvi	a, 0
	sta	hsttrk+1
	push	bc
	push	de
	call	readhst
	pop	de
	pop	bc
	dcr	b
	jz	gocpm	; Go to CP/M when done
	inr	e
	mvi	a, hstspt
	cmp	e
	jnz	rdloop
	mvi	e, 0
	inr	d
	jp	rdloop
;
;	end of	load operation, set parameters and go to cp/m
gocpm:
	mvi	a, 0c3h		;c3 is a jmp instruction
	sta	0		;for jmp to wboot
	lxi	h, wboote	;wboot entry point
	shld	1		;set address field for jmp at 0
;
	sta	5		;for jmp to bdos
	lxi	h, bdos		;bdos entry point
	shld	6		;address field of Jump at 5 to bdos
;
	lxi	b, 80h		;default dma address is 80h
	call	setdma
;
	;ei			;enable the interrupt system
	lda	cdisk		;get current disk number
	mov	c, a		;send to the ccp
	jmp	ccp		;go to cp/m for further processing
;
;
; I/O handlers
; 

; Console status
const:	xra	a
	ret

; Console in
conin	jr	conin
	ret

; Console out
conout	mvi	a, cr
	cmp	c
	jrz	concr
	mvi	a, lf
	cmp	c
	jrz	conlf
	mvi	a, ' '
	cmp	c
	jrnz	conout1
	mvi	c, 0		; Blank for space
conout1	push	d
	lhld	cursor
	push	h
	lxi	d, 0E000h	; CRT base address
	dad	d
	mov	m, c
	pop	h
	pop	d
	inx	h
	shld	cursor
	mvi	a, 80		; 80 columns
	cmp	l
	rnz
	mvi	l, 0		; Newline
	inr	h
	shld	cursor
	jr	scroll

concr:	lhld	cursor
	xra	a		; Move cursor to start of line
	mov	l, a
	shld	cursor
	ret
	
conlf:	lhld	cursor		; Newline and scroll
	inr	h
	shld	cursor

scroll:	mvi	a, 24
	cmp	h
	rnc

	mvi	h, 23		; 0..22
	shld	cursor
	mvi	a, 0E0h
scrll:	push	a
	mov	d, a
	mvi	e, 0
	inr	a
	mov	h, a
	mvi	l, 0
	lxi	b, 80
	ldir
	pop	a
	inr	a
	cpi	0F8h
	jrnz	scrll
	
	xra	a		; Last line blanked
	lxi	h, 0F700h
	mvi	b, 80
endlin:	mov	m, a
	inx	h
	djnz	endlin
	ret
	


; List out
list:	ret

; List status
listst	xra	a
	ret

; Punch out
punch	ret

; Reader in
reader	mvi	a, 01Ah		; Return EOF for reader device
	ret


cursor	dw	0		; Cursor position
;
;
;	i/o drivers for the disk follow
;	for now, we will simply store the parameters away for use
;	in the read and write	subroutines
;
	;home the selected disk
home:	lda	hstwrt	;check for pending write
	ora	a
	jnz	homed
	sta	hstact	;clear host active flag
homed:	lxi	b, 0
	call	settrk
	ret
;
seldsk:
	;select disk
	mov	a,c		;selected disk number
	sta	sekdsk		;seek disk number
	mov	l,a		;disk number to HL
	mvi	h,0
	rept	4		;multiply by 16
	dad	h
	endm
	lxi	d,dpbase	;base of parm block
	dad	d		;hl=.dpb(curdsk)
	ret
	;
settrk:	;set track given by register bc
	;mov	h,b
	mvi	h,0
	mov	l,c
	shld	sektrk
	ret
;
setsec:
	;set sector given by register c 
	mov	a,c
	sta	seksec		;sector to seek
	;jmp	phex
	ret

setdma:
	;set dma address given by BC
	mov	h,b
	mov	l,c
	shld	dmaadr
	ret
;
sectran:
	;translate sector number BC
	mov	h,b
	mov	l,c
	ret
;
;*****************************************************
;*                                                   *
;*	The READ entry point takes the place of      *
;*	the previous BIOS defintion for READ.        *
;*                                                   *
;*****************************************************
read:
	;read the selected CP/M sector
	xra	a
	sta	unacnt
	mvi	a,1
	sta	readop		;read operation
	sta	rsflag		;must read data
	mvi	a,wrual
	sta	wrtype		;treat as unalloc
	jmp	rwoper		;to perform the read
;
;*****************************************************
;*                                                   *
;*	The WRITE entry point takes the place of     *
;*	the previous BIOS defintion for WRITE.       *
;*                                                   *
;*****************************************************
write:
	;write the selected CP/M sector
	xra	a		;0 to accumulator
	sta	readop		;not a read operation
	mov	a,c		;write type in c
	sta	wrtype
	cpi	wrual		;write unallocated?
	jnz	chkuna		;check for unalloc
;
;	write to unallocated, set parameters
	mvi	a,blksiz/128	;next unalloc recs
	sta	unacnt
	lda	sekdsk		;disk to seek
	sta	unadsk		;unadsk = sekdsk
	lhld	sektrk
	shld	unatrk		;unatrk = sectrk
	lda	seksec
	sta	unasec		;unasec = seksec
;
chkuna:
	;check for write to unallocated sector
	lda	unacnt		;any unalloc remain?
	ora	a
	jz	alloc		;skip if not
;
;	more unallocated records remain
	dcr	a		;unacnt = unacnt-1
	sta	unacnt
	lda	sekdsk		;same disk?
	lxi	h,unadsk
	cmp	m		;sekdsk = unadsk?
	jnz	alloc		;skip if not
;
;	disks are the same
	lxi	h,unatrk
	call	sektrkcmp	;sektrk = unatrk?
	jnz	alloc		;skip if not
;
;	tracks are the same
	lda	seksec		;same sector?
	lxi	h,unasec
	cmp	m		;seksec = unasec?
	jnz	alloc		;skip if not
;
;	match, move to next sector for future ref
	inr	m		;unasec = unasec+1
	mov	a,m		;end of track?
	cmp	cpmspt		;count CP/M sectors
	jc	noovf		;skip if no overflow
;
;	overflow to next track
	mvi	m,0		;unasec = 0
	lhld	unatrk
	inx	h
	shld	unatrk		;unatrk = unatrk+1
;
noovf:
	;match found, mark as unnecessary read
	xra	a		;0 to accumulator
	sta	rsflag		;rsflag = 0
	jmp	rwoper		;to perform the write
;
alloc:
	;not an unallocated record, requires pre-read
	xra	a		;0 to accum
	sta	unacnt		;unacnt = 0
	inr	a		;1 to accum
	sta	rsflag		;rsflag = 1
;
;*****************************************************
;*                                                   *
;*	Common code for READ and WRITE follows       *
;*                                                   *
;*****************************************************
rwoper:
	;enter here to perform the read/write
	xra	a		;zero to accum
	sta	erflag		;no errors (yet)
	lda	seksec		;compute host sector
	rept	secshf
	ora	a		;carry = 0
	rar			;shift right
	endm
	sta	sekhst		;host sector to seek
;
;	active host sector?
	lxi	h,hstact	;host active flag
	mov	a,m
	mvi	m,1		;always becomes 1
	ora	a		;was it already?
	jz	filhst		;fill host if not
;
;	host buffer active, same as seek buffer?
	lda	sekdsk
	lxi	h,hstdsk	;same disk?
	cmp	m		;sekdsk = hstdsk?
	jnz	nomatch
;
;	same disk, same track?
	lxi	h,hsttrk
	call	sektrkcmp	;sektrk = hsttrk?
	jnz	nomatch
;
;	same disk, same track, same buffer?
	lda	sekhst
	lxi	h,hstsec	;sekhst = hstsec?
	cmp	m
	jz	match		;skip if match
;
nomatch:
	;proper disk, but not correct sector
	lda	hstwrt		;host written?
	ora	a
	cnz	writehst	;clear host buff
;
filhst:
	;may have to fill the host buffer
	lda	sekdsk
	sta	hstdsk
	lhld	sektrk
	shld	hsttrk
	lda	sekhst
	sta	hstsec
	lda	rsflag		;need to read?
	ora	a
	cnz	readhst		;yes, if 1
	xra	a		;0 to accum
	sta	hstwrt		;no pending write
;
match:
	;copy data to or from buffer
	lda	seksec		;mask buffer number
	ani	secmsk		;least signif bits
	mov	l,a		;ready to shift
	mvi	h,0		;double count
	rept	7		;shift left 7
	dad	h
	endm
;	hl has relative host buffer address
	lxi	d,hstbuf
	dad	d		;hl = host address
	xchg			;now in DE
	lhld	dmaadr		;get/put CP/M data
	mvi	c,128		;length of move
	lda	readop		;which way?
	ora	a
	jnz	rwmove		;skip if read
;
;	write operation, mark and switch direction
	mvi	a,1
	sta	hstwrt		;hstwrt = 1
	xchg			;source/dest swap
;
rwmove:
	;C initially 128, DE is source, HL is dest
	ldax	d		;source character
	inx	d
	mov	m,a		;to dest
	inx	h
	dcr	c		;loop 128 times
	jnz	rwmove
;
;	data has been moved to/from host buffer
	lda	wrtype		;write type
	cpi	wrdir		;to directory?
	lda	erflag		;in case of errors
	rnz			;no further processing
;
;	clear host buffer for directory write
	ora	a		;errors?
	rnz			;skip if so
	xra	a		;0 to accum
	sta	hstwrt		;buffer written
	call	writehst
	lda	erflag
	ret
;
;*****************************************************
;*                                                   *
;*	Utility subroutine for 16-bit compare        *
;*                                                   *
;*****************************************************
sektrkcmp:
	;HL = .unatrk or .hsttrk, compare with sektrk
	xchg
	lxi	h,sektrk
	ldax	d		;low byte compare
	cmp	m		;same?
	rnz			;return if not
;	low bytes equal, test high 1s
	inx	d
	inx	h
	ldax	d
	cmp	m	;sets flags
	ret
;
;*****************************************************
;*                                                   *
;*	WRITEHST performs the physical write to      *
;*	the host disk, READHST reads the physical    *
;*	disk.					     *
;*                                                   *
;*****************************************************
writehst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. write "hstsiz" bytes
	;from hstbuf and return error flag in erflag.
	;return erflag non-zero if error
	ora	0FFh
	sta	erflag
	ret

;
readhst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. read "hstsiz" bytes
	;into hstbuf and return error flag in erflag.
	;lxi	d, crlf
	;call	print

	call	seektrk
	
	call	fdcwait
	mvi	a, 046h		; Read sector MFM
	call	fdcio
	call	dchrn		; Drive C H R N

	; Main read loop
	lxi	b, fdcdata	; B = 0 C = port
	lxi	h, hstbuf
readl:	in	irqstat
	add	a
	jrc	fdcret
	jp	p,readl
	ini
	jrnz	readl
	call	fdctc		; Send TC

fdcret	call	fdcio
	ani	0D8h		; Interested in bits 7,6,4,3
	mov	b, a
	call	fdcio		; ST1
	ora	b
	mov	b, a
	call	fdcio		; ST2
	ani	03Fh		; Interested in bits 5..0
	ora	b
	mov	b, a
	
	call	fdcio		; C
	call	fdcio		; H
	call	fdcio		; R
	call	fdcio		; N
	
	mov	a, b
	sta	erflag
	ret	


seektrk:
	call	fdcwait
	mvi	a, 00Fh		; SEEK
	call	fdcio
	lda	hstdsk		; Current disk
	mov	b, a
	lda	hsttrk
	ani	020h		; high byte of 0..31 is side
	rar			; Move bit D4 to D2
	rar
	rar
	ora	a, b
	call	fdcio
	lda	hsttrk		; Current track
	call	fdcio
	ret

dchrn:	lda	hstdsk		; Disk 1..2
	mov	b, a
	lda	hstsec
	rar			; Move bit D4 to D2
	rar
	ani	004h
	ora	a, b
	call	fdcio
	
	lda	hsttrk		; Cylinder
	call	fdcio
	
	lda	hstsec
	rar			; D4 to D0
	rar
	rar
	rar
	ani	1
	call	fdcio
	
	lda	hstsec		; Record
	ani	00Fh		; 
	inr	a		; 1..16
	call	fdcio
	
	mvi	a, 1		; 256 bytes per sector
	call	fdcio
	
	mvi	a, 16		; EOT
	call	fdcio
	
	mvi	a, 018h		; Gap Length
	call	fdcio
	
	xra	a		; DTL
	call	fdcio
	ret
	

fdcwait:
	in	fdcstat
	and	0C0h
	cpi	080h
	rz
	in	fdcdata
	jr	fdcwait

fdcio:
	push	psw
fdcwl1:	in	fdcstat
	bit	7,a
	jrz	fdcwl1
	bit	6,a
	jrnz	fdcio1
	pop	psw
	out	fdcdata
	;jmp	phex
	ret
	
fdcio1:	pop	psw
	in	fdcdata
	;push	psw
	;call	phex
	;pop	psw
	ret
	
fdctc:	mvi	a, 010h		; Send TC
	out	fdcctrl
	mvi	a, 0
	out	fdcctrl
	ret

	; Print the message at HL
print	ldax	d
	mov	c, a
	inx	d
	ora	a
	rz
	call	conout
	jmp	print

mesg	db	"48k CP/M 2.2"
crlf	db	cr,lf,0


	dw	0,0,0,0,0,0
	dw	0,0,0,0,0,0
	dw	0,0,0,0,0,0
stack:

phex	push	psw
	mvi	c, ' '
	call	conout
	pop	psw
	push	psw		; Will use A twice
	rar			; Shift upper to lower nibble
	rar
	rar
	rar
	call	phex1		; Print it
	pop	psw		; Restore original Acc
phex1	ani	00Fh		; Mask off high nibble
	adi	090h		; Decimal adjust for ASCII
	daa
	aci	040h
	daa
	mov	c, a		; Print it
	jmp	conout
	ret
	
	disks	1
	;      dn,fsc,   lsc,[skf],bls   ,dks,dir,cks,ofs,[0]
	diskdef 0,  1,cpmspt,1    ,blksiz,135,128,128,1
;
;	the remainder of the cbios is reserved uninitialized
;	data area, and does not need to be a Part of the
;	system	memory image (the space must be available,
;	however, between"begdat" and"enddat").
;
sekdsk:	ds	1		;seek disk number
sektrk:	ds	2		;seek track number
seksec:	ds	1		;seek sector number
;
hstdsk:	ds	1		;host disk number
hsttrk:	ds	2		;host track number
hstsec:	ds	1		;host sector number
;
sekhst:	ds	1		;seek shr secshf
hstact:	ds	1		;host active flag
hstwrt:	ds	1		;host written flag
;
unacnt:	ds	1		;unalloc rec cnt
unadsk:	ds	1		;last unalloc disk
unatrk:	ds	2		;last unalloc track
unasec:	ds	1		;last unalloc sector
;
erflag:	ds	1		;error reporting
rsflag:	ds	1		;read sector flag
readop:	ds	1		;1 if read operation
wrtype:	ds	1		;write operation type
dmaadr:	ds	2		;last dma address
hstbuf:	ds	hstsiz		;host buffer
	endef
	
	rept	(0C1C0h - $)
	db	0
	endm
	
	end