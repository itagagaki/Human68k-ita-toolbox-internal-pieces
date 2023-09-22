* mkdir - make directory
*
* Itagaki Fumihiko  9-Jul-91  Create.
*
* Usage: mkdir [ -p ] <パス名> ...

.include doscall.h
.include error.h
.include chrcode.h

.xref DecodeHUPAIR
.xref strlen
.xref headtail
.xref drvchkp

STACKSIZE	equ	2048

.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		movea.l	8(a0),a5			*  A5 := 与えられたメモリの底
		lea	bsstop(pc),a6			*  A6 := BSS先頭アドレス
		lea	stack(a6),a7			*  A7 := スタックの底
		movea.l	a7,a1		*  A1 := 引数並びを格納するエリアの先頭アドレス
		lea	1(a2),a0	*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen		*  D0.L に A0 が示す文字列の長さを求め，
		add.l	a1,d0		*    格納エリアの容量を
		cmp.l	a5,d0		*    チェックする．
		bhs	insufficient_memory
		*
		bsr	DecodeHUPAIR	*  デコードする．
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.w	d0,d7				*  D7.W : 引数カウンタ
		moveq	#0,d6				*  D6.W : エラー・コード
		sf	d5				*  D5.B : -p フラグ
decode_opt_loop1:
		tst.w	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		subq.w	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		beq	decode_opt_done
decode_opt_loop2:
		cmp.b	#'p',d0
		bne	bad_option

		st	d5
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		subq.w	#1,d7
		bcs	too_few_args

loop:
		bsr	drvchkp
		bmi	fail

		bsr	try_mkdir
		bpl	next

		cmp.l	#ENODIR,d0
		bne	fail

fail:
		move.l	a0,-(a7)
		bsr	werror_myname
		cmp.l	#ENODIR,d0
		beq	fail_nodir

		lea	msg_directory(pc),a0
		bsr	werror
		movea.l	(a7),a0
		bsr	werror
		lea	msg_failed(pc),a0
		bsr	werror
		bra	fail_perror

fail_nodir:
		movea.l	(a7),a0
		move.l	d0,-(a7)
		bsr	headtail
		move.l	(a7)+,d0
		subq.l	#1,a1
		bsr	werror_2
fail_perror:
		bsr	perror
		movea.l	(a7)+,a0
		moveq	#3,d6
next:
		tst.b	(a0)+
		bne	next
		dbra	d7,loop
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2


bad_option:
		bsr	werror_myname
		lea	msg_illegal_option(pc),a0
		bsr	werror
		move.w	d0,-(a7)
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		bra	usage

too_few_args:
		bsr	werror_myname
		lea	msg_too_few_args(pc),a0
		bsr	werror
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	exit_program
*****************************************************************
perror:
		not.l	d0		* -1 -> 0, -2 -> 1, ...
		cmp.l	#25,d0
		bls	perror_2

		cmp.l	#256,d0
		blo	perror_1

		sub.l	#256,d0
		cmp.l	#4,d0
		bhi	perror_1

		lea	perror_table_2(pc),a0
		bra	perror_3

perror_1:
		moveq	#25,d0
perror_2:
		lea	perror_table(pc),a0
perror_3:
		lsl.l	#2,d0
		move.l	(a0,d0),d0
		beq	perror_4

		movea.l	d0,a0
		bsr	werror
perror_4:
		lea	msg_newline(pc),a0
		bra	werror
*****************************************************************
werror_myname:
		lea	msg_myname(pc),a0
werror:
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1
werror_2:
		move.l	d0,-(a7)
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		move.l	(a7)+,d0
		rts
*****************************************************************
try_mkdir:
		movem.l	d1/a1,-(a7)
		bsr	do_mkdir			*  まず自分を作ってみる
		bpl	try_mkdir_return		*  成功したならば帰る

		tst.b	d5				*  -p が指定されて
		beq	try_mkdir_return		*  いないならば失敗とする

		cmp.l	#ENODIR,d0			*  「パス名の途中のディレクトリが無い」
		bne	try_mkdir_return		*  以外ならば失敗 -- 帰る

		*  パス名の途中のディレクトリが無い
		*  --- 親ディレクトリを作る

		move.l	d0,-(a7)
		bsr	headtail
		move.l	(a7)+,d0
		cmpa.l	a0,a1
		beq	try_mkdir_return		*  親は無い -- 失敗 -- 帰る

		move.b	-(a1),d1
		cmp.b	#'/',d1
		beq	try_mkdir_try

		cmp.b	#'\',d1
		bne	try_mkdir_return		*  親は無い -- 失敗 -- 帰る
try_mkdir_try:
		clr.b	(a1)
		bsr	try_mkdir
		bmi	try_mkdir_return		*  親も失敗 -- 失敗 -- 帰る

		*  親ディレクトリの作成は成功した
		*  --- もう一度自分を作る

		move.b	d1,(a1)
		bsr	do_mkdir
try_mkdir_return:
		movem.l	(a7)+,d1/a1
		tst.l	d0
		rts
*****************************************************************
do_mkdir:
		move.l	a0,-(a7)
		DOS	_MKDIR
		addq.l	#4,a7
		move.l	d0,d3
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## mkdir 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

.even
perror_table:
	dc.l	0			*   0 ( -1)
	dc.l	0			*   1 ( -2)
	dc.l	msg_nodir		*   2 ( -3)
	dc.l	0			*   3 ( -4)
	dc.l	0			*   4 ( -5)
	dc.l	0			*   5 ( -6)
	dc.l	0			*   6 ( -7)
	dc.l	0			*   7 ( -8)
	dc.l	0			*   8 ( -9)
	dc.l	0			*   9 (-10)
	dc.l	0			*  10 (-11)
	dc.l	0			*  11 (-12)
	dc.l	msg_bad_name		*  12 (-13)
	dc.l	0			*  13 (-14)
	dc.l	msg_bad_drive		*  14 (-15)
	dc.l	0			*  15 (-16)
	dc.l	0			*  16 (-17)
	dc.l	0			*  17 (-18)
	dc.l	msg_write_disabled	*  18 (-19)
	dc.l	msg_directory_exists	*  19 (-20)
	dc.l	0			*  20 (-21)
	dc.l	0			*  21 (-22)
	dc.l	msg_disk_full		*  22 (-23)
	dc.l	msg_directory_full	*  23 (-24)
	dc.l	0			*  24 (-25)
	dc.l	0			*  25 (-26)

.even
perror_table_2:
	dc.l	msg_bad_drivename	* 256 (-257)
	dc.l	msg_no_drive		* 257 (-258)
	dc.l	msg_no_media_in_drive	* 258 (-259)
	dc.l	msg_media_set_miss	* 259 (-260)
	dc.l	msg_drive_not_ready	* 260 (-261)

msg_nodir:		dc.b	': このようなディレクトリはありません',0
msg_bad_name:		dc.b	'; 名前が無効です',0
msg_bad_drive:		dc.b	'; ドライブの指定が無効です',0
msg_write_disabled:	dc.b	'; 書き込みが許可されていません',0
msg_directory_exists:	dc.b	'; すでに存在しています',0
msg_directory_full:	dc.b	'; ディレクトリが満杯です',0
msg_disk_full:		dc.b	'; ディスクが満杯です',0
msg_bad_drivename:	dc.b	'; ドライブ名が無効です',0
msg_no_drive:		dc.b	'; ドライブがありません',0
msg_no_media_in_drive:	dc.b	'; ドライブにメディアがセットされていません',0
msg_media_set_miss:	dc.b	'; ドライブにメディアが正しくセットされていません',0
msg_drive_not_ready:	dc.b	'; ドライブの準備ができていません',0

msg_myname:		dc.b	'mkdir: ',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_directory:		dc.b	' ディレクトリ "',0
msg_failed:		dc.b	'" の作成に失敗しました',0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_too_few_args:	dc.b	'引数が足りません',0
msg_usage:		dc.b	CR,LF,'使用法:  mkdir [ -p ] <パス名> ...'
msg_newline:		dc.b	CR,LF,0
*****************************************************************
.bss
.even
bsstop:
.offset 0
		ds.b	STACKSIZE
.even
stack:
*****************************************************************

.end start
