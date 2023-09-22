* login - sign on
*
* Itagaki Fumihiko 25-Aug-91  Create.
*
* Usage: login [ -p ] [ name [ env-var ... ] ]

.include doscall.h
.include chrcode.h
.include limits.h
.include pwd.h

.xref DecodeHUPAIR
.xref isdigit
.xref islower
.xref isspace
.xref utoa
.xref strlen
.xref strchr
.xref strspc
.xref strcmp
.xref memcmp
.xref strcpy
.xref strmove
.xref memmovi
.xref strfor1
.xref strazbot
.xref skip_space
.xref cat_pathname
.xref getenv
.xref setenv
.xref getcwd
.xref tfopen
.xref fclose
.xref fgetc
.xref chdir
.xref getpass
.xref fgetpwnam

** 固定定数
PDB_ProcessFlag	equ	$50

** 可変定数
MAXLOGNAME	equ	64				*  255以下
MAXPASSWD	equ	64				*  65535以下

STACKSIZE	equ	512

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0			*  HUPAIR適合宣言
		dc.b	'login',0			*  loginコマンド宣言
start1:
		move.l	8(a0),a5			*  A5 := 与えられたメモリの底
		lea	bsstop(pc),a6			*  A6 := BSSの先頭アドレス
		lea	stack_bottom(a6),a7		*  A7 := スタックの底
		move.l	a3,login_envp(a6)		*  環境のアドレスを記憶する
		clr.l	user_envp(a6)
	*
	*  login自身のカレント・ディレクトリを保存する
	*
		lea	login_cwd(a6),a0
		bsr	getcwd
	*
	*  $SYSROOT/etc/nologin があればexitする
	*
		lea	file_nologin(pc),a1
		bsr	open_sysfile
		bpl	nologin
	*
	*  標準入力が端末かどうかをチェックする
	*
		clr.l	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		and.b	#%10100000,d0			*  CHR, RAW
		cmp.b	#%10000000,d0			*  CHR && (!RAW (COOKED))
		bne	not_a_tty
	*
	*  引数をデコードし，解釈する
	*
		sf	protect_env(a6)
		clr.b	logname+2(a6)

		lea	envarg_top(a6),a1	*  A1 := 引数並びを格納するエリアの先頭アドレス
		lea	1(a2),a0		*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen			*  D0.L に A0 が示す文字列の長さを求め，
		add.l	a1,d0			*    格納エリアの容量を
		cmp.l	a5,d0			*    チェックする
		bhs	insufficient_memory_for_me

		bsr	DecodeHUPAIR			*  デコードする
		movea.l	a1,a0
		move.w	d0,argc(a6)
		beq	parse_arg_done

		lea	str_p(pc),a1
		bsr	strcmp
		bne	no_p

		st	protect_env(a6)
		bsr	strfor1
		subq.w	#1,argc(a6)
no_p:
		tst.w	argc(a6)
		beq	parse_arg_done

		bsr	strlen
		cmp.l	#MAXLOGNAME,d0
		bhi	set_logname_done

		movea.l	a0,a1
		lea	logname+2(a6),a0
		bsr	strcpy
		movea.l	a1,a0
set_logname_done:
		bsr	strfor1
		subq.w	#1,argc(a6)
parse_arg_done:
	*
	*  残りの引数をスタックの直後に保存する
	*
		movea.l	a0,a1
		lea	envarg_top(a6),a0
		move.w	argc(a6),d7
		bra	move_envarg_continue

move_envarg_loop:
		bsr	strmove
move_envarg_continue:
		dbra	d7,move_envarg_loop
	*
	*  占有メモリを切り詰める
	*
		DOS	_GETPDB
		movea.l	d0,a1				*  A1 : PDBアドレス
		move.l	a0,d0
		sub.l	a1,d0
		move.l	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  親プロセスが無いならばシグナル処理ルーチンを設定する
	*
		tst.l	PDB_ProcessFlag(a1)		*  0:親有り  -1:OSから起動
		beq	test_logname

		st	in_login(a6)
		pea	manage_signals(pc)
		move.w	#_CTRLVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		pea	manage_signals(pc)
		move.w	#_ERRJVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		bra	test_logname
	**
	**  メイン・ループ
	**
main_loop:
		move.l	user_envp(a6),d0
		beq	free_envp_ok

		move.l	d0,-(a7)
		DOS	_MFREE
		addq.l	#4,a7
		clr.l	user_envp(a6)
free_envp_ok:
		lea	login_cwd(a6),a0
		bsr	chdir
ask_logname:
		*
		*  ログイン名を入力する
		*
		pea	msg_login(pc)
		DOS	_PRINT
		addq.l	#4,a7
		lea	logname(a6),a0
		move.b	#MAXLOGNAME,(a0)
		clr.b	1(a0)
		move.l	a0,-(a7)
		DOS	_GETS
		addq.l	#4,a7
		bsr	put_newline
		lea	logname+1(a6),a0
		moveq	#0,d0
		move.b	(a0)+,d0
		clr.b	(a0,d0.l)
test_logname:
		lea	logname+2(a6),a0
		bsr	skip_space
		tst.b	(a0)
		beq	ask_logname

		move.l	a0,logname_top(a6)
		sf	incorrect(a6)
	*
	*  ログイン名をチェックする
	*
		moveq	#0,d1
		move.b	(a0)+,d0
		bra	check_logname_first

check_logname_loop:
		bsr	isdigit
		beq	check_logname_continue
check_logname_first:
		bsr	islower
		bne	login_invalid
check_logname_continue:
		addq.l	#1,d1
		cmp.l	#PW_NAME_SIZE,d1
		bhi	login_invalid

		move.b	(a0)+,d0
		beq	check_logname_done

		bsr	isspace
		bne	check_logname_loop

		clr.b	-1(a0)
		bsr	skip_space
		tst.b	(a0)
		bne	login_invalid
check_logname_done:
	*
	*  パスワード・ファイルを参照する
	*
		lea	file_passwd(pc),a1		*  パスワード・ファイルを
		bsr	open_sysfile			*  オープンする
		bmi	login_invalid

		lea	pwd_buf(a6),a0
		movea.l	logname_top(a6),a1
		bsr	fgetpwnam
		bsr	xfclose
		tst.l	d0
		bne	login_invalid

		lea	pwd_buf+PW_PASSWD(a6),a0
		tst.b	(a0)
		beq	do_login

		bra	ask_passwd

login_invalid:
		st	incorrect(a6)
ask_passwd:
	*
	*  パスワードを尋ねて照合する
	*
		lea	msg_password(pc),a1
		lea	password(a6),a0
		move.l	#MAXPASSWD,d0
		bsr	getpass
		clr.b	(a0,d0.l)
		bsr	put_newline
		tst.b	incorrect(a6)
		bne	login_incorrect

		lea	pwd_buf+PW_PASSWD(a6),a1
		bsr	strcmp
		bne	login_incorrect
do_login:
	*
	*  ユーザのディレクトリに chdir する
	*
		lea	pwd_buf+PW_DIR(a6),a0
		tst.b	(a0)
		beq	check_dir_1

		cmpi.b	#':',1(a0)
		bne	check_dir_1

		tst.b	2(a0)
		bne	check_dir_1

		lea	msg_incomplete_directory(pc),a1
		bsr	werror2
		bra	main_loop

check_dir_1:
		bsr	chdir
		bpl	chdir_ok

		lea	msg_unable_to_change_directory(pc),a1
		bsr	werror2
		bra	main_loop

chdir_ok:
	*
	*  ユーザのシェルとパラメータを決定する
	*
		lea	pwd_buf+PW_SHELL(a6),a0
		tst.b	(a0)
		beq	make_default_shell

		movea.l	a0,a1
		bsr	strspc
		move.l	a0,d0
		sub.l	a1,d0
		cmp.l	#MAXPATH,d0
		bhi	too_long_shell

		lea	shell_pathname(a6),a0
		bsr	memmovi
		clr.b	(a0)
		movea.l	a1,a0
		bsr	skip_space
		bra	shell_ok

make_default_shell:
		lea	default_shell(pc),a1
		lea	shell_pathname(a6),a0
		bsr	make_sys_pathname
		bmi	too_long_shell

		lea	default_parameter(pc),a0
shell_ok:
		bsr	strlen
		cmp.l	#255,d0
		bhi	too_long_parameter

		movea.l	a0,a1
		lea	parameter(a6),a0
		move.b	d0,(a0)+
		bsr	strcpy
	*
	*  ユーザの環境を作成する
	*
		*
		*  ユーザの環境のために最大ブロックを確保する
		*
		move.l	#$00ffffff,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		sub.l	#$81000000,d0
		move.l	d0,d1				*  D1.L : 確保可能な大きさ
		cmp.l	#5,d1
		blo	insufficient_memory_for_shell

		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		bmi	insufficient_memory_for_shell

		move.l	d0,user_envp(a6)
		movea.l	d0,a3				*  A3 : ユーザの環境
		movea.l	a3,a2
		move.l	d1,(a2)+
		subq.l	#5,d1
		*
		*  loginの環境を継承する
		*
		movea.l	login_envp(a6),a0
		cmpa.l	#-1,a0
		beq	dupenv_done

		addq.l	#4,a0
dupenv_loop:
		tst.b	(a0)
		beq	dupenv_done

		lea	word_SYSROOT(pc),a1
		bsr	envcmp
		beq	do_dupenv

		tst.b	protect_env(a6)
		beq	dupenv_next

		lea	word_LOGNAME(pc),a1
		bsr	envcmp
		beq	dupenv_next

		lea	word_USER(pc),a1
		bsr	envcmp
		beq	dupenv_next

		lea	word_HOME(pc),a1
		bsr	envcmp
		beq	dupenv_next

		lea	word_SHELL(pc),a1
		bsr	envcmp
		beq	dupenv_next
do_dupenv:
		bsr	strlen
		addq.l	#1,d0
		sub.l	d0,d1
		bcs	insufficient_memory_for_shell

		movea.l	a0,a1
		movea.l	a2,a0
		bsr	memmovi
		movea.l	a0,a2
		movea.l	a1,a0
		bra	dupenv_loop

dupenv_next:
		bsr	strfor1
		bra	dupenv_loop

dupenv_done:
		clr.b	(a2)
		*
		*  LOGNAME, USER, HOME, SHELL をセットする
		*
		lea	pwd_buf+PW_NAME(a6),a1
		lea	word_LOGNAME(pc),a0
		bsr	setenv
		bne	insufficient_memory_for_shell
		*
		lea	word_USER(pc),a0
		bsr	setenv
		bne	insufficient_memory_for_shell
		*
		lea	pwd_buf+PW_DIR(a6),a1
		lea	word_HOME(pc),a0
		bsr	setenv_path
		bne	insufficient_memory_for_shell
		*
		lea	shell_pathname(a6),a1
		lea	word_SHELL(pc),a0
		bsr	setenv_path
		bne	insufficient_memory_for_shell
		*
		*  引数からセットする
		*
		lea	envarg_top(a6),a0
		move.w	argc(a6),d7
		moveq	#0,d1
		bra	setargenv_continue

setargenv_loop:
		movea.l	a0,a1
		moveq	#'=',d0
		bsr	strchr
		exg	a0,a1
		beq	setargenv_l

		clr.b	(a1)+
		bsr	setenv
		move.b	#'=',-(a1)
		bra	setargenv_doneone

setargenv_l:
		movea.l	a0,a1
		lea	lbuf(a6),a0
		move.b	#'L',(a0)+
		move.l	d1,d0
		addq.l	#1,d1
		bsr	utoa
		subq.l	#1,a0
		bsr	setenv
		movea.l	a1,a0
setargenv_doneone:
		tst.l	d0
		bne	insufficient_memory_for_shell

		bsr	strfor1
setargenv_continue:
		dbra	d7,setargenv_loop
		*
		*  ユーザの環境を切り詰める
		*
		lea	4(a3),a0
		bsr	strazbot
		addq.l	#2,a0
		move.l	a0,d0
		sub.l	a3,d0
		bclr	#0,d0
		move.l	d0,(a3)
		move.l	d0,-(a7)
		move.l	a3,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  $HOME/%hushlogin をチェックする
	*
		link	a5,#-54
		move.w	#$37,-(a7)			*  ボリューム・ラベル以外すべて
		pea	file_hushlogin(pc)
		pea	-54(a5)
		DOS	_FILES
		lea	10(a7),a7
		unlk	a5
		tst.l	d0
		bpl	motd_done
	*
	*  A:/etc/motd を出力する
	*
		lea	file_motd(pc),a1		*  motd ファイルを
		bsr	open_sysfile			*  オープンしてみる
		bmi	motd_done

		bsr	print_file
motd_done:
	*
	*  ユーザのシェルをexecする
	*
		clr.w	child_signal(a6)
		sf	in_login(a6)
		move.l	user_envp(a6),-(a7)		*  ユーザの環境のアドレス
		pea	parameter(a6)			*  起動するプログラムへの引数のアドレス
		pea	shell_pathname(a6)		*  起動するプログラムのパス名のアドレス
		move.w	#1,-(a7)			*  ファンクション：LOAD
		DOS	_EXEC
		lea	14(a7),a7

		lea	bsstop(pc),a6
		tst.w	child_signal(a6)
		bne	shell_done

		tst.l	d0
		bmi	shell_done

		move.l	a4,-(a7)			*  エントリ・アドレス
		move.w	#4,-(a7)			*  ファンクション：EXEC
		DOS	_EXEC
		addq.l	#6,a7
shell_done:
		lea	bsstop(pc),a6
		st	in_login(a6)

		tst.l	d0
		bpl	main_loop

		lea	shell_pathname(a6),a0
		lea	msg_unable_to_execute(pc),a1
		bsr	werror2
		bra	main_loop


too_long_shell:
		lea	msg_too_long_shell(pc),a0
werror_loop:
		bsr	werror
		bra	main_loop


too_long_parameter:
		lea	msg_too_long_parameter(pc),a0
		bra	werror_loop


login_incorrect:
		lea	msg_login_incorrect(pc),a0
		bra	werror_loop


insufficient_memory_for_shell:
		lea	msg_insufficient_memory(pc),a0
		bra	werror_loop
*****************************************************************
manage_signals:
		lea	bsstop(pc),a6
		lea	stack_bottom(a6),a7
		bsr	xfclose
		tst.b	in_login(a6)
		bne	main_loop

		moveq	#1,d0
		move.w	d0,child_signal(a6)
		move.w	d0,-(a7)
		DOS	_EXIT2
*****************************************************************
nologin:
		bsr	print_file
		lea	msg_nologin(pc),a0
werror_exit:
		bsr	werror
		move.w	#1,-(a7)
		DOS	_EXIT2
*****************************************************************
not_a_tty:
		lea	msg_not_a_tty(pc),a0
		bra	werror_exit
*****************************************************************
insufficient_memory_for_me:
		lea	msg_insufficient_memory(pc),a0
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
*****************************************************************
print_file:
		move.l	d0,-(a7)
print_file_loop:
		move.w	file_handle(a6),d0
		bsr	fgetc
		bmi	print_file_done

		cmp.b	#LF,d0
		bne	print_file_1char

		bsr	put_newline
		bra	print_file_loop

print_file_1char:
		bsr	putchar
		bra	print_file_loop

print_file_done:
		move.l	(a7)+,d0
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
put_newline:
		moveq	#CR,d0
		bsr	putchar
		moveq	#LF,d0
putchar:
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		rts
*****************************************************************
make_sys_pathname:
		movem.l	d0/a0-a4,-(a7)
		movea.l	a0,a4
		movea.l	a1,a2
		movea.l	login_envp(a6),a3
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
open_sysfile:
		lea	pathname_buf(a6),a0
		bsr	make_sys_pathname
		bmi	return

		moveq	#0,d0				*  読み込みモードで
		bsr	tfopen				*  オープンする
		bmi	open_sysfile_return

		move.w	d0,file_handle(a6)
open_sysfile_return:
		rts
*****************************************************************
setenv_path:
		lea	pathname_buf(a6),a2
slash_to_backslash_loop:
		move.b	(a1)+,d0
		cmp.b	#'/',d0
		bne	slash_to_backslash_1

		moveq	#'\',d0
slash_to_backslash_1:
		move.b	d0,(a2)+
		bne	slash_to_backslash_loop

		lea	pathname_buf(a6),a1
		bra	setenv
*****************************************************************
envcmp:
		move.l	d1,-(a7)
		exg	a0,a1
		bsr	strlen
		exg	a0,a1
		move.l	d0,d1
		bsr	memcmp
		bne	envcmp_return

		move.b	(a0,d1.l),d0
		sub.b	#'=',d0
envcmp_return:
		move.l	(a7)+,d1
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## login 0.3 ##  Copyright(C)1991 by Itagaki Fumihiko',0

word_HOME:			dc.b	'HOME',0
word_LOGNAME:			dc.b	'LOGNAME',0
word_SHELL:			dc.b	'SHELL',0
word_USER:			dc.b	'USER',0
word_SYSROOT:			dc.b	'SYSROOT',0
msg_login:			dc.b	'login: ',0
msg_password:			dc.b	'Password:',0
msg_login_incorrect:		dc.b	'Login incorrect',CR,LF,0
msg_nologin:			dc.b	'Login disabled.',CR,LF,0
msg_not_a_tty:			dc.b	'Not a cooked character device.',CR,LF,0
msg_incomplete_directory:	dc.b	'Incomplete directory',0
msg_unable_to_change_directory:	dc.b	'Unable to change directory to',0
msg_unable_to_execute:		dc.b	'Unable to execute',0
msg_too_long_shell:		dc.b	'Too long shell pathname',CR,LF,0
msg_too_long_parameter:		dc.b	'Too long shell parameter',CR,LF,0
msg_insufficient_memory:	dc.b	'Insufficient memory',CR,LF,0
msg_space_quote:		dc.b	' "',0
msg_quote_crlf:			dc.b	'"'
msg_crlf:			dc.b	CR,LF,0

file_passwd:			dc.b	'/etc/passwd',0
file_nologin:			dc.b	'/etc/nologin',0
file_motd:			dc.b	'/etc/motd',0
default_shell:			dc.b	'/bin/COMMAND.X',0
file_hushlogin:			dc.b	'%hushlogin',0

str_p:				dc.b	'-p',0

default_parameter:
str_nul:			dc.b	0
*****************************************************************
.bss
.even
bsstop:
.offset 0

login_envp:	ds.l	1
user_envp:	ds.l	1
logname_top:	ds.l	1
argc:		ds.w	1
file_handle:	ds.w	1
child_signal:	ds.w	1
pwd_buf:	ds.b	PW_SIZE
logname:	ds.b	2+MAXLOGNAME+1
password:	ds.b	MAXPASSWD+1
shell_pathname:	ds.b	MAXPATH+1
parameter:	ds.b	1+255+1
login_cwd:	ds.b	MAXPATH+1
pathname_buf:	ds.b	MAXPATH+1
lbuf:		ds.b	12
in_login:	ds.b	1
incorrect:	ds.b	1
protect_env:	ds.b	1

		ds.b	STACKSIZE
.even
stack_bottom:
envarg_top:
*****************************************************************
.end start
