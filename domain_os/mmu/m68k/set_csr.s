/*
 * MMU_$SET_CSR - Set the ASID byte of MMU_$PID_PRIV and write the CSR
 *
 * The SAU2 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * Original address: 0x00E241F4, 16 bytes (0xE241F4..0xE24203).
 *
 * Image bytes (`gsk read 0xe241f4 16`):
 *   00e241f4  41 fa fb 36 10 af 00 05  33 d0 00 ff b4 00 4e 75
 *
 * Argument: (4,SP) a word whose LOW byte, (5,SP), is stored into the
 * HIGH byte of MMU_$PID_PRIV (0xE23D2C); the whole word is then written
 * to the CSR.
 *
 * Deviation from the image bytes, forced by separate assembly:
 *   0xE241F4  lea (-0x4ca,PC),%a0     -> lea MMU_$PID_PRIV,%a0      (+2)
 */

        .include "base/config.inc"
        .if pft_mmu                     /* the SAU2/SAU3/SAU5 MMU (base/config.ins.pas) */

        .section ".text.MMU_$SET_CSR","ax",@progbits
        .even

        .extern MMU_$PID_PRIV           /* map 0xE23D2C, mmu/m68k/mmu_data.s */
        .equ    MMU_CSR,        0x00FFB400  /* SAU2 MMU CSR (hardware) */

        .globl  MMU_$SET_CSR
        .globl  _MMU_$SET_CSR

MMU_$SET_CSR:
_MMU_$SET_CSR:
        lea     MMU_$PID_PRIV,%a0       /* 0xE241F4  41 fa fb 36 in the image */
        move.b  (5,%sp),(%a0)           /* 0xE241F8  10 af 00 05       */
        move.w  (%a0),MMU_CSR           /* 0xE241FC  33 d0 00 ff b4 00 */
        rts                             /* 0xE24202  4e 75             */

        .size   MMU_$SET_CSR, .-MMU_$SET_CSR

        .endif
