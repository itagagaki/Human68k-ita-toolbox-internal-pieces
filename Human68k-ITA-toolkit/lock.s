* lock - lock terminal
*
* Itagaki Fumihiko 16-Jun-91  Create.
*
* Usage: lock

.include doscall.h
.include chrcode.h

.xref getpass

MAXKEYLEN	EQU	64		* unsigned WORD
STACKSIZE	EQU	18+16

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bsstop(pc),a6
		lea	stack(a6),a7

		lea	msg_not_a_tty(pc),a1
		clr.l	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		and.b	#%10100000,d0
		cmp.b	#%10000000,d0			*  CHR, COOKED
		bne	error

		lea	msg_enter_key(pc),a1
		lea	key_pattern(a6),a0
		bsr	getpass2
		move.w	d1,key_length(a6)
		lea	msg_again(pc),a1
		lea	buffer(a6),a0
		bsr	getpass2
		lea	key_pattern(a6),a1
		bsr	compare
		lea	msg_keys_are_different(pc),a1
		bne	error

		pea	lock(pc)
		move.w	#_CTRLVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7

		pea	lock(pc)
		move.w	#_ERRJVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7

		lea	msg_locked(pc),a1
		bsr	puts
lock:
		lea	bsstop(pc),a6
		lea	stack(a6),a7
		lea	msg_key(pc),a1
		lea	buffer(a6),a0
		bsr	getpass2
		lea	key_pattern(a6),a1
		bsr	compare
		bne	lock

		clr.w	-(a7)
		DOS	_EXIT2

error:
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	a1,a0
		bsr	werror
		move.w	#1,-(a7)
		DOS	_EXIT2

werror:
		moveq	#0,d0
		move.b	(a0)+,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		rts
****************************************************************
getpass2:
		move.l	#MAXKEYLEN,d0
		bsr	getpass
		move.l	d0,d1
put_newline:
		lea	str_newline(pc),a1
puts:
		move.l	a1,-(a7)
		DOS	_PRINT
		addq.l	#4,a7
		rts
****************************************************************
compare:
		cmp.w	key_length(a6),d1
		bne	compare_done

		tst.w	d1
		beq	compare_done
compare_loop:
		cmpm.b	(a0)+,(a1)+
		bne	compare_done

		subq.w	#1,d1
		bne	compare_loop
compare_done:
		rts
****************************************************************
.data

	dc.b	0
	dc.b	'## lock 1.0 ##  Copyright(C)1991 by Itagaki Fumihiko',0

msg_myname:		dc.b	6,'lock: '
msg_not_a_tty:		dc.b	26,'入力が端末ではありません',CR,LF
msg_keys_are_different:	dc.b	16,'キーが違います',CR,LF
msg_enter_key:		dc.b	'キーを入力してください:',0
msg_again:		dc.b	'もう一度入力してください:',0
msg_locked:		dc.b	'ロックしました'
str_newline:		dc.b	CR,LF,0
msg_key:		dc.b	'キー:',0
****************************************************************
.bss
.even
bsstop:
.offset 0
key_length:	ds.w	1
key_pattern:	ds.b	MAXKEYLEN
buffer:		ds.b	MAXKEYLEN

		ds.b	STACKSIZE
.even
stack:
****************************************************************

.end start
