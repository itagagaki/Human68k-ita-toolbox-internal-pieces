.include doscall.h

.text

start:
		clr.w	-(a7)
		pea	filename
		DOS	_OPEN
		addq.l	#6,a7
		move.w	d0,d1
loop:
		move.w	d1,-(a7)
		pea	buf
		DOS	_FGETS
		addq.l	#6,a7
		move.l	d0,d2
		bmi	done


		move.w	#'>',-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		tst.l	d2
		beq	print_done

		lea	buf+2,a0
print_loop:
		move.b	(a0)+,d0
		cmp.b	#$20,d0
		bhs	print_1

		move.w	#'^',-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7

		move.b	-1(a0),d0
		add.b	#$40,d0
print_1:
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		subq.l	#1,d2
		bne	print_loop
print_done:
		move.w	#'<',-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		move.w	#$0d,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		move.w	#$0a,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		bra	loop

done:
		DOS	_EXIT

buf:		dc.b	255
		ds.b	1
		ds.b	256

.data

filename:	dc.b	'd:t',0

.end	start
