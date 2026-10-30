/*
 * io/m68k/trap.s - IO_$TRAP, the first-level interrupt dispatcher and
 * IO_$FLIH_TAB (SAU2, SAU5, SAU9)
 *
 * The SAU2, SAU5 and SAU9 images have the same code here except two
 * places: with `trap_page_high' (the SAU9) IO_$TRAP's vector table is
 * TRAP_PAGE, not 0, and with `interrupt_pc_histogram' (the SAU9) the
 * dispatcher stores the interrupted PC in HISTOGRAM_ADDRESS (below)
 * first.  The address and byte columns below are the SAU2 image's,
 * except on the lines of those arms, which carry the SAU9 image's.
 *
 * Byte gate (tools/asm_compare.py, `make check'): encodings identical to
 * the image; address operands resolve to our objects.
 *
 * Three pieces of the SAU2 map's IO_$TBLS segment (0xE2E800, size 0x480;
 * the rest - IO_$SAVED_OS_SP at 0xE2E822 and IO_$USE_INT_STACK at
 * 0xE2E826, io/m68k/use_int_stack.s - live elsewhere;
 * IO_$COND_SWITCH_BACK at 0xE2E846 is io/m68k/cond_switch_back.s):
 *
 *   0x00E2E800  IO_$TRAP            34 bytes
 *   0x00E2E85C  io_$flih_dispatch   36 bytes, no map symbol (the common
 *                                   interrupt entry IO_$TRAP installs)
 *   0x00E2E880  IO_$FLIH_TAB        0x400 bytes, one handler per vector,
 *                                   zero in the image
 *
 * The dispatcher reaches the table with an 8-bit PC-relative index
 * operand, so the two share a section in the image's layout.  Its
 * `bsr.b' to IO_$USE_INT_STACK crosses into that routine's section and
 * carries an R_68K_PC8 relocation; the layout (tools/gen_layout_ld.py)
 * places .text.IO_$USE_INT_STACK directly ahead of this section, within
 * reach.  IO_$TRAP reaches both with 16-bit PC-relative operands
 * (R_68K_PC16 relocations).
 */

        .include "base/config.inc"

/* -------------------------------------------------------------------------
 * HISTOGRAM_ADDRESS - with `interrupt_pc_histogram' (base/config.ins.pas:
 * the SAU9), a longword: the PC each interrupt interrupted, which the
 * dispatcher stores.  The SAU9 map's 4-byte IO_$TBLS segment in the
 * wired data, `D 3C425544 IO_$TBLS size = 4' (zero in the image), apart
 * from the rest of IO_$TBLS (0x3C434400); its own section.
 * ------------------------------------------------------------------------- */
        .if interrupt_pc_histogram
        .section ".text.HISTOGRAM_ADDRESS","ax",@progbits
        .globl  HISTOGRAM_ADDRESS
HISTOGRAM_ADDRESS:                              /* sau9 3c425544 */
        .long   0
        .endif

/* -------------------------------------------------------------------------
 * IO_$TRAP(vector, handler) - 0x00E2E800, 34 bytes
 *
 *   4(SP)  vector   word, the exception vector number
 *   6(SP)  handler  longword, the routine's address (the Pascal caller's
 *                   packing; SYSBUS_$INIT pushes a result slot first, which
 *                   the routine does not fill)
 *
 * IO_$FLIH_TAB[vector] = handler; the exception vector itself (absolute,
 * the table at 0) = io_$flih_dispatch.  No SR bracket: the caller runs
 * with interrupts in whatever state it has.
 * ------------------------------------------------------------------------- */
        .section ".text.IO_$TRAP","ax",@progbits
        .globl  IO_$TRAP

IO_$TRAP:
        move.w  (0x4,%sp),%d0                   /* 00e2e800 */
        lsl.w   #2,%d0                          /* 00e2e804 */
        movea.l (0x6,%sp),%a0                   /* 00e2e806: handler */
        lea     (IO_$FLIH_TAB:w,%pc),%a1        /* 00e2e80a: (0x74,PC) */
        move.l  %a0,(0,%a1,%d0.w)               /* 00e2e80e */
        lea     (io_$flih_dispatch:w,%pc),%a0   /* 00e2e812: (0x48,PC) */
        .if trap_page_high
        lea     (TRAP_PAGE).l,%a1               /* sau9 3c434416: vector table */
        .else
        lea     0x0.l,%a1                       /* 00e2e816: vector table */
        .endif
        move.l  %a0,(0,%a1,%d0.w)               /* 00e2e81c */
        rts                                     /* 00e2e820 */

/* -------------------------------------------------------------------------
 * io_$flih_dispatch - 0x00E2E85C, 36 bytes
 *
 * The exception entry of every vector IO_$TRAP has claimed: IPL 6, save
 * D0-D1/A0-A1, take the vector offset from the exception frame's
 * format/offset word (0x16(SP) after the 16 saved bytes; `andi.w #0xfff'),
 * fetch the handler from IO_$FLIH_TAB, move to the interrupt stack, call
 * handler(vector number) with the number pushed as a word, and leave
 * through PROC1_$INT_EXIT.
 * ------------------------------------------------------------------------- */
        .section ".text.IO_$FLIH_TAB","ax",@progbits
        .globl  IO_$FLIH_TAB

io_$flih_dispatch:
        ori.w   #0x600,%sr                      /* 00e2e85c: IPL 6 */
        movem.l %d0-%d1/%a0-%a1,-(%sp)          /* 00e2e860 */
        .if interrupt_pc_histogram
        move.l  (0x12,%sp),(HISTOGRAM_ADDRESS).l /* sau9 3c434464: the */
                                                /* interrupted PC */
        .endif
        move.w  (0x16,%sp),%d0                  /* 00e2e864: format/offset */
        andi.w  #0xfff,%d0                      /* 00e2e868: vector * 4 */
        movea.l (0x12,%pc,%d0.w),%a0            /* 00e2e86c: IO_$FLIH_TAB[] */
        lsr.w   #2,%d0                          /* 00e2e870: vector number */
        bsr.b   IO_$USE_INT_STACK               /* 00e2e872 */
        move.w  %d0,-(%sp)                      /* 00e2e874 */
        jsr     (%a0)                           /* 00e2e876 */
        addq.l  #2,%sp                          /* 00e2e878 */
        jmp     PROC1_$INT_EXIT                 /* 00e2e87a */

IO_$FLIH_TAB:
        .space  0x400                           /* 00e2e880 .. 00e2ec7f */
