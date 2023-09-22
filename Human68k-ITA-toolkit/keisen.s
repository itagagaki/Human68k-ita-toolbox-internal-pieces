*********************************************
*  Filename A:/usr/pds/keisen.X
*  Time Stamp Date 90-06-11
*             Time  0:00:00
*
*  Base address 000000
*  Exec address 0000b4
*  Text size    0001e2 bytes
*  Data size    0000e0 byte(s)
*  Bss  size    000000 byte(s)
*  33 Labels
*  Code Generate date Fri Sep 20 22:51:39 1991
*  Command Line D:\dis.x A:/usr/pds/keisen.X keisen.s 
*          DIS.X version 1.00d
*********************************************
	.include	doscall.mac
	.include	iocscall.mac
	.include	fefunc.h

****************************************************************
	.text

resident_top:
	.dc.b	'KEISEN_DRIVE V1.xx',$00,$00

org_keyinp:		.ds.l	1
org_keyinp_offset	equ	org_keyinp-resident_top

org_keysns:		.ds.l	1
org_keysns_offset	equ	org_keysns-resident_top
****************
alt_keyinp:
alt_keyinp_offset	equ	alt_keyinp-resident_top
		movem.l	d1/a0,-(a7)
		tst.b	L0000b2
		bne	L000052

		move.l	org_keyinp,$00000400
		IOCS	_B_KEYINP
		lea	alt_keyinp(pc),a0
		move.l	a0,$00000400

		move.l	d0,d1
		IOCS	_B_SFTSNS
		exg	d0,d1
		btst	#1,d1
		beq	leave

		moveq	#0,d1
		cmp.b	#',',d0
		beq	keisen_ok

		cmp.b	#'0',d0
		blo	leave

		cmp.b	#'9',d0
		bhi	leave

		sub.b	#'0'-1,d0
		moveq	#0,d1
		move.b	d0,d1
keisen_ok:
		lsl.l	#1,d1
		lea	keisenmap(pc),a0
		move.b	1(a0,d1.l),d0
		move.b	d0,L0000b2
		move.l	#$100,d0
		move.b	(a0,d1.l),d0
leave:
		movem.l	(a7)+,d1/a0
		rts

L000052:
		move.l	#$100,d0
		move.b	L0000b2(pc),d0
		clr.b	L0000b2
		bra	leave
****************
alt_keysns:
alt_keysns_offset	equ	alt_keysns-resident_top
		tst.b	L0000b2
		beq	do_org_keysns

		move.l	#$00000100,d0
		move.b	L0000b2(pc),d0
		rts

do_org_keysns:
		move.l	a0,-(a7)
		move.l	org_keysns,$00000404
		IOCS	_B_KEYSNS
		lea	alt_keysns(pc),a0
		move.l	a0,$00000404
		movea.l	(a7)+,a0
		rts

keisenmap:	.dc.b	'│─└┴┘├┼┤┌┬┐'

L0000ae:
		.dc.l	0
L0000b2:
		.dc.b	0
		.dc.b	0
resident_bot:
****************************************************************
start:
		bsr	L000194
		cmpa.l	a4,a5
		beq	L0000c4

		sne.b	L0002c0
		movea.l	a5,a4
L0000c4:
		pea.l	msg_title(pc)
		DOS	_PRINT
L0000ca:
		move.b	(a2)+,d2
		beq	L000108

		cmp.b	#$20,d2
		beq	L0000ca

		cmp.b	#$09,d2
		beq	L0000ca

		cmp.b	#'?',d2
		beq	L00017c

		cmp.b	#'/',d2
		beq	L0000f0

		cmp.b	#'-',d2
		beq	L0000f0

		bra	L0000ca
L0000f0:
		move.b	(a2)+,d2
		cmp.b	#'?',d2
		beq	L00017c

		or.b	#$20,d2
		cmp.b	#'r',d2
		beq	L000134

		subq.l	#1,a2
		bra	L0000ca

L000108:
		tst.b	L0002c0
		bne	L000188

		pea.l	alt_keyinp(pc)
		move.w	#$0100,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		move.l	d0,org_keyinp

		pea.l	alt_keysns(pc)
		move.w	#$0101,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		move.l	d0,org_keysns

		pea.l	msg_resident(pc)
		DOS	_PRINT

		clr.w	-(a7)
		lea	resident_top(pc),a0
		lea	resident_bot(pc),a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		DOS	_KEEPPR

L000134:
		tst.b	L0002c0
		bne	L000144

		pea.l	msg_cannot_release(pc)
		bra	error_exit

L000144:
		lea	org_keysns_offset(a4),a5
		move.l	(a5),-(a7)
		move.w	#$0101,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		move.l	d0,d1

		lea	org_keyinp_offset(a4),a5
		move.l	(a5),-(a7)
		move.w	#$0100,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7

		lea	alt_keyinp_offset(a4),a5
		cmpa.l	d0,a5
		bne	cannot_release

		lea	alt_keysns_offset(a4),a5
		cmpa.l	d1,a5
		bne	cannot_release

		movea.l	a4,a5
		suba.l	#$000000f0,a5
		pea.l	(a5)
		DOS	_MFREE
		pea.l	msg_release(pc)
exit_successfully:
		DOS	_PRINT
		move.w	#0,-(a7)
		DOS	_EXIT2

L00017c:
		pea.l	msg_describe(pc)
		bra	exit_successfully

cannot_release:
		move.l	d0,-(a7)
		move.w	#$0100,-(a7)
		DOS	_INTVCS

		move.l	d1,-(a7)
		move.w	#$0101,-(a7)
		DOS	_INTVCS

		pea.l	msg_cannot_release(pc)
		bra	error_exit

L000188:
		pea.l	msg_how_to_release(pc)
error_exit:
		DOS	_PRINT
		move.w	#1,-(a7)
		DOS	_EXIT2

L000194:
		movem.l	d0-d7/a0-a4/a6,-(a7)

		clr.l	-(a7)
		DOS	_SUPER
		addq.l	#4,a7
		move.l	d0,L0000ae

		movea.l	a4,a5
		movea.l	a0,a1
L0001a8:
		move.l	(a0),d0
		beq	L0001d2

		movea.l	d0,a0
		lea	$100(a0),a3
		lea	$100(a1),a2
L0001be:
		cmpm.b	(a2)+,(a3)+
		bne	L0001a8

		moveq.l	#$ff,d7
		tst.b	(a2,d7.l)
		bne	L0001be

		movea.l	a0,a5
		adda.l	#$100,a5
L0001d2:
		move.l	L0000ae,-(a7)
		DOS	_SUPER
		addq.l	#4,a7
		movem.l	(a7)+,d0-d7/a0-a4/a6
		rts

	.data

msg_title:
	.dc.b	$8c,$72,$90,$fc,$93,$fc,$97,$cd
	.dc.b	$83,$68,$83,$89,$83,$43,$83,$6f
	.dc.b	$20,$f3,$56,$f3,$45,$f3,$52,$f3
	.dc.b	$53,$f3,$49,$f3,$4f,$f3,$4e,$20
	.dc.b	$31,$2e,$30,$30,$20,$f3,$50,$f3
	.dc.b	$52,$f3,$4f,$f3,$47,$f3,$52,$f3
	.dc.b	$41,$f3,$4d,$f3,$45,$f3,$44,$20
	.dc.b	$f3,$42,$f3,$59,$20,$41,$2e,$4b
	.dc.b	$4f,$55,$53,$41,$4b,$41,$0d,$0a
	.dc.b	$00
msg_release:		.dc.b	'常駐解除しました。',$0d,$0a,$00
msg_resident:		.dc.b	'常駐しました。',$0d,$0a,$00
msg_cannot_release:	.dc.b	'常駐解除出来ません。',$0d,$0a,$00
msg_how_to_release:	.dc.b	'常駐解除は -R です。',$0d,$0a,$00
msg_vector_is_occupied:	.dc.b	'ベクタが使用されています。',$0d,$0a,$00
msg_describe:		.dc.b	'OPT1+テンキーで罫線入力をします。',$0d,$0a,$00
L0002c0:
	.dc.b	$00,$00

	.end	start
