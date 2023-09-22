* init - process controll initialization
*
* Itagaki Fumihiko 26-Jan-92  Create.
*
* Usage: init

.include doscall.h
.include chrcode.h
.include limits.h

.xref EncodeHUPAIR
.xref SetHUPAIR
.xref memmovi
.xref strazbot
.xref cat_pathname
.xref getenv
.xref fclose

** 可変定数
CMDLINE_SIZE	equ	256

STACKSIZE	equ	512

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0			*  HUPAIR適合宣言
start1:
		move.l	8(a0),a5			*  A5 := 与えられたメモリの底
		lea	bsstop(pc),a6			*  A6 := BSSの先頭アドレス
		lea	stack_bottom(a6),a7		*  A7 := スタックの底
		move.l	a3,init_envp(a6)		*  環境のアドレスを記憶する
	*
	*  占有メモリを切り詰める
	*
		DOS	_GETPDB
		movea.l	d0,a1				*  A1 : PDBアドレス
		lea	stack_bottom(a6),a0
		move.l	a0,d0
		sub.l	a1,d0
		move.l	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  initの環境を複製する
	*
		movea.l	init_envp(a6),a1
		lea	4(a1),a0
		bsr	strazbot
		move.l	a0,d1
		sub.l	a1,d1
		move.l	d1,d2
		addq.l	#2,d1
		bclr	#0,d1
		move.l	d1,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		bmi	insufficient_memory

		move.l	d0,child_envp(a6)
		movea.l	d0,a0
		move.l	d1,(a0)+
		lea	4(a1),a1
		move.l	d2,d0
		bsr	memmovi
	*
	*  ［暫定］/bin/login を決める
	*
		lea	file_login(pc),a1
		lea	child_pathname(a6),a0
		bsr	make_sys_pathname
		bmi	too_long_pathname

		lea	child_args(a6),a0
		move.l	#CMDLINE_SIZE,d0
		lea	str_p(pc),a1
		moveq	#1,d1
		bsr	EncodeHUPAIR
		bmi	too_long_arg

		lea	child_args(a6),a1
		lea	child_pathname(a6),a2
		move.l	#CMDLINE_SIZE,d1
		bsr	SetHUPAIR
		bmi	too_long_arg
	*
	*  シグナル処理ルーチンを設定する
	*
		st	in_me
		pea	manage_interrupt_signal(pc)
		move.w	#_CTRLVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		pea	manage_abort_signal(pc)
		move.w	#_ERRJVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
	**
	**  メイン・ループ
	**
main_loop:
		bsr	xfclose
	*
	*  子プロセスをexecする
	*
		sf	in_me
		move.l	child_envp(a6),-(a7)		*  子プロセスの環境のアドレス
		pea	child_args(a6)			*  起動するプログラムへの引数のアドレス
		pea	child_pathname(a6)		*  起動するプログラムのパス名のアドレス
		clr.w	-(a7)				*  ファンクション：LOAD&EXEC
		DOS	_EXEC
		lea	14(a7),a7
		lea	bsstop(pc),a6
		st	in_me
		tst.l	d0
		bpl	main_loop

		lea	child_pathname(a6),a0
		lea	msg_unable_to_execute(pc),a1
		bsr	werror2
		moveq	#1,d0
do_exit:
		move.w	d0,-(a7)
		DOS	_EXIT2
*****************************************************************
manage_abort_signal:
		move.l	#$3fc,d0		* D0 = 000003FC
		cmp.w	#$100,d1
		bcs	manage_signals

		addq.l	#1,d0			* D0 = 000003FD
		cmp.w	#$200,d1
		bcs	manage_signals

		addq.l	#2,d0			* D0 = 000003FF
		cmp.w	#$ff00,d1
		bcc	manage_signals

		cmp.w	#$f000,d1
		bcc	manage_signals

		move.b	d1,d0
		bra	manage_signals

manage_interrupt_signal:
		move.l	#$200,d0		* D0 = 00000200
manage_signals:
		tst.b	in_me
		beq	do_exit

		lea	bsstop(pc),a6
		lea	stack_bottom(a6),a7
		bra	main_loop


insufficient_memory:
		lea	msg_insufficient_memory(pc),a0
werror_exit:
		bsr	werror
		move.w	#1,-(a7)
		DOS	_EXIT2

too_long_pathname:
		lea	msg_too_long_pathname(pc),a0
		bra	werror_exit

too_long_arg:
		lea	msg_too_long_arg(pc),a0
		bra	werror_exit
*****************************************************************
werror2:
		move.l	a0,-(a7)
		movea.l	a1,a0
		bsr	werror
		lea	msg_space_quote(pc),a0
		bsr	werror
		move.l	(a7)+,a0
		bsr	werror
		lea	msg_quote_crlf(pc),a0
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
xfclose:
		move.l	d0,-(a7)
		move.w	file_handle(a6),d0
		bmi	xfclose_done

		bsr	fclose
		move.w	#-1,file_handle(a6)
xfclose_done:
		move.l	(a7)+,d0
		rts
*****************************************************************
make_sys_pathname:
		movem.l	d0/a0-a4,-(a7)
		movea.l	a0,a4
		movea.l	a1,a2
		movea.l	init_envp(a6),a3
		cmpa.l	#-1,a3
		beq	make_sys_pathname_sysroot_null

		lea	word_SYSROOT(pc),a0
		bsr	getenv
		bne	make_sys_pathname_cat
make_sys_pathname_sysroot_null:
		lea	str_nul,a0
		move.l	a0,d0
make_sys_pathname_cat:
		movea.l	d0,a1
		movea.l	a4,a0
		bsr	cat_pathname
make_sys_pathname_return:
		movem.l	(a7)+,d0/a0-a4
return:
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## init 0.0 ##  Copyright(C)1992 by Itagaki Fumihiko',0

word_SYSROOT:			dc.b	'SYSROOT',0
msg_insufficient_memory:	dc.b	'init: Insufficient memory',CR,LF,0
msg_too_long_pathname:		dc.b	'init: Too long pathname',CR,LF,0
msg_too_long_arg:		dc.b	'init: Too long argument',CR,LF,0
msg_unable_to_execute:		dc.b	'init: Unable to execute',0
msg_space_quote:		dc.b	' "',0
msg_quote_crlf:			dc.b	'"',CR,LF
str_nul:			dc.b	0

file_login:			dc.b	'/etc/getty.x',0
str_p:				dc.b	'-p',0
*****************************************************************
.bss

in_me:		ds.b	1

.even
bsstop:
.offset 0

init_envp:	ds.l	1
child_envp:	ds.l	1
file_handle:	ds.w	1
child_pathname:	ds.b	MAXPATH+1
		ds.b	8
child_args:	ds.b	CMDLINE_SIZE

		ds.b	STACKSIZE
.even
stack_bottom:
envarg_top:
*****************************************************************
.end start
