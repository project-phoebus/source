/*
 * gpu/m68k/gpu_asm.s - the GPU_ASM data segment (SAU2, SAU9)
 *
 * The SAU2 and SAU9 images have the same bytes here; the address
 * columns below are the SAU2 image's (SAU9 map: "D 3C42ABF8 GPU_ASM
 * size = 10", GPU_$PRESENT 0x3C42ABF8, GPU_$PAGE_EC 0x3C42ABFA).  The
 * SAUs with the graphics processor's driver (`gpu_driver',
 * base/config.ins.pas) have a GPU_ASM of their own (gpu/sau5/gpu_asm.s).
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): the bytes are the
 * image's.
 *
 * SAU2 map: "D E27500 GPU_ASM size = 10" (WIRED_DATA), 0x00E27500..
 * 0x00E2750F, SOCK following at 0xE27510.  A hand-written block (the
 * `_ASM' segment name; gpu/gpu.pas has no data).  All zero in the image
 * (`gsk read 0xe27500 0x10').  Its symbols, the map's:
 *
 *   0xE27500  GPU_$PRESENT   a boolean byte (gpu/gpu.ins.pas), its pad byte
 *   0xE27502  GPU_$PAGE_EC   an eventcount, 12 bytes (zero: its waiter
 *                            list is not made self-pointing in the image,
 *                            unlike NETLOG_$EC's)
 *   0xE2750E  a zero word to the segment's end
 */

        .include "base/config.inc"
        .if !gpu_driver

        .section ".text.GPU_$PRESENT","ax",@progbits

        .globl  GPU_$PRESENT
        .globl  GPU_$PAGE_EC

GPU_$PRESENT:                                   /* e27500 */
        .byte   0, 0
GPU_$PAGE_EC:                                   /* e27502 */
        .long   0, 0, 0
        .word   0                               /* e2750e: to the segment's end */

        .endif
