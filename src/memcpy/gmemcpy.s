/* Copyright (C) 2012-2021 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include "sysdep.h"

/* Assumptions:
 *
 * ARMv8-a, AArch64, unaligned accesses.
 *
 */

#define dstin	x0
#define src	x1
#define count	x2
#define dst	x3
#define srcend	x4
#define dstend	x5
#define A_l	x6
#define A_lw	w6
#define A_h	x7
#define B_l	x8
#define B_lw	w8
#define B_h	x9
#define C_l	x10
#define C_lw	w10
#define C_h	x11
#define D_l	x12
#define D_h	x13
#define E_l	x14
#define E_h	x15
#define F_l	x16
#define F_h	x17
#define G_l	count
#define G_h	dst
#define H_l	src
#define H_h	srcend
#define tmp1	x14

//#ifndef MEMMOVE
//# define MEMMOVE memmove
//#endif
//#ifndef MEMCPY
//# define MEMCPY memcpy
//#endif

#define MEMCPY gmemcpy

/* This implementation supports both memcpy and memmove and shares most code.
   It uses unaligned accesses and branchless sequences to keep the code small,
   simple and improve performance.

   Copies are split into 3 main cases: small copies of up to 32 bytes, medium
   copies of up to 128 bytes, and large copies.  The overhead of the overlap
   check in memmove is negligible since it is only required for large copies.

   Large copies use a software pipelined loop processing 64 bytes per
   iteration.  The destination pointer is 16-byte aligned to minimize
   unaligned accesses.  The loop tail is handled by always copying 64 bytes
   from the end.
*/

//ENTRY_ALIGN (MEMCPY, 6)
.globl _gmemcpy 
//.type _gmemcpy,%function
//.p2align 6
_gmemcpy: //.cfi_startproc; nop;

	PTR_ARG (0)
	PTR_ARG (1)
	SIZE_ARG (2)

	add	srcend, src, count
	add	dstend, dstin, count
	cmp	count, 128
	b.hi	L(copy_long)
	cmp	count, 32
	b.hi	L(copy32_128)

	/* Small copies: 0..32 bytes.  */
	cmp	count, 16
	b.lo	L(copy16)
	ldp	A_l, A_h, [src]
	ldp	D_l, D_h, [srcend, -16]
	stp	A_l, A_h, [dstin]
	stp	D_l, D_h, [dstend, -16]
	ret

	/* Copy 8-15 bytes.  */
L(copy16):
	tbz	count, 3, L(copy8)
	ldr	A_l, [src]
	ldr	A_h, [srcend, -8]
	str	A_l, [dstin]
	str	A_h, [dstend, -8]
	ret

	.p2align 3
	/* Copy 4-7 bytes.  */
L(copy8):
	tbz	count, 2, L(copy4)
	ldr	A_lw, [src]
	ldr	B_lw, [srcend, -4]
	str	A_lw, [dstin]
	str	B_lw, [dstend, -4]
	ret

	/* Copy 0..3 bytes using a branchless sequence.  */
L(copy4):
	cbz	count, L(copy0)
	lsr	tmp1, count, 1
	ldrb	A_lw, [src]
	ldrb	C_lw, [srcend, -1]
	ldrb	B_lw, [src, tmp1]
	strb	A_lw, [dstin]
	strb	B_lw, [dstin, tmp1]
	strb	C_lw, [dstend, -1]
L(copy0):
	ret

	.p2align 4
	/* Medium copies: 33..128 bytes.  */
L(copy32_128):
	ldp	A_l, A_h, [src]
	ldp	B_l, B_h, [src, 16]
	ldp	C_l, C_h, [srcend, -32]
	ldp	D_l, D_h, [srcend, -16]
	cmp	count, 64
	b.hi	L(copy128)
	stp	A_l, A_h, [dstin]
	stp	B_l, B_h, [dstin, 16]
	stp	C_l, C_h, [dstend, -32]
	stp	D_l, D_h, [dstend, -16]
	ret

	.p2align 4
	/* Copy 65..128 bytes.  */
L(copy128):
	ldp	E_l, E_h, [src, 32]
	ldp	F_l, F_h, [src, 48]
	cmp	count, 96
	b.ls	L(copy96)
	ldp	G_l, G_h, [srcend, -64]
	ldp	H_l, H_h, [srcend, -48]
	stp	G_l, G_h, [dstend, -64]
	stp	H_l, H_h, [dstend, -48]
L(copy96):
	stp	A_l, A_h, [dstin]
	stp	B_l, B_h, [dstin, 16]
	stp	E_l, E_h, [dstin, 32]
	stp	F_l, F_h, [dstin, 48]
	stp	C_l, C_h, [dstend, -32]
	stp	D_l, D_h, [dstend, -16]
	ret

	.p2align 4
	/* Copy more than 128 bytes.  */
L(copy_long):
	/* Copy 16 bytes and then align dst to 16-byte alignment.  */
	ldp	D_l, D_h, [src]
	and	tmp1, dstin, 15
	bic	dst, dstin, 15
	sub	src, src, tmp1
	add	count, count, tmp1	/* Count is now 16 too large.  */
	ldp	A_l, A_h, [src, 16]
	stp	D_l, D_h, [dstin]
	ldp	B_l, B_h, [src, 32]
	ldp	C_l, C_h, [src, 48]
	ldp	D_l, D_h, [src, 64]!
	subs	count, count, 128 + 16	/* Test and readjust count.  */
	b.ls	L(copy64_from_end)

L(loop64):
	stp	A_l, A_h, [dst, 16]
	ldp	A_l, A_h, [src, 16]
	stp	B_l, B_h, [dst, 32]
	ldp	B_l, B_h, [src, 32]
	stp	C_l, C_h, [dst, 48]
	ldp	C_l, C_h, [src, 48]
	stp	D_l, D_h, [dst, 64]!
	ldp	D_l, D_h, [src, 64]!
	subs	count, count, 64
	b.hi	L(loop64)

	/* Write the last iteration and copy 64 bytes from the end.  */
L(copy64_from_end):
	ldp	E_l, E_h, [srcend, -64]
	stp	A_l, A_h, [dst, 16]
	ldp	A_l, A_h, [srcend, -48]
	stp	B_l, B_h, [dst, 32]
	ldp	B_l, B_h, [srcend, -32]
	stp	C_l, C_h, [dst, 48]
	ldp	C_l, C_h, [srcend, -16]
	stp	D_l, D_h, [dst, 64]
	stp	E_l, E_h, [dstend, -64]
	stp	A_l, A_h, [dstend, -48]
	stp	B_l, B_h, [dstend, -32]
	stp	C_l, C_h, [dstend, -16]
	ret

//END (MEMCPY)
//libc_hidden_builtin_def (MEMCPY)

