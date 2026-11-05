/*
 * CACHE_$FLUSH_VIRTUAL - Flush virtual address cache
 *
 * The SAU2, SAU3 and SAU5 images have the same code here; the address and
 * byte columns below are the SAU2 image's.
 *
 * On SAU2 (68010-based systems), this is a no-op since the 68010 has no
 * data cache. The function exists for API compatibility with later
 * processors (68020/030/040) that do have data caches requiring explicit
 * flushing for DMA coherency.
 *
 * On systems with data caches, this would typically:
 * - Push modified (dirty) cache lines to memory
 * - Invalidate cache entries for the specified virtual address range
 * - Ensure DMA operations see current memory contents
 *
 * Since 68010 has no cache, we simply return.
 *
 * With the part `cacr_clear_data' (base/config.ins.pas; the SAU9) the
 * routine clears the MC68030's data cache: it sets the CACR's CD bit
 * (bit 11, clear data cache) and writes it back, 0xE bytes at the
 * SAU9's 0x3C42726A, the last routine of the map's MMU_ASM:
 *   3c42726a  4e7a 0002  movec %cacr,%d0
 *   3c42726e  08c0 000b  bset #11,%d0
 *   3c427272  4e7b 0002  movec %d0,%cacr
 *   3c427276  4e75       rts
 * (checked by assembling with `m68k-elf-as -m68030' and the SAU9
 * config.inc against the image's bytes; MMU_$PURGE calls it,
 * mmu/sau9/mmu_asm.s).
 *
 * With the part `flush_virtual_68030' (the SAU7) the routine tests
 * M68030 (MMU_ASM's byte, mmu/sau7/mmu_asm.s): on an MC68030 it clears
 * the data cache as above; else it stores a zero byte at SC_PAGE + 0xE.
 * 0x1E bytes at the SAU7's 0x3C42966E (`make TARGET_SAU=sau7
 * check-asm'):
 *   3c42966e  103a fa7a            move.b (M68030,%pc),%d0
 *   3c429672  660a                 bne.s  3c42967e
 *   3c429674  13fc 0000 3ffb 000e  move.b #0,SC_PAGE+0xE
 *   3c42967c  600c                 bra.s  3c42968a
 *   3c42967e  4e7a 0002            movec  %cacr,%d0
 *   3c429682  08c0 000b            bset   #11,%d0
 *   3c429686  4e7b 0002            movec  %d0,%cacr
 *   3c42968a  4e75                 rts
 *
 * Original address: 0x00E242E2
 * Size: 2 bytes
 *
 * Assembly:
 *   00e242e2    rts                 ; Return immediately (no-op)
 */

        .include "base/config.inc"

        .section ".text.CACHE_$FLUSH_VIRTUAL","ax",@progbits
    .globl  CACHE_$FLUSH_VIRTUAL
    .type   CACHE_$FLUSH_VIRTUAL, @function

CACHE_$FLUSH_VIRTUAL:
    .if flush_virtual_68030
    move.b  (M68030:w,%pc),%d0      /* 0x3C42966E: the CPU is an MC68030 */
    bne.s   .Lflush_cacr            /* 0x3C429672 */
    move.b  #0,SC_PAGE+0xE          /* 0x3C429674 */
    bra.s   .Lflush_done            /* 0x3C42967C */
.Lflush_cacr:
    movec   %cacr,%d0               /* 0x3C42967E */
    bset    #11,%d0                 /* 0x3C429682: CD, clear data cache */
    movec   %d0,%cacr               /* 0x3C429686 */
.Lflush_done:
    .endif
    .if cacr_clear_data
    movec   %cacr,%d0               /* 0x3C42726A */
    bset    #11,%d0                 /* 0x3C42726E: CD, clear data cache */
    movec   %d0,%cacr               /* 0x3C427272 */
    .endif
    /*
     * No operation needed on 68010 - just return.
     * On 68020/030/040 this would use CPUSH or similar instructions.
     */
    rts

    .size   CACHE_$FLUSH_VIRTUAL, .-CACHE_$FLUSH_VIRTUAL
