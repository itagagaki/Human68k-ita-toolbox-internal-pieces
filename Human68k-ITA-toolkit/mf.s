* mf.s
*
* Itagaki Fumihiko 22-Oct-90  Create.
****************************************************************
*  Name
*       mf - print memory free
*
*  Synopsis
*       mf
****************************************************************

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref strcmp
.xref utoa
.xref printfi

STACKSIZE	equ	256

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		move.l	8(a0),d6			*  このメモリブロックの終わり＋１
		sub.l	a0,d6
		sub.l	#16,d6				*  D6.L : 最大の空きメモリの大きさ
		move.l	d6,d7				*  D7.L : 空きメモリの総量
		lea	bsstop(pc),a6
		lea	stack(a6),a7

		st	print_max(a6)
		st	print_total(a6)
		sf	print_all(a6)

		lea	1(a2),a0
		bsr	DecodeHUPAIR
		cmp.w	#1,d0
		bhi	usage
		blo	mf_start

		lea	word_all(pc),a1
		bsr	strcmp
		beq	mf_all

		lea	word_total(pc),a1
		bsr	strcmp
		beq	mf_total

		sf	print_total(a6)
		lea	word_max(pc),a1
		bsr	strcmp
		beq	mf_start

usage:
		move.l	#msg_usage_bot-msg_usage,-(a7)
		pea	msg_usage(pc)
		move.w	#2,-(a7)
		DOS	_WRITE
		move.w	#1,-(a7)
		DOS	_EXIT2

mf_all:
		st	print_all(a6)
mf_total:
		sf	print_max(a6)
mf_start:
		tst.b	print_all(a6)
		beq	get_size_loop

		move.l	d6,d0
		bsr	print1
get_size_loop:
		move.l	#$00ffffff,-(a7)		*  こん限り
		DOS	_MALLOC				*  確保してみる
		addq.l	#4,a7
		sub.l	#$81000000,d0
		move.l	d0,d3				*  D3 : 確保可能な大きさ
		move.l	d0,-(a7)			*  それを
		DOS	_MALLOC				*  確保してみる
		addq.l	#4,a7
		tst.l	d0
		bmi	count_done			*  これ以上確保できない

		cmp.l	d3,d6				*  今確保したブロックが
		bhs	max_ok				*  D6 よりも大きければ

		move.l	d3,d6				*  D6 を更新
max_ok:
		add.l	d3,d7				*  今確保した大きさを D7 に加える
		tst.b	print_all(a6)
		beq	get_size_loop

		move.l	d3,d0
		bsr	print1
		bra	get_size_loop

count_done:
		tst.b	print_max(a6)
		beq	not_print_max

		move.l	d6,d0
		lea	msg_max(pc),a0
		bsr	print2
not_print_max:
		tst.b	print_total(a6)
		beq	not_print_total

		move.l	d7,d0
		lea	msg_total(pc),a0
		bsr	print2
not_print_total:
		clr.w	-(a7)
		DOS	_EXIT2
*****************************************************************
print1:
		lea	msg_newline(pc),a0
print2:
		move.l	a0,-(a7)
		moveq	#0,d1
		moveq	#' ',d2
		moveq	#10,d3
		moveq	#1,d4
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		bsr	printfi
		DOS	_PRINT
		addq.l	#4,a7
		tst.l	d0
		bmi	write_fail

		rts
*****************************************************************
putc:
		movem.l	d0,-(a7)
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		tst.l	d0
		bmi	write_fail

		movem.l	(a7)+,d0
		rts
*****************************************************************
write_fail:
		move.l	#msg_write_fail_bot-msg_write_fail,-(a7)
		pea	msg_write_fail(pc)
		move.w	#2,-(a7)
		DOS	_WRITE
		move.w	#2,-(a7)
		DOS	_EXIT2
*****************************************************************
.data

	dc.b	0
	dc.b	'## mf 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

word_all:		dc.b	'all',0
word_total:		dc.b	'total',0
word_max:		dc.b	'max',0

msg_max:		dc.b	HT,'最大',CR,LF,0
msg_total:		dc.b	HT,'総計'
msg_newline:		dc.b	CR,LF,0

msg_usage:		dc.b	'使用法:  mf [ all | total | max ]',CR,LF
msg_usage_bot:

msg_write_fail:		dc.b	'wc: 出力エラー',CR,LF
msg_write_fail_bot:
*****************************************************************
.bss
.even
bsstop:
.offset 0

print_all:	ds.b	1
print_total:	ds.b	1
print_max:	ds.b	1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************
.end start
