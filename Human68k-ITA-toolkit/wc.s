* wc - word count
*
* Itagaki Fumihiko 19-Jun-91  Create.
*
* Usage: wc [ -SZlwc ] [ <ファイル> ] ...
*

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref isspace
.xref strlen
.xref utoa
.xref printfi
.xref tfopen

STACKSIZE	equ	256

CTRLD	equ	$04
CTRLZ	equ	$1A


.text

start:
		bra	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6			*  A6 := BSSの先頭アドレス
		lea	stack_bottom(a6),a7		*  A7 := スタックの底
		move.l	a7,inpbuf_top(a6)		*  入力バッファの先頭アドレス
		move.l	8(a0),d0			*  このメモリ・ブロックの終わり+1
		sub.l	a7,d0				*  入力バッファの大きさ
		bls	insufficient_memory

		move.l	d0,inpbuf_size(a6)
		*
		movea.l	a7,a1			*  A1 := 引数並びを格納するエリアの先頭アドレス
		lea	1(a2),a0		*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen
		addq.l	#1,d0
		sub.l	d0,inpbuf_size(a6)
		bls	insufficient_memory

		add.l	d0,inpbuf_top(a6)

		bsr	DecodeHUPAIR
		move.w	d0,d7				*  D7.W : 引数カウンタ

		moveq	#0,d6				*  D6.W : エラー・コード
		sf	flag_silent(a6)
		sf	flag_ctrlz(a6)
		sf	flag_l(a6)
		sf	flag_w(a6)
		sf	flag_c(a6)
parse_option:
		tst.w	d7
		beq	parse_option_done

		cmpi.b	#'-',(a1)
		bne	parse_option_done

		tst.b	1(a1)
		beq	parse_option_done

		addq.l	#1,a1
		subq.w	#1,d7
parse_option_arg:
		move.b	(a1)+,d0
		beq	parse_option

		lea	flag_silent(a6),a0
		cmp.b	#'S',d0
		beq	option_found

		lea	flag_ctrlz(a6),a0
		cmp.b	#'Z',d0
		beq	option_found

		lea	flag_l(a6),a0
		cmp.b	#'l',d0
		beq	option_found

		lea	flag_w(a6),a0
		cmp.b	#'w',d0
		beq	option_found

		lea	flag_c(a6),a0
		cmp.b	#'c',d0
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
		moveq	#1,d6
		bra	exit_program

option_found:
		st	(a0)
		bra	parse_option_arg

parse_option_done:
		move.b	flag_l(a6),d0
		or.b	flag_w(a6),d0
		or.b	flag_c(a6),d0
		bne	option_ok

		st	flag_l(a6)
		st	flag_w(a6)
		st	flag_c(a6)
option_ok:
		subq.w	#1,d7
		bcc	for_file_start

		bsr	do_stdin
		clr.l	a1
		bsr	do_print
		bra	for_file_done

for_file_start:
		move.w	d7,nfiles(a6)
		clr.l	total_lines(a6)
		clr.l	total_words(a6)
		clr.l	total_characters(a6)
for_file_loop:
		movea.l	a1,a0
		moveq	#0,d0
		bsr	tfopen
		bpl	open_file_ok

		moveq	#2,d6
		tst.b	flag_silent(a6)
		bne	for_file_continue

		bsr	werror_myname
		movea.l	a1,a0
		bsr	werror
		lea	msg_open_fail(pc),a0
		bsr	werror
		bra	for_file_continue

open_file_ok:
		move.w	d0,d2
		sf	this_is_stdin(a6)
		bsr	do_file
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7

		bsr	do_print
		move.l	lines(a6),d0
		add.l	d0,total_lines(a6)
		move.l	words(a6),d0
		add.l	d0,total_words(a6)
		move.l	characters(a6),d0
		add.l	d0,total_characters(a6)
for_file_continue:
		tst.b	(a1)+
		bne	for_file_continue
		dbra	d7,for_file_loop

		tst.w	nfiles(a6)
		beq	for_file_done

		move.l	total_lines(a6),d0
		move.l	d0,lines(a6)
		move.l	total_words(a6),d0
		move.l	d0,words(a6)
		move.l	total_characters(a6),d0
		move.l	d0,characters(a6)
		lea	word_total(pc),a1
		bsr	do_print
for_file_done:
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2
****************************************************************
* do_stdin
* do_file
****************************************************************
do_stdin:
		moveq	#0,d2
		st	this_is_stdin(a6)
do_file:
		move.b	flag_ctrlz(a6),d0
		move.b	d0,terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		move.w	d2,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		btst	#7,d0				*  '0':block  '1':character
		beq	do_file_start

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	do_file_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
do_file_start:
		clr.l	lines(a6)
		clr.l	words(a6)
		clr.l	characters(a6)
		st	lastchar_is_space(a6)
		movea.l	inpbuf_top(a6),a3
do_file_loop:
		move.l	inpbuf_size(a6),-(a7)
		move.l	a3,-(a7)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail
.if 0
		beq	do_file_done	* （ここで終わらなくても下で終わってくれる）
.endif

		sf	d4				* D4.B : EOF flag
		tst.b	terminate_by_ctrlz(a6)
		beq	trunc_ctrlz_done

		moveq	#CTRLZ,d0
		bsr	trunc
trunc_ctrlz_done:
		tst.b	terminate_by_ctrld(a6)
		beq	trunc_ctrld_done

		moveq	#CTRLD,d0
		bsr	trunc
trunc_ctrld_done:
		tst.l	d3
		beq	do_file_done

		movea.l	a3,a2
count_loop:
		move.b	(a2)+,d0
		*
		*  count characters
		*
		addq.l	#1,characters(a6)
		*
		*  count words
		*
		bsr	isspace
		seq	d1				*  D1 : current char is space
		tst.b	lastchar_is_space(a6)
		beq	not_newword

		tst.b	d1
		bne	not_newword

		addq.l	#1,words(a6)
not_newword:
		move.b	d1,lastchar_is_space(a6)
		*
		*  count lines
		*
		cmp.b	#LF,d0
		bne	count_continue

		addq.l	#1,lines(a6)
count_continue:
		subq.l	#1,d3
		bne	count_loop

		tst.b	d4
		beq	do_file_loop
do_file_done:
		rts
*****************************************************************
trunc:
		move.l	d3,d1
		beq	trunc_done

		movea.l	a3,a2
trunc_find_loop:
		cmp.b	(a2)+,d0
		beq	trunc_found

		subq.l	#1,d1
		bne	trunc_find_loop
		bra	trunc_done

trunc_found:
		move.l	a2,d3
		subq.l	#1,d3
		sub.l	a3,d3
		st	d4
trunc_done:
		rts
*****************************************************************
do_print:
		move.l	a1,-(a7)
		moveq	#0,d1
		moveq	#' ',d2
		moveq	#10,d3
		moveq	#1,d4
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		tst.b	flag_l(a6)
		beq	not_print_lines

		move.l	lines(a6),d0
		bsr	printu
not_print_lines:
		tst.b	flag_w(a6)
		beq	not_print_words

		move.l	words(a6),d0
		bsr	printu
not_print_words:
		tst.b	flag_c(a6)
		beq	not_print_characters

		move.l	characters(a6),d0
		bsr	printu
not_print_characters:
		tst.l	(a7)
		beq	print_done

		bsr	put_space
		bsr	put_space
		DOS	_PRINT
		tst.l	d0
		bmi	write_fail
print_done:
		movea.l	(a7)+,a1
		moveq	#CR,d0
		bsr	putc
		moveq	#LF,d0
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
put_space:
		move.l	d0,-(a7)
		moveq	#' ',d0
		bsr	putc
		move.l	(a7)+,d0
		rts
*****************************************************************
printu:
		bsr	put_space
		bra	printfi
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
read_fail:
		bsr	werror_myname
		movea.l	a1,a0
		tst.b	this_is_stdin(a6)
		beq	read_fail_1

		lea	msg_stdin(pc),a0
read_fail_1:
		bsr	werror
		lea	msg_read_fail(pc),a0
		bra	werror_exit_3
*****************************************************************
write_fail:
		lea	msg_write_fail(pc),a0
werror_exit_3:
		bsr	werror
		moveq	#3,d6
		bra	exit_program
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
	dc.b	'## wc 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	'wc: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_read_fail:		dc.b	': 入力エラー',CR,LF,0
msg_write_fail:		dc.b	'wc: 出力エラー',CR,LF,0
msg_stdin:		dc.b	'(標準入力)',0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_usage:		dc.b	CR,LF,'使用法:  wc [ -SZlwc ] [ <ファイル> ] ...',CR,LF,0
word_total:		dc.b	'合計',0
*****************************************************************
.bss
.even
bsstop:
.offset 0
inpbuf_top:		ds.l	1
inpbuf_size:		ds.l	1
lines:			ds.l	1
words:			ds.l	1
characters:		ds.l	1
total_lines:		ds.l	1
total_words:		ds.l	1
total_characters:	ds.l	1
nfiles:			ds.w	1
flag_silent:		ds.b	1
flag_ctrlz:		ds.b	1
flag_l:			ds.b	1
flag_w:			ds.b	1
flag_c:			ds.b	1
this_is_stdin:		ds.b	1
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1
lastchar_is_space:	ds.b	1

		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
