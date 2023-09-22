* tee - T joint
*
* Itagaki Fumihiko 19-Jun-91  Create.
*
* Usage: tee [ -Zia ] [ - | <ファイル> ... ]
*

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref isatty
.xref tfopen

STACKSIZE	equ	256

CTRLD	equ	$04
CTRLZ	equ	$1A


.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
		move.l	8(a0),d0			*  このメモリ・ブロックの終わり+1
		sub.l	a7,d0				*  stack 以降のブロックの大きさ
		bls	insufficient_memory

		move.l	d0,buffer_size(a6)

		moveq	#0,d6				*  D6.W : エラー・コード
		*
		lea	1(a2),a0
		bsr	DecodeHUPAIR
		move.w	d0,d7				*  D7.W : 引数カウンタ
		sf	flag_ctrlz(a6)
		sf	flag_i(a6)
		sf	flag_a(a6)
parse_option:
		tst.w	d7
		beq	parse_option_done

		cmpi.b	#'-',(a0)
		bne	parse_option_done

		tst.b	1(a0)
		beq	parse_option_done

		addq.l	#1,a0
		subq.w	#1,d7
parse_option_arg:
		move.b	(a0)+,d0
		beq	parse_option

		lea	flag_ctrlz(a6),a1
		cmp.b	#'Z',d0
		beq	option_found

		lea	flag_i(a6),a1
		cmp.b	#'i',d0
		beq	option_found

		lea	flag_a(a6),a1
		cmp.b	#'a',d0
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
		st	(a1)
		bra	parse_option_arg

parse_option_done:
		moveq	#0,d0
		move.w	d7,d0				*  D7.W : 出力ファイル数-1
		addq.l	#1,d0
		add.l	d0,d0
		move.l	d0,d1
		add.l	d0,d0
		add.l	d1,d0
		sub.l	d0,buffer_size(a6)
		bls	insufficient_memory

		lea	outputs(a6),a3
		adda.l	d0,a3				*  A3 : バッファアドレス

		lea	outputs(a6),a4
		move.w	#1,(a4)+
		clr.l	(a4)+
		move.w	d7,d1
		bra	open_file_continue

open_file_loop:
		cmpi.b	#'-',(a0)
		bne	open_file

		tst.b	1(a0)
		bne	open_file

		sf	d4
		moveq	#1,d0
		bra	open_file_ok

open_file:
		moveq	#0,d0				*  まず読み込みモードで
		bsr	tfopen				*  出力先ファイルをオープンしてみる
		cmp.l	#-256,d0			*  ドライブのエラーか？
		blt	open_fail

		move.l	d0,d2				*  デスクリプタをD2にセット
		bmi	do_create_file

		bsr	isatty				*  そいつがキャラクタデバイスかどうかを
		move.b	d0,d3				*    D3にセット
		moveq	#1,d0
		btst	#7,d3				*  キャラクタ・デバイスで
		beq	device_check_done		*    なければチェック終わり

		move.w	d2,-(a7)			*  そいつが
		move.w	#7,-(a7)			*    出力可能デバイスかどうか
		DOS	_IOCTRL				*    調べる
		addq.l	#4,a7
device_check_done:
		move.l	d0,-(a7)
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
		move.l	(a7)+,d0			*  出力可能デバイスか？
		beq	open_fail

		move.b	flag_a(a6),d4			*  D4.B : アペンドフラグ  アペンドならば
		bne	do_open_file			*    オープンする（新規作成しない）

		btst	#7,d3				*  キャラクタ・デバイスならば
		bne	do_open_file			*  　オープンする（新規作成しない）
do_create_file:
		sf	d4				*  D4=0 : アペンドしない
		move.w	#$20,-(a7)			*  通常のファイルモードで
		move.l	a0,-(a7)			*  出力先ファイルを
		DOS	_CREATE				*  新規作成する
		bra	file_opened

do_open_file:
		move.w	#1,-(a7)			*  書き込みモードで
		move.l	a0,-(a7)			*  出力先ファイルを
		DOS	_OPEN				*  オープンする
file_opened:
		addq.l	#6,a7
		move.l	a0,d2
		tst.l	d0
		bpl	open_file_ok
open_fail:
		moveq	#2,d6
		move.l	a0,-(a7)
		bsr	werror_myname
		movea.l	(a7),a0
		bsr	werror
		lea	msg_open_fail(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		moveq	#0,d0
open_file_ok:
		move.w	d0,(a4)
		move.l	d2,2(a4)
		tst.b	d4
		beq	open_file_done

		bsr	isatty				* キャラクタ・デバイス
		bne	open_file_done			*   ならばシークしない

		move.w	#2,-(a7)			* EOF
		clr.l	-(a7)				* 　まで
		move.w	(a4),-(a7)			* 　出力を
		DOS	_SEEK				* 　シークする
		addq.l	#8,a7
open_file_done:
		addq.l	#6,a4
open_file_next:
		tst.b	(a0)+
		bne	open_file_next
open_file_continue:
		dbra	d1,open_file_loop

		move.b	flag_ctrlz(a6),d0
		move.b	d0,terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		clr.w	-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		btst	#7,d0				*  '0':block  '1':character
		beq	tee_start

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	tee_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
tee_start:
tee_loop:
		move.l	buffer_size(a6),-(a7)
		move.l	a3,-(a7)
		clr.w	-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail
.if 0
		beq	tee_done	* （ここで終わらなくても下で終わってくれる）
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
		beq	tee_done

		lea	outputs(a6),a4
		move.w	d7,d1
write_loop:
		move.w	(a4),d0
		beq	write_continue

		bsr	write_one
		bne	write_fail
write_continue:
		addq.l	#6,a4
		dbra	d1,write_loop

		tst.b	d4
		beq	tee_loop

tee_done:
		lea	outputs(a6),a4
		move.w	d7,d1
close_loop:
		move.w	(a4),d0
		cmp.w	#1,d0
		bls	close_continue

		move.w	d0,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
		tst.l	d0
		bmi	write_fail
close_continue:
		addq.l	#6,a4
		dbra	d1,close_loop
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2
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
write_one:
		move.l	d3,-(a7)
		move.l	a3,-(a7)
		move.w	d0,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_one_return

		sub.l	d3,d0
		blt	write_one_return

		moveq	#0,d0
write_one_return:
		rts
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
read_fail:
		bsr	werror_myname
		lea	msg_read_fail(pc),a0
		bra	werror_exit_3
*****************************************************************
write_fail:
		bsr	werror_myname
		tst.l	2(a4)
		beq	write_fail_stdout

		movea.l	2(a4),a0
		bra	write_fail_1

write_fail_stdout:
		lea	word_stdout(pc),a0
write_fail_1:
		bsr	werror
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
	dc.b	'## tee 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	'tee: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_read_fail:		dc.b	'入力エラー',CR,LF,0
msg_open_fail:		dc.b	': 出力できません',CR,LF,0
msg_write_fail:		dc.b	': 出力エラー',CR,LF,0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_usage:		dc.b	CR,LF,'使用法:  tee [ -Zia ] [ - | <ファイル> ] ...',CR,LF,0
word_stdout:		dc.b	'-標準出力-',0
*****************************************************************
.bss
.even
bsstop:
.offset 0
buffer_size:		ds.l	1
flag_ctrlz:		ds.b	1
flag_i:			ds.b	1
flag_a:			ds.b	1
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1

		ds.b	STACKSIZE
.even
stack:
outputs:
*****************************************************************

.end start
