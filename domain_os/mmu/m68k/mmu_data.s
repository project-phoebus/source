|
| mmu/m68k/mmu_data.s - the data at the head of the hand-written MMU_ASM
| segment: MMU_$PID_PRIV, M68020 and the three MMU shift/mask cells
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| Byte gate (tools/asm_compare.py, `make check-asm'): the
| image's twelve bytes.
|
| SAU2 map: "D E23D2C MMU_ASM size = 5B8", 0xE23D2C..0xE23D38, ahead of
| MMU_$INIT (mmu/m68k/init.s).  Map symbols MMU_$PID_PRIV and M68020; the
| map names nothing after M68020 up to MMU_$INIT, so the three cells
| after it are reached as MMU_$PID_PRIV + offset (their users' local
| names):
|   0xE23D2C  MMU_$PID_PRIV   word, 0: the CSR value (PID and privilege
|                             bits) MMU_$INSTALL_ASID sets and the
|                             install/remove routines write to the CSR
|   0xE23D2E  M68020          word, 0: nonzero on a 68020 CPU (COLD sets
|                             it; tested as a whole word, `tst.w')
|   0xE23D30  (+0x4)          long, 0x000FFC00: VA_TO_PTT_OFFSET_MASK
|   0xE23D34  (+0x8)          word, 3: MMU_$VA_SHIFT
|   0xE23D36  (+0xA)          word, 8: MMU_$PTT_SHIFT
| On a 68020 MMU_$INIT rewrites the three; on a 68010 the image's defaults
| stand.
|
        .include "base/config.inc"
        .if pft_mmu                     | the SAU2/SAU3/SAU5 MMU (base/config.ins.pas)

        .section ".text.MMU_$PID_PRIV","ax",@progbits
        .balign 2

        .globl  MMU_$PID_PRIV
        .globl  M68020

MMU_$PID_PRIV:                          | 0xE23D2C
        .word   0
M68020:                                 | 0xE23D2E
        .word   0
        .long   0x000FFC00              | 0xE23D30  VA_TO_PTT_OFFSET_MASK
        .word   3                       | 0xE23D34  MMU_$VA_SHIFT
        .word   8                       | 0xE23D36  MMU_$PTT_SHIFT

        .endif
