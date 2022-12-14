/*
 * strcmp - compare two strings
 *
 * Copyright (c) 2012, Arm Limited.
 * SPDX-License-Identifier: MIT
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64
 */

#include <linux/linkage.h>
#include <asm/assembler.h>

#define L(l) .L ## l

#define REP8_01 0x0101010101010101
#define REP8_7f 0x7f7f7f7f7f7f7f7f
#define REP8_80 0x8080808080808080

/* Parameters and result.  */
#define src1		x0
#define src2		x1
#define result		x0

/* Internal variables.  */
#define data1		x2
#define data1w		w2
#define data2		x3
#define data2w		w3
#define has_nul		x4
#define diff		x5
#define syndrome	x6
#define tmp1		x7
#define tmp2		x8
#define tmp3		x9
#define zeroones	x10
#define pos		x11

	/* Start of performance-critical section  -- one 64B cache line.  */
ENTRY(strcmp)
	eor	tmp1, src1, src2
	mov	zeroones, #REP8_01
	tst	tmp1, #7
	b.ne	L(misaligned8)
	ands	tmp1, src1, #7
	b.ne	L(mutual_align)
	/* NUL detection works on the principle that (X - 1) & (~X) & 0x80
	   (=> (X - 1) & ~(X | 0x7f)) is non-zero iff a byte is zero, and
	   can be done in parallel across the entire word.  */
L(loop_aligned):
	ldr	data1, [src1], #8
	ldr	data2, [src2], #8
L(start_realigned):
	sub	tmp1, data1, zeroones
	orr	tmp2, data1, #REP8_7f
	eor	diff, data1, data2	/* Non-zero if differences found.  */
	bic	has_nul, tmp1, tmp2	/* Non-zero if NUL terminator.  */
	orr	syndrome, diff, has_nul
	cbz	syndrome, L(loop_aligned)
	/* End of performance-critical section  -- one 64B cache line.  */

L(end):

CPU_LE(	rev	syndrome, syndrome )
CPU_LE(	rev	data1, data1 )
	/* The MS-non-zero bit of the syndrome marks either the first bit
	   that is different, or the top bit of the first zero byte.
	   Shifting left now will bring the critical information into the
	   top bits.  */
CPU_LE(	clz	pos, syndrome )
CPU_LE(	rev	data2, data2 )
CPU_LE(	lsl	data1, data1, pos )
CPU_LE(	lsl	data2, data2, pos )
	/* But we need to zero-extend (char is unsigned) the value and then
	   perform a signed 32-bit subtraction.  */
CPU_LE(	lsr	data1, data1, #56 )
CPU_LE(	sub	result, data1, data2, lsr #56 )
CPU_LE(	ret )

	/* For big-endian we cannot use the trick with the syndrome value
	   as carry-propagation can corrupt the upper bits if the trailing
	   bytes in the string contain 0x01.  */
	/* However, if there is no NUL byte in the dword, we can generate
	   the result directly.  We can't just subtract the bytes as the
	   MSB might be significant.  */
CPU_BE(	cbnz	has_nul, 1f )
CPU_BE(	cmp	data1, data2 )
CPU_BE(	cset	result, ne )
CPU_BE(	cneg	result, result, lo )
CPU_BE(	ret )
CPU_BE(	1: )
	/* Re-compute the NUL-byte detection, using a byte-reversed value.  */
CPU_BE(	rev	tmp3, data1 )
CPU_BE(	sub	tmp1, tmp3, zeroones )
CPU_BE(	orr	tmp2, tmp3, #REP8_7f )
CPU_BE(	bic	has_nul, tmp1, tmp2 )
CPU_BE(	rev	has_nul, has_nul )
CPU_BE(	orr	syndrome, diff, has_nul )
CPU_BE(	clz	pos, syndrome )
	/* The MS-non-zero bit of the syndrome marks either the first bit
	   that is different, or the top bit of the first zero byte.
	   Shifting left now will bring the critical information into the
	   top bits.  */
CPU_BE(	lsl	data1, data1, pos )
CPU_BE(	lsl	data2, data2, pos )
	/* But we need to zero-extend (char is unsigned) the value and then
	   perform a signed 32-bit subtraction.  */
CPU_BE(	lsr	data1, data1, #56 )
CPU_BE(	sub	result, data1, data2, lsr #56 )
CPU_BE(	ret )

L(mutual_align):
	/* Sources are mutually aligned, but are not currently at an
	   alignment boundary.  Round down the addresses and then mask off
	   the bytes that preceed the start point.  */
	bic	src1, src1, #7
	bic	src2, src2, #7
	lsl	tmp1, tmp1, #3		/* Bytes beyond alignment -> bits.  */
	ldr	data1, [src1], #8
	neg	tmp1, tmp1		/* Bits to alignment -64.  */
	ldr	data2, [src2], #8
	mov	tmp2, #~0
	/* Big-endian.  Early bytes are at MSB.  */
CPU_BE(	lsl	tmp2, tmp2, tmp1 )	/* Shift (tmp1 & 63).  */
	/* Little-endian.  Early bytes are at LSB.  */
CPU_LE(	lsr	tmp2, tmp2, tmp1 )	/* Shift (tmp1 & 63).  */
	orr	data1, data1, tmp2
	orr	data2, data2, tmp2
	b	L(start_realigned)

L(misaligned8):
	/* Align SRC1 to 8 bytes and then compare 8 bytes at a time, always
	   checking to make sure that we don't access beyond page boundary in
	   SRC2.  */
	tst	src1, #7
	b.eq	L(loop_misaligned)
L(do_misaligned):
	ldrb	data1w, [src1], #1
	ldrb	data2w, [src2], #1
	cmp	data1w, #1
	ccmp	data1w, data2w, #0, cs	/* NZCV = 0b0000.  */
	b.ne	L(done)
	tst	src1, #7
	b.ne	L(do_misaligned)

L(loop_misaligned):
	/* Test if we are within the last dword of the end of a 4K page.  If
	   yes then jump back to the misaligned loop to copy a byte at a time.  */
	and	tmp1, src2, #0xff8
	eor	tmp1, tmp1, #0xff8
	cbz	tmp1, L(do_misaligned)
	ldr	data1, [src1], #8
	ldr	data2, [src2], #8

	sub	tmp1, data1, zeroones
	orr	tmp2, data1, #REP8_7f
	eor	diff, data1, data2	/* Non-zero if differences found.  */
	bic	has_nul, tmp1, tmp2	/* Non-zero if NUL terminator.  */
	orr	syndrome, diff, has_nul
	cbz	syndrome, L(loop_misaligned)
	b	L(end)

L(done):
	sub	result, data1, data2
	ret

ENDPIPROC(strcmp)
