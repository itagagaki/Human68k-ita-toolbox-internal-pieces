* mv  --  move file
*
* Itagaki Fumihiko  2-Jul-91  Create.
*
* Usage: mv [ -if ] [ - ] <file1> <file2>
*        mv [ -if ] [ - ] <file> ... <target>
*

.include doscall.h
.include chrcode.h
.include limits.h

.xref DecodeHUPAIR
.xref isatty
.xref iscntrl
.xref utoa
.xref printfi

STACKSIZE	equ	256

.text

start:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
		*
		move.l	8(a0),d7			*  このメモリ・ブロックの終わり+1
		sub.l	a7,d7				*  D7.L = stack 以降のブロックの大きさ
		moveq	#0,d5				*  D5.W : エラー・コード
		*
		lea	1(a2),a0
		bsr	DecodeHUPAIR
		move.w	d0,d6				*  D6.W : 引数カウンタ
		sf	flag_i(a6)
		sf	flag_f(a6)
parse_option:
		tst.w	d6
		beq	parse_option_done

		cmpi.b	#'-',(a0)
		bne	parse_option_done

		tst.b	1(a0)
		beq	parse_option_done

		addq.l	#1,a0
		subq.w	#1,d6
parse_option_arg:
		move.b	(a0)+,d0
		beq	parse_option

		lea	flag_i(a6),a1
		cmp.b	#'i',d0
		beq	option_found

		lea	flag_f(a6),a1
		cmp.b	#'f',d0
		beq	option_found

		move.w	d0,-(a7)
		bsr	werror_myname
		lea	msg_illegal_option(pc),a0
		bsr	werror
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d5
		bra	exit_program

option_found:
		st	(a1)
		bra	parse_option_arg

parse_option_done:
		subq.w	#1,d6
		bcc	for_file_loop

		bsr	do_stdin
		bra	exit_program

for_file_loop:
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		bpl	open_file_ok

		moveq	#2,d5
		tst.b	flag_silent(a6)
		bne	for_file_continue

		move.l	a0,-(a7)
		bsr	werror_myname
		movea.l	(a7),a0
		bsr	werror
		lea	msg_open_fail(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
open_file_ok:
		move.w	d0,d2
		bsr	do_file
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
for_file_continue:
		tst.b	(a0)+
		bne	for_file_continue
		dbra	d6,for_file_loop
exit_program:
		move.w	d5,-(a7)
		DOS	_EXIT2
*****************************************************************
write_fail:
		lea	msg_write_fail(pc),a0
		bsr	werror
		moveq	#2,d5
		bra	exit_program
*****************************************************************
* do_stdin
* do_file
****************************************************************
do_stdin:
		moveq	#0,d2
do_file:
		move.b	flag_binary(a6),d0
		not.b	d0
		bne	do_file_1

		move.w	d2,d0
		bsr	isatty
do_file_1:
		move.b	d0,text_mode(a6)
do_file_loop:
		move.l	d7,-(a7)
		pea	stack(a6)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail
		beq	do_file_done

		lea	stack(a6),a1
write_loop:
		move.b	(a1)+,d0
		cmp.b	#EOT,d0
		bne	not_eot

		tst.b	text_mode(a6)
		bne	do_file_done
not_eot:
		tst.b	newline(a6)
		beq	continue_put_line

		sf	newline(a6)
		move.b	last_is_empty(a6),d1
		cmp.b	#CR,d0
		seq	last_is_empty(a6)
		bne	do_not_cancel_this_line

		tst.b	d1
		beq	do_not_cancel_this_line

		tst.b	flag_s(a6)
		beq	do_not_cancel_this_line

		st	canceling_line(a6)
		bra	put1char_done

do_not_cancel_this_line:
		sf	canceling_line(a6)

		tst.b	flag_b(a6)
		beq	not_b

		tst.b	last_is_empty(a6)
		beq	print_lineno

		moveq	#7,d1
		bra	print_spaces_after_lineno

not_b:
		tst.b	flag_n(a6)
		beq	continue_put_line
print_lineno:
		addq.l	#1,lineno(a6)
		movem.l	d0/d2-d4/a0-a2,-(a7)
		move.l	lineno(a6),d0
		moveq	#0,d1
		moveq	#' ',d2
		moveq	#6,d3
		moveq	#1,d4
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		bsr	printfi
		movem.l	(a7)+,d0/d2-d4/a0-a2
		moveq	#1,d1
print_spaces_after_lineno:
		move.w	d0,-(a7)
		moveq	#' ',d0
print_spaces_loop:
		bsr	putc
		bmi	write_fail

		dbra	d1,print_spaces_loop

		move.w	(a7)+,d0
continue_put_line:
		tst.b	canceling_line(a6)
		bne	put1char_done

		cmp.b	#FS,d0
		beq	put1char_normal

		cmp.b	#LF,d0
		beq	put1char_normal

		cmp.b	#CR,d0
		beq	put_cr

		cmp.b	#HT,d0
		beq	put_ht

		btst	#7,d0
		beq	put1char_nonmeta

		tst.b	flag_m(a6)
		beq	put1char_nonmeta

		move.w	d0,-(a7)
		moveq	#'M',d0
		bsr	putc
		bmi	write_fail

		moveq	#'-',d0
		bsr	putc
		bmi	write_fail

		move.w	(a7)+,d0
		bclr	#7,d0
put1char_nonmeta:
		bsr	iscntrl
		bne	put1char_normal

		tst.b	flag_v(a6)
		bne	put_cntrl_caret

		tst.b	flag_e(a6)
		bne	put_cntrl_caret

		tst.b	flag_t(a6)
		bne	put_cntrl_caret

		tst.b	flag_m(a6)
		bne	put_cntrl_caret

		bra	put1char_normal

put_cr:
		tst.b	flag_e(a6)
		beq	put1char_normal

		move.w	d0,-(a7)
		moveq	#'$',d0
		bsr	putc
		bmi	write_fail

		move.w	(a7)+,d0
		bra	put1char_normal

put_ht:
		tst.b	flag_t(a6)
		beq	put1char_normal
put_cntrl_caret:
		move.w	d0,-(a7)
		moveq	#'^',d0
		bsr	putc
		bmi	write_fail

		move.w	(a7)+,d0
		add.b	#$40,d0
		bclr	#7,d0
put1char_normal:
		bsr	putc
		bmi	write_fail
put1char_done:
		tst.b	waiting_for_lf(a6)
		bne	test_lf

		cmp.b	#CR,d0
		bne	write_continue

		st	waiting_for_lf(a6)
		bra	write_continue

test_lf:
		cmp.b	#LF,d0
		bne	write_continue

		sf	waiting_for_lf(a6)
		st	newline(a6)
write_continue:
		subq.l	#1,d3
		bne	write_loop

		bra	do_file_loop

do_file_done:
		rts
*****************************************************************
putc:
		movem.l	d0,-(a7)
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		tst.l	d0
		movem.l	(a7)+,d0
		rts
*****************************************************************
werror_myname:
		lea	msg_myname(pc),a0
werror:
		move.l	a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movea.l	(a7)+,a1
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## mv 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	'mv: ',0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_write_fail:		dc.b	'mv: 出力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_usage:		dc.b	CR,LF,'使用法:  cat [ -if ] [ - ] <file> ... <target>',CR,LF,0
*****************************************************************
.bss
.even
bsstop:
.offset 0
flag_i:		ds.b	1
flag_f:		ds.b	1
newname:	ds.b	MAXPATH+1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************

.end start
