* yow - Print a quotation from Zippy the Pinhead.
*
* Itagaki Fumihiko 23-Jun-91  Create.
*
* Usage: yow [ <ファイル> ... ]

.include doscall.h
.include iocscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref isspace
.xref tfopen
.xref fgetc
.xref mulul
.xref irandom
.xref init_irandom

STACKSIZE	equ	256
RANDOM_POOLSIZE	equ	20		*  1..63

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack(pc),a7

		IOCS	_ONTIME
		moveq	#RANDOM_POOLSIZE,d1
		bsr	init_irandom

		lea	1(a2),a0
		bsr	DecodeHUPAIR
		move.w	d0,d1				*  D1.W : 引数の数
		bne	select_file

		lea	default_file(pc),a0
		bra	try_open

select_file:
		bsr	irandom
		lsl.w	#1,d0
		mulu	d1,d0
		swap	d0
		bra	skipargs_start
skipargs_loop:
		tst.b	(a0)+
		bne	skipargs_loop
skipargs_start:
		dbra	d0,skipargs_loop
try_open:
		lea	msg_open_fail(pc),a1
		moveq	#0,d0				*  読み込みモードで
		bsr	tfopen				*  ファイルをオープンする
		move.l	d0,d2				*  D2.W : ファイル・ハンドル
		bmi	error

		lea	msg_seek_fail(pc),a1
		move.w	#2,-(a7)
		clr.l	-(a7)
		move.w	d2,-(a7)
		DOS	_SEEK				*  ファイルのサイズを得る
		addq.l	#8,a7
		move.l	d0,d3				*  D3.L : ファイルのサイズ
		bmi	error
retry:
		bsr	irandom
		lsl.w	#1,d0
		move.l	d3,d1
		bsr	mulul
		move.w	d1,d0
		swap	d0
		lea	msg_seek_fail(pc),a1
		clr.w	-(a7)
		move.l	d0,-(a7)
		move.w	d2,-(a7)
		DOS	_SEEK
		addq.l	#8,a7
		tst.l	d0
		bmi	error
find_sep:
		move.w	d2,d0
		bsr	fgetc
		bmi	retry

		tst.b	d0
		bne	find_sep
find_nonspace:
		move.w	d2,d0
		bsr	fgetc
		bmi	retry

		bsr	isspace
		beq	find_nonspace
output:
		cmp.b	#LF,d0
		bne	output1

		bsr	put_newline
		bra	continue

output1:
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
continue:
		move.w	d2,d0
		bsr	fgetc
		bmi	done

		tst.b	d0
		bne	output
done:
		bsr	put_newline
		clr.w	-(a7)
		DOS	_EXIT2
*****************************************************************
put_newline:
		move.w	#CR,-(a7)
		DOS	_PUTCHAR
		move.w	#LF,(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		rts
*****************************************************************
error:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		bsr	werror
		movea.l	a1,a0
		bsr	werror
		move.w	#1,-(a7)
		DOS	_EXIT2
*****************************************************************
werror:
		movea.l	a0,a2
werror_1:
		tst.b	(a2)+
		bne	werror_1

		suba.l	a0,a2
		move.l	a2,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## yow 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

default_file:		dc.b	'A:/usr/lib/yowlines',0
msg_myname:		dc.b	'yow: ',0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_seek_fail:		dc.b	': シークできません',CR,LF,0
*****************************************************************
.bss

.xdef irandom_table
.xdef irandom_pool
.xdef irandom_index
.xdef irandom_position
.xdef irandom_poolsize

.even
irandom_table:       ds.w    55
irandom_pool:        ds.w    RANDOM_POOLSIZE
irandom_index:       ds.b    1
irandom_position:    ds.b    1
irandom_poolsize:    ds.b    1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************

.end start
