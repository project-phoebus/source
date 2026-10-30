/*
 * CACHE_$FLUSH_VIRTUAL - Flush virtual address cache
 *
 * The SAU2 and SAU5 images have the same code here; the address and
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
