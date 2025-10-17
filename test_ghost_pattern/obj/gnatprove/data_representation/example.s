	.arch armv8.5-a
	.build_version macos,  14, 0
	.text
	.align	2
	.globl _example__create
_example__create:
LFB2:
	sub	sp, sp, #16
LCFI0:
	str	w0, [sp, 12]
	and	x0, x1, -4294967296
	mov	x1, x0
	ldr	w0, [sp, 12]
	bfi	x1, x0, 32, 32
	mov	x0, x1
	add	sp, sp, 16
LCFI1:
	ret
LFE2:
	.const
	.align	3
lC0:
	.ascii "example.adb"
	.space 1
	.text
	.align	2
	.globl _example__increment
_example__increment:
LFB3:
	stp	x29, x30, [sp, -32]!
LCFI2:
	mov	x29, sp
LCFI3:
	str	x0, [x29, 24]
	ldr	w1, [x29, 24]
	mov	w0, 2147483647
	cmp	w1, w0
	bne	L4
	mov	w1, 11
	adrp	x0, lC0@PAGE
	add	x0, x0, lC0@PAGEOFF;
	bl	___gnat_rcheck_CE_Overflow_Check
L4:
	ldr	w0, [x29, 24]
	add	w0, w0, 1
	str	w0, [x29, 24]
	ldr	x0, [x29, 24]
	ldp	x29, x30, [sp], 32
LCFI4:
	ret
LFE3:
	.globl _example_E
	.data
	.align	1
_example_E:
	.space 2
	.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
EH_frame1:
	.set L$set$0,LECIE1-LSCIE1
	.long L$set$0
LSCIE1:
	.long	0
	.byte	0x3
	.ascii "zR\0"
	.uleb128 0x1
	.sleb128 -8
	.uleb128 0x1e
	.uleb128 0x1
	.byte	0x10
	.byte	0xc
	.uleb128 0x1f
	.uleb128 0
	.align	3
LECIE1:
LSFDE1:
	.set L$set$1,LEFDE1-LASFDE1
	.long L$set$1
LASFDE1:
	.long	LASFDE1-EH_frame1
	.quad	LFB2-.
	.set L$set$2,LFE2-LFB2
	.quad L$set$2
	.uleb128 0
	.byte	0x4
	.set L$set$3,LCFI0-LFB2
	.long L$set$3
	.byte	0xe
	.uleb128 0x10
	.byte	0x4
	.set L$set$4,LCFI1-LCFI0
	.long L$set$4
	.byte	0xe
	.uleb128 0
	.align	3
LEFDE1:
LSFDE3:
	.set L$set$5,LEFDE3-LASFDE3
	.long L$set$5
LASFDE3:
	.long	LASFDE3-EH_frame1
	.quad	LFB3-.
	.set L$set$6,LFE3-LFB3
	.quad L$set$6
	.uleb128 0
	.byte	0x4
	.set L$set$7,LCFI2-LFB3
	.long L$set$7
	.byte	0xe
	.uleb128 0x20
	.byte	0x9d
	.uleb128 0x4
	.byte	0x9e
	.uleb128 0x3
	.byte	0x4
	.set L$set$8,LCFI3-LCFI2
	.long L$set$8
	.byte	0xd
	.uleb128 0x1d
	.byte	0x4
	.set L$set$9,LCFI4-LCFI3
	.long L$set$9
	.byte	0xde
	.byte	0xdd
	.byte	0xc
	.uleb128 0x1f
	.uleb128 0
	.align	3
LEFDE3:
	.ident	"GCC: (GNU) 15.0.1 20250418 (prerelease)"
	.subsections_via_symbols
