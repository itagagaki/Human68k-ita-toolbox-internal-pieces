* rm - remove directory
*
* Itagaki Fumihiko 17-Jun-91  Create.
*
* Usage: rm [ -fir ] [ - ] <ファイル> ...
*

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref iscntrl
.xref utoa
.xref printfi

STACKSIZE	equ	512

OUTBUF_SIZE	equ	1024

CTRLD	equ	$04
CTRLZ	equ	$1A


.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
		moveq	#0,d6				*  D6.W : エラー・コード
		*
		lea	1(a2),a0
		bsr	DecodeHUPAIR
		move.w	d0,d7				*  D7.W : 引数カウンタ
		sf	flag_f(a6)
		sf	flag_i(a6)
		sf	flag_r(a6)
parse_option:
		tst.w	d7
		beq	parse_option_done

		cmpi.b	#'-',(a0)
		bne	parse_option_done

		addq.l	#1,a0
		subq.w	#1,d7

		tst.b	(a0)
		beq	parse_option_break
parse_option_arg:
		move.b	(a0)+,d0
		beq	parse_option

		lea	flag_f(a6),a1
		cmp.b	#'f',d0
		beq	option_found

		lea	flag_i(a6),a1
		cmp.b	#'i',d0
		beq	option_found

		lea	flag_r(a6),a1
		cmp.b	#'r',d0
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
		lea	msg_newline(pc),a0
		bsr	werror
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

option_found:
		st	(a1)
		bra	parse_option_arg

parse_option_break:
		addq.l	#1,a0
parse_option_done:
		subq.w	#1,d7
		bcs	usage
for_file_loop:
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		bpl	open_file_ok

		tst.b	flag_f(a6)
		bne	for_file_continue

		moveq	#2,d6
		move.l	a0,-(a7)
		bsr	werror_myname
		movea.l	(a7),a0
		bsr	werror
		lea	msg_nofile(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		bra	for_file_continue

open_file_ok:
		move.w	d0,d2
		bsr	remove_file
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
for_file_continue:
		tst.b	(a0)+
		bne	for_file_continue
		dbra	d7,for_file_loop
for_file_done:
		tst.b	do_buffering(a6)
		beq	exit_program

		move.l	#OUTBUF_SIZE,d0
		sub.l	outbuf_free(a6),d0
		beq	exit_program

		bsr	flush_outbuf
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2
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
		rts
****************************************************************
* remove_file
****************************************************************
remove_file:
		move.b	flag_ctrlz(a6),d0
		move.b	d0,terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		move.w	d2,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		btst	#7,d0				*  '0':block  '1':character
		beq	remove_file_start

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	remove_file_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
remove_file_start:
		movea.l	inpbuf_top(a6),a3
remove_file_loop:
		move.l	inpbuf_size(a6),-(a7)
		move.l	a3,-(a7)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail
.if 0
		beq	remove_file_done	*（ここで終わらなくても下で終わってくれる）
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
		beq	remove_file_done

		tst.b	simple(a6)
		beq	remove_file_not_simple

		move.l	d3,-(a7)
		move.l	a3,-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	d3,d0
		blt	write_fail

		bra	remove_file_continue

remove_file_not_simple:
		movea.l	a3,a2
write_loop:
		move.b	(a2)+,d0
		*
		*	if (newline) {
		*		if (!pending_cr && code == CR) goto do_pending_cr;
		*		tmp = last_is_empty;
		*		last_is_empty = (code == LF);
		*		if (last_is_empty && tmp && flag_s) {
		*			pending_cr = 0;
		*			continue;
		*		}
		*		newline = 0;
		*		print_lineno(++lineno);
		*	}
		tst.b	newline(a6)
		beq	continue_for_line

		tst.b	pending_cr(a6)
		bne	check_empty

		cmp.b	#CR,d0
		beq	do_pending_cr
check_empty:
		move.b	last_is_empty(a6),d1
		cmp.b	#LF,d0
		seq	last_is_empty(a6)
		bne	not_cancel_line

		tst.b	d1
		beq	not_cancel_line

		tst.b	flag_s(a6)
		beq	not_cancel_line

		sf	pending_cr(a6)
		bra	write_continue

not_cancel_line:
		sf	newline(a6)

		tst.b	flag_b(a6)
		beq	not_b

		tst.b	last_is_empty(a6)
		bne	continue_for_line
		bra	print_lineno

not_b:
		tst.b	flag_n(a6)
		beq	continue_for_line
print_lineno:
		addq.l	#1,lineno(a6)
		movem.l	d0/d2-d4/a0/a2,-(a7)
		move.l	lineno(a6),d0
		moveq	#0,d1
		moveq	#' ',d2
		moveq	#6,d3
		moveq	#1,d4
		lea	utoa(pc),a0
		lea	putc(pc),a1
		suba.l	a2,a2
		bsr	printfi
		moveq	#HT,d0
		bsr	putc
		movem.l	(a7)+,d0/d2-d4/a0/a2
continue_for_line:
		*	if (code == LF) {
		*		if (flag_e) putc('$');
		*		if (convert_newline) pending_cr = 1;
		*		flush_out_cr();
		*		newline = 1;
		*	}
		*	else {
		*		flush_out_cr();
		*		if (code == CR) {
		*			pending_cr = 1;
		*			continue;
		*		}
		*		else ...
		*			:
		*			:
		*			:
		*	}
		*	putc(code);
		*
		cmp.b	#LF,d0
		bne	not_lf

		tst.b	flag_e(a6)
		beq	pass_put_doller

		move.w	d0,-(a7)
		moveq	#'$',d0
		bsr	putc
		move.w	(a7)+,d0
pass_put_doller:
		tst.b	convert_newline(a6)
		beq	pass_convert_newline

		st	pending_cr(a6)
pass_convert_newline:
		bsr	flush_out_cr
		st	newline(a6)
		bra	put1char_normal

not_lf:
		bsr	flush_out_cr
		cmp.b	#CR,d0
		bne	not_cr
do_pending_cr:
		st	pending_cr(a6)
		bra	write_continue

not_cr:
		cmp.b	#HT,d0
		beq	put_ht

		cmp.b	#FS,d0
		beq	put1char_normal

		btst	#7,d0
		beq	put1char_nonmeta

		tst.b	flag_m(a6)
		beq	put1char_nonmeta

		move.w	d0,-(a7)
		moveq	#'M',d0
		bsr	putc
		moveq	#'-',d0
		bsr	putc
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

put_ht:
		tst.b	flag_t(a6)
		beq	put1char_normal
put_cntrl_caret:
		move.w	d0,-(a7)
		moveq	#'^',d0
		bsr	putc
		move.w	(a7)+,d0
		add.b	#$40,d0
		bclr	#7,d0
put1char_normal:
		bsr	putc
write_continue:
		subq.l	#1,d3
		bne	write_loop
remove_file_continue:
		tst.b	d4
		beq	remove_file_loop
remove_file_done:
flush_out_cr:
		tst.b	pending_cr(a6)
		beq	flush_out_cr_done

		move.l	d0,-(a7)
		move.b	#CR,d0
		bsr	putc
		move.l	(a7)+,d0
		sf	pending_cr(a6)
flush_out_cr_done:
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
flush_outbuf:
		move.l	d0,-(a7)
		move.l	outbuf_top(a6),-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	-4(a7),d0
		blt	write_fail

		move.l	outbuf_top(a6),d0
		move.l	d0,outbuf_ptr(a6)
		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free(a6)
		rts
*****************************************************************
putc:
		movem.l	d0/a0/a6,-(a7)
		lea	bsstop(pc),a6
		tst.b	do_buffering(a6)
		bne	putc_do_buffering

		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		tst.l	d0
		bmi	write_fail

		bra	putc_done

putc_do_buffering:
		tst.l	outbuf_free(a6)
		bne	putc_do_buffering_1

		move.l	d0,-(a7)
		move.l	#OUTBUF_SIZE,d0
		bsr	flush_outbuf
		move.l	(a7)+,d0
putc_do_buffering_1:
		movea.l	outbuf_ptr(a6),a0
		move.b	d0,(a0)+
		move.l	a0,outbuf_ptr(a6)
		subq.l	#1,outbuf_free(a6)
putc_done:
		movem.l	(a7)+,d0/a0/a6
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## rm 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	'rm: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_nofile:		dc.b	': このようなファイルはありません',CR,LF,0
msg_read_fail:		dc.b	': 入力エラー',CR,LF,0
msg_write_fail:		dc.b	'rm: 出力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_usage:		dc.b	'使用法:  rm [ -fir ] [ - ] <ファイル> ...'
msg_newline:		dc.b	CR,LF,0
*****************************************************************
.bss
.even
bsstop:
.offset 0
flag_f:			ds.b	1
flag_i:			ds.b	1
flag_r:			ds.b	1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************

.end start
