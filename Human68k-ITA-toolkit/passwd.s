* passwd - change password
*
* Itagaki Fumihiko 25-Aug-91  Create.
*
* Usage: passwd [ name ]

.include doscall.h
.include chrcode.h
.include limits.h
.include pwd.h

.xref DecodeHUPAIR
.xref isdigit
.xref islower
.xref issjis
.xref isspace
.xref utoa
.xref strlen
.xref strchr
.xref strcmp
.xref strcpy
.xref strfor1
.xref strazbot
.xref strazcpy
.xref skip_space
.xref getenv
.xref setenv
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
		dc.b	'#HUPAIR',0			*  HUPAIR 適合宣言
start1:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
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
	*  引数を解釈する
	*
		lea	1(a2),a0
		bsr	DecodeHUPAIR
		tst.w	d0
		bne	logname_ok

		lea	word_USER(pc),a0
		bsr	getenv
		movea.l	d0,a0
		bne	logname_ok

		lea	word_LOGNAME(pc),a0
		bsr	getenv
		movea.l	d0,a0
		beq	no_user_nor_logname
logname_ok:
		movea.l	a0,logname(a6)
		bsr	skip_space
		tst.b	(a0)
		beq	bad_logname

		movea.l	a0,a2				*  A2 : ログイン名
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
		bne	passwd_invalid
check_logname_continue:
		addq.l	#1,d1
		cmp.l	#PW_NAME_SIZE,d1
		bhi	passwd_invalid

		move.b	(a0)+,d0
		beq	check_logname_done

		bsr	isspace
		bne	check_logname_loop

		clr.b	-(a0)
check_logname_done:
		*
		*  パスワード・ファイルを参照する
		*
		lea	passwd_file(pc),a1		*  パスワード・ファイルを
		bsr	open_sysfile			*  オープンする
		bmi	passwd_invalid

		move.w	d0,d2
		lea	pwd_buf(a6),a0
		movea.l	a2,a1
		bsr	fgetpwnam
		exg	d0,d2
		bsr	fclose
		tst.l	d2
		bne	passwd_invalid

		lea	pwd_buf+PW_PASSWD(a6),a0
		tst.b	(a0)
		beq	do_passwd

		bra	ask_passwd

passwd_invalid:
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
		bne	passwd_incorrect

		lea	pwd_buf+PW_PASSWD(a6),a1
		bsr	strcmp
		bne	passwd_incorrect
do_passwd:
		moveq	#2,d7
passwd_loop:

		bra	main_loop


passwd_incorrect:
		lea	msg_passwd_incorrect(pc),a0
		bra	werror_loop
*****************************************************************
not_a_tty:
		lea	msg_not_a_tty(pc),a0
		bsr	werror
		move.w	#1,-(a7)
		DOS	_EXIT2
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
		movem.l	d0-d1,-(a7)
		move.w	d0,d1
print_file_loop:
		move.w	d1,d0
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
		movem.l	(a7)+,d0-d1
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
make_sys_pathname:
		movem.l	d1/a0-a3,-(a7)
		move.l	a0,a2				*  A2:buffer
		move.l	#MAXPATH,d1
		lea	word_SYSROOT(pc),a0
		movea.l	passwd_envp(a6),a3
		bsr	getenv
		beq	make_sys_pathname_just_copy

		movea.l	d0,a0				*  A0:$SYSROOT
		moveq	#0,d0
make_sys_pathname_head_loop:
		tst.b	(a0)
		beq	make_sys_pathname_head_done

		subq.l	#1,d1
		bcs	make_sys_pathname_return

		move.b	(a0)+,d0
		move.b	d0,(a2)+
		bsr	issjis
		bne	make_sys_pathname_head_loop

		tst.b	(a0)
		beq	make_sys_pathname_head_done

		subq.l	#1,d1
		bcs	make_sys_pathname_return

		move.b	(a0)+,(a2)+
		bra	make_sys_pathname_head_loop

make_sys_pathname_head_done:
		cmp.b	#'/',d0
		beq	make_sys_pathname_del_slash

		cmp.b	#'\',d0
		bne	make_sys_pathname_just_copy
make_sys_pathname_del_slash:
		addq.l	#1,a1
make_sys_pathname_just_copy:
		movea.l	a1,a0
		bsr	strlen
		sub.l	d0,d1
		bcs	make_sys_pathname_return

		movea.l	a2,a0
		bsr	strcpy
		moveq	#0,d1
make_sys_pathname_return:
		move.l	d1,d0
		movem.l	(a7)+,d1/a0-a3
return:
		rts
*****************************************************************
open_sysfile:
		lea	pathname_buf(a6),a0
		bsr	make_sys_pathname
		bmi	return

		moveq	#0,d0				*  読み込みモードで
		bra	tfopen				*  オープンする
*****************************************************************
.data

	dc.b	0
	dc.b	'## passwd 0.2 ##  Copyright(C)1991 by Itagaki Fumihiko',0

word_HOME:			dc.b	'HOME',0
word_LOGNAME:			dc.b	'LOGNAME',0
word_SHELL:			dc.b	'SHELL',0
word_USER:			dc.b	'USER',0
word_SYSROOT:			dc.b	'SYSROOT',0
msg_passwd:			dc.b	'passwd: ',0
msg_password:			dc.b	'Password:',0
msg_passwd_incorrect:		dc.b	'Login incorrect',CR,LF,0
msg_not_a_tty:			dc.b	'Not a cooked character device.',CR,LF,0
msg_incomplete_directory:	dc.b	'Incomplete directory',0
msg_unable_to_change_directory:	dc.b	'Unable to change directory to',0
msg_unable_to_execute:		dc.b	'Unable to execute',0
msg_too_long_shell:		dc.b	'Too long shell pathname',CR,LF,0
msg_insufficient_memory:	dc.b	'Insufficient memory',CR,LF,0
msg_space_quote:		dc.b	' "',0
msg_quote_crlf:			dc.b	'"'
msg_crlf:			dc.b	CR,LF,0

passwd_file:			dc.b	'/etc/passwd',0
default_shell:			dc.b	'/bin/COMMAND.X',0
motd_file:			dc.b	'/etc/motd',0
hushpasswd:			dc.b	'%hushpasswd',0

str_p:				dc.b	'-p',0

parameter:			dc.b	0,0
*****************************************************************
.bss
.even
bsstop:
.offset 0

passwd_envp:	ds.l	1
user_envp:	ds.l	1
argp:		ds.l	1
argc:		ds.w	1
child_signal:	ds.w	1
pwd_buf:	ds.b	PW_SIZE
logname:	ds.b	2+MAXLOGNAME+1
password:	ds.b	MAXPASSWD+1
shell_pathname:	ds.b	MAXPATH+1
pathname_buf:	ds.b	MAXPATH+1
lbuf:		ds.b	12
in_passwd:	ds.b	1
incorrect:	ds.b	1
protect_env:	ds.b	1

		ds.b	STACKSIZE
.even
stack:
*****************************************************************
.end start
