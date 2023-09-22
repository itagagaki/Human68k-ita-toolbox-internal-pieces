.include doscall.h

STACKSIZE	equ	2+16

.text

pause:
		lea	stack(pc),a7
		move.w	#_GETC.and.$ff,-(a7)
		DOS	_KFLUSH
		addq.l	#2,a7
		clr.w	-(a7)
		DOS	_EXIT2

.bss
		ds.b	STACKSIZE
.even
stack:

.end pause
