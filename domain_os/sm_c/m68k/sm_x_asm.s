|
| sm_c/m68k/sm_x_asm.s - SM_X_ASM, SM_FIX_ECC: flip the bits a storage
| module controller's ECC names
|
| SAU5 map: "I E75690 SM_X_ASM size = 6C" (.TEXT, between SM_C and
| SM_C_END_ADDR), one symbol, SM_FIX_ECC at its start: 0x6A bytes of
| code and a zero pad word.  Hand-written (the `_ASM' segment; no frame,
| D2/D6 saved by movem, the arguments read off the stack past the save):
|
|   (12,sp)  the request's block header (32 bytes)
|   (16,sp)  the data page
|   (20,sp)  the ECC words: the first (bytes 0 and 1, byte 1 high) the
|            16-bit pattern, reversed bit by bit into D1; the second
|            (bytes 2 and 3) the bit offset of the error plus 1
|
| The pattern, shifted by the offset's low three bits, is xor-ed into
| three consecutive bytes from the offset's byte (the byte index with
| its low bit flipped: the controller numbers bytes within words the
| other way), in the header for byte offsets below 32, in the page
| (less the header's 32) below 1056; beyond that nothing.  Its one
| caller, sm_c_$fix_ecc (sm_c/fix_ecc.pas), pushes three addresses
| (sm_c/sm_c.ins.pas's heading).
|
| The same bytes on the SAU3, SAU4 and SAU6 (the catalog: SM_FIX_ECC
| identical; SAU3 map: "I E6FB28 SM_X_ASM size = 6C"); no SM_X_ASM on
| the SAU2 or SAU7..SAU9.  So the file is shared and assembled under the
| storage module drivers' part, `smd_disk' (base/config.ins.pas); the
| address and byte columns below are the SAU5 image's.  The bytes were
| checked by assembling the file by hand against the SAU5 and SAU3
| images, and against the SAU6's (`m68k-elf-as -m68020', linked at the
| map's address).
|
        .include "base/config.inc"

        .if smd_disk

        .section ".text.SM_FIX_ECC","ax",@progbits
        .even

        .globl  SM_FIX_ECC

SM_FIX_ECC:                             | 0xE75690
        movem.l %d2/%d6,-(%sp)          | e75690  48e7 2200
        movea.l (20,%sp),%a1            | e75694  226f 0014
        move.b  (1,%a1),%d0             | e75698  1029 0001
        lsl.w   #8,%d0                  | e7569c  e148
        move.b  (%a1),%d0               | e7569e  1011
        moveq   #15,%d6                 | e756a0  7c0f
        clr.l   %d1                     | e756a2  4281
1:      roxr.w  #1,%d0                  | e756a4  e250
        roxl.w  #1,%d1                  | e756a6  e351
        dbf     %d6,1b                  | e756a8  51ce fffa
        move.b  (2,%a1),%d0             | e756ac  1029 0002
        lsl.w   #8,%d0                  | e756b0  e148
        move.b  (3,%a1),%d0             | e756b2  1029 0003
        subq.l  #1,%d0                  | e756b6  5380
        move.b  %d0,%d2                 | e756b8  1400
        .word   0xc43c,0x0007           | e756ba  and.b #7,%d2
        lsl.l   %d2,%d1                 | e756be  e5a9
        lsr.w   #3,%d0                  | e756c0  e648
        moveq   #2,%d2                  | e756c2  7402
2:      .word   0xb07c,0x0020           | e756c4  cmp.w #32,%d0
        bge.s   3f                      | e756c8  6c06
        movea.l (12,%sp),%a0            | e756ca  206f 000c
        bra.s   4f                      | e756ce  6010
3:      .word   0xb07c,0x0420           | e756d0  cmp.w #1056,%d0
        bge.s   5f                      | e756d4  6c1e
        movea.l (16,%sp),%a0            | e756d6  206f 0010
        .word   0x91fc,0x0000,0x0020    | e756da  suba.l #32,%a0
4:      eori.w  #1,%d0                  | e756e0  0a40 0001
        adda.w  %d0,%a0                 | e756e4  d0c0
        eor.b   %d1,(%a0)               | e756e6  b310
        lsr.l   #8,%d1                  | e756e8  e089
        eori.w  #1,%d0                  | e756ea  0a40 0001
        addq.l  #1,%d0                  | e756ee  5280
        dbf     %d2,2b                  | e756f0  51ca ffd2
5:      movem.l (%sp)+,%d2/%d6          | e756f4  4cdf 0044
        rts                             | e756f8  4e75
        .word   0                       | e756fa  0000

        .endif
