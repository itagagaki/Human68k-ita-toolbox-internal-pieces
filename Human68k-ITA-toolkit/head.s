* head  --  extract some head lines of file
*
* Itagaki Fumihiko  8-Jun-91  Create.
*
* Usage: head [ [ -Z ] [ -<行数> ] <ファイル> ] ...
*

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref isatty
.xref isdigit
.xref atou

STACKSIZE	equ	256

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
		*
		move.l	8(a0),d7			*  このメモリ・ブロックの終わり+1
		sub.l	a7,d7				*  D7.L = stack 以降のブロックの大きさ
		bls	insufficient_memory

		moveq	#0,d5				*  D5.W : エラー・コード
		*
		lea	1(a2),a0
		bsr	DecodeHUPAIR
		move.w	d0,d6				*  D6.W : 引数カウンタ
		move.l	#10,count(a6)
		st	do_count(a6)
		sf	flag_ctrlz(a6)
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
		move.b	(a0),d0
		bsr	isdigit
		bne	parse_normal_option_arg

		bsr	atou
		move.l	d1,count(a6)
		tst.l	d0
		seq	do_count(a6)
		tst.b	(a0)+
		beq	parse_option

		bsr	werror_myname
		lea	msg_illegal_count(pc),a0
		bsr	werror
		bra	usage

parse_normal_option_arg:
		move.b	(a0)+,d0
		beq	parse_option

		lea	flag_ctrlz(a6),a1
		cmp.b	#'Z',d0
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
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d5
		bra	exit_program

option_found:
		st	(a1)
		bra	parse_normal_option_arg

parse_option_done:
		clr.l	lineno(a6)
		sf	waiting_for_lf(a6)
		subq.w	#1,d6
		bcc	for_file_loop

		clr.w	nfiles(a6)
		bsr	do_stdin
		bra	exit_program

for_file_loop:
		move.w	d6,nfiles(a6)
		cmpi.b	#'-',(a0)
		bne	open_file

		tst.b	1(a0)
		bne	open_file

		bsr	do_stdin
		bra	for_file_continue

open_file:
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		bpl	open_file_ok

		moveq	#2,d5
		move.l	a0,-(a7)
		bsr	werror_myname
		movea.l	(a7),a0
		bsr	werror
		lea	msg_open_fail(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		bra	for_file_continue

open_file_ok:
		move.w	d0,d2
		movea.l	a0,a2
		sf	this_is_stdin(a6)
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
* do_stdin
* do_file
****************************************************************
do_stdin:
		moveq	#0,d2
		st	this_is_stdin(a6)
do_file:
		move.b	flag_ctrlz(a6),d0
		bne	do_file_1

		move.w	d2,d0
		bsr	isatty
do_file_1:
		move.b	d0,text_mode(a6)
		tst.b	do_count(a6)
		beq	do_file_loop

		move.l	count(a6),count_work(a6)
		beq	do_file_done
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
		movem.l	d0,-(a7)
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		tst.l	d0
		movem.l	(a7)+,d0
		bmi	write_fail

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
		tst.b	do_count(a6)
		beq	write_continue

		subq.l	#1,count_work(a6)
		beq	do_file_done
write_continue:
		subq.l	#1,d3
		bne	write_loop

		bra	do_file_loop

do_file_done:
		rts
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
read_fail:
		move.l	a0,-(a7)
		bsr	werror_myname
		movea.l	(a7)+,a0
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
		moveq	#2,d5
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
	dc.b	'## head 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	'head: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_read_fail:		dc.b	': 入力エラー',CR,LF,0
msg_write_fail:		dc.b	'head: 出力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_stdin:		dc.b	'(標準入力)',0
msg_illegal_count:	dc.b	'行数が不正です',0
msg_usage:		dc.b	CR,LF,'使用法:  head [ [ -Z ] [ -<行数> ] <ファイル> ] ...',CR,LF,0
*****************************************************************
.bss
.even
bsstop:
.offset 0
lineno:		ds.l	1
count:		ds.l	1
count_work:	ds.l	1
nfiles:		ds.w	1
do_count:	ds.b	1
this_is_stdin:	ds.b	1
flag_ctrlz:	ds.b	1
text_mode:	ds.b	1
waiting_for_lf:	ds.b	1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************

.end start
