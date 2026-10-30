/*
 * cold/sau9/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU9)
 *
 * The SAU9's COLD, transcribed from the SAU9 image file (file 0..0xBFC,
 * loaded at 0x4002400; sr10.2-install/.../sau9/domain_os).  The SAU9 map:
 *
 *   D23 4002400  COLD               loaded at 4002400, size = C68
 *   D   4002400  COLD_START         size = BFC
 *       4002400  COLD
 *       40026D6  COLD_REMAP_CSR_PPN .. 40026E0  COLD_REMAP_FRM_CNT
 *   D   4002FFC  OS_COLD            size = 6C    (os/cold.pas's data)
 *   I 3 4003068  COLD_PROC          loaded at 4003068, size = 568
 *   I   4003068  OS_COLD            size = 568   (OS_$COLD_START 40033E4)
 *
 * This file is COLD_START: the 12-byte header, the 12-byte info block,
 * the start code and its cells, and the stack COLD runs on up to
 * 0x4002FFC (`cold_stack_top', the OS_COLD module's data).  Another form
 * than the SAU2's (cold/sau2/cold_start.s): the SAU9 is an MC68030 whose
 * own MMU translates through tables in memory, and the kernel's
 * tables are built by OS_$COLD_START, the OS_COLD module's routine, in the
 * identity-mapped COLD_PROC (loaded like COLD, physical = VA); COLD itself:
 *   1. A5 = COLD; VBR = 0 (the PROM's vectors); pops the PROM's frame:
 *      the boot record's first two longwords (D1, D2) into
 *      cold_boot_params, a 7-longword block (A1) and, past a word, the
 *      PROM's boot record (A2); SP = cold_stack_top.  The 7 longwords go
 *      to cold_diskless_info when boot flag bit 7 is set, or, without
 *      boot flag bit 8, when the boot device type is 2 or 6.
 *   2. CACR = 9 (the instruction cache on and cleared).
 *   3. Copies the DUMP page (file 0x1800, 0x800 bytes) to its physical
 *      home, 0x4001400 (DUMP_PHYS: the kernel's VA - 0x38400000, OS_BEGIN
 *      at the RAM's start 0x4000000), and builds the new vector page at
 *      physical 0x4002000 (TRAP_PAGE's, below COLD): vectors 0 and 1 kept,
 *      2..255 the PROM's; stores DUMP_PHYS at +0x30 of the PROM's boot
 *      record.
 *   4. Sizes the RAM from 0x4000000 with the bus-error vector (of the new
 *      page, VBR = 0x4002000) pointing past the loop: reads and rewrites
 *      each longword up to the boot record's limit (capped by a size
 *      already in cold_mem_size), and keeps the size found; VBR = 0.
 *   5. PROM_$MACHINE_ID bit 2 (of its low byte, 0x103): cold_mem_flags
 *      gets bit 2.
 *   6. OS_$COLD_START(boot params, mem size, mem flags, status): the
 *      kernel's translation tables; a status stops in the debugger
 *      (`trap #13').
 *   7. Turns the MMU on (cold_mmu_on: CRP = cold_crp, the root table at
 *      physical 0x4001C00, RARS's page; TC = cold_tc), VBR = TRAP_PAGE,
 *      rebases the PROM's vectors (values below 0x20000) to the PROM's VA
 *      (+ PROM 0x3FFE0000), keeping PROM_$MACHINE_ID, marks the page
 *      (0xFF at its byte 0), sets the data cache (CACR: write allocate,
 *      data cache on).
 *   8. Hands the display's remap cells (COLD_REMAP_*, which OS_$COLD_START
 *      fills) to CRASH_SYSTEM's (REMAP_CSR_PPN ..), probes the FPU (a
 *      line-F trap through FLINE_TRAP_VEC skips the store of
 *      M68881_EXISTS), disables the FPU (MMU_CCR bit 7) and parity
 *      (bit 2), clears the utility interrupt controller's masks
 *      (UTIL_PIC, +4), lights the LEDs off (MMU_LEDR = 0xFF);
 *   9. SP = P1_STACK_BASE; the PROM's boot record's two pointers (+0x28,
 *      +0x2C) moved from physical to VA (- 0x4000000 + OS_BEGIN), and
 *      OS_$INIT(boot params, diskless info, the record's VA), after a
 *      `trap #15' when boot flag bit 15 is set.
 *
 * Every address of the kernel is a symbol (the map's names), the
 * physical addresses equates: the SAU9 image has no fixup table, and
 * COLD runs before the MMU is on.  The Apollo assembler's <ea>=#imm
 * forms (sub/and/or #imm,Dn), which gas spells subi/andi/ori, are
 * written as `.short'.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau9 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU9 image's.
 */

        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  cold_start_entry
        .globl  cold_mmu_on
        .globl  cold_boot_params
        .globl  cold_diskless_info
        .globl  COLD_REMAP_CSR_PPN
        .globl  COLD_REMAP_FRM_PPN
        .globl  COLD_REMAP_CSR_CNT
        .globl  COLD_REMAP_FRM_CNT

/* ---- physical layout (the loaded file and the RAM; not relocated) -------- */
        .equ    RAM_BASE,       0x04000000  /* the RAM's first byte: OS_BEGIN's physical home */
        .equ    DUMP_PHYS,      0x04001400  /* DUMP's physical home (OS_BEGIN + 0x1400 - 0x38400000) */
        .equ    TRAP_PAGE_PHYS, 0x04002000  /* TRAP_PAGE's (the page below COLD) */
        .equ    DUMP_LOW,       0x04003C00  /* file 0x1800: the DUMP page as loaded */
        .equ    PROM_MACHINE_ID_LO, 0x00000103  /* low byte of the PROM's machine id (its own page) */

/* ---- the RFC header (12 bytes) and the info block (12 bytes) ------------ */
COLD:
        .long   COLD                            | 04002400  load address
        .long   cold_start_entry                | 04002404  start address
        .short  9                               | 04002408  machine type
        .short  0                               | 0400240a
        .long   0x2000                          | 0400240c  the kernel file offset (sau9.ld asserts it)
        .long   OS_DATA                         | 04002410  the map's .DATA
        .long   OS_PROC                         | 04002414  the first kernel page

/* ---- COLD_START --------------------------------------------------------- */
cold_start_entry:
        movea.l #COLD,%a5                       | 04002418  2a7c 0400 2400
        movea.l #0,%a0                          | 0400241e  207c 0000 0000
        movec   %a0,%vbr                        | 04002424  4e7b 8801  the PROM's vectors
        movem.l (%sp)+,%d0-%d2                  | 04002428  4cdf 0007  D0: the return address
        movea.l (%sp)+,%a1                      | 0400242c  225f  the 7-longword block
        addq.l  #2,%sp                          | 0400242e  548f
        movea.l (%sp)+,%a2                      | 04002430  245f  the PROM's boot record
        movem.l %d1-%d2,(cold_boot_params-COLD:w,%a5) | 04002432  48ed 0006 028e
        lea     (cold_stack_top:w,%pc),%sp      | 04002438  4ffa 0bc2
        btst    #7,(cold_boot_flags+1:w,%pc)    | 0400243c  083a 0007 0255
        bne.b   .Lcopy_diskless                 | 04002442  6618
        btst    #8,(cold_boot_flags:w,%pc)      | 04002444  083a 0008 024c
        bne.b   .Lno_diskless                   | 0400244a  661a
        cmpi.w  #2,(cold_boot_params-COLD:w,%a5) | 0400244c  0c6d 0002 028e  the boot device type
        beq.b   .Lcopy_diskless                 | 04002452  6708
        cmpi.w  #6,(cold_boot_params-COLD:w,%a5) | 04002454  0c6d 0006 028e
        bne.b   .Lno_diskless                   | 0400245a  660a
.Lcopy_diskless:
        movem.l (%a1)+,%d0-%d6                  | 0400245c  4cd9 007f
        movem.l %d0-%d6,(cold_diskless_info-COLD:w,%a5) | 04002460  48ed 007f 029a
.Lno_diskless:
        move.l  %a2,(cold_boot_record-COLD:w,%a5) | 04002466  2b4a 02b6
        movea.l #9,%a0                          | 0400246a  207c 0000 0009
        movec   %a0,%cacr                       | 04002470  4e7b 8002  the instruction cache

        /* the DUMP page to its physical home */
        movea.l #DUMP_PHYS,%a0                  | 04002474  207c 0400 1400
        move.l  #0x1ff,%d0                      | 0400247a  203c 0000 01ff
        movea.l #DUMP_LOW,%a1                   | 04002480  227c 0400 3c00
.Lcopy_dump:
        move.l  (%a1)+,(%a0)+                   | 04002486  20d9
        dbf     %d0,.Lcopy_dump                 | 04002488  51c8 fffc

        /* the new vector page: 0 and 1 kept, 2..255 the PROM's */
        lea     (TRAP_PAGE_PHYS).l,%a1          | 0400248c  43f9 0400 2000
        move.l  (%a1),(%a1)+                    | 04002492  22d1
        move.l  (%a1),(%a1)+                    | 04002494  22d1
        lea     (0x8).w,%a0                     | 04002496  41f8 0008
        move.w  #0xfd,%d0                       | 0400249a  303c 00fd
.Lcopy_vectors:
        move.l  (%a0)+,(%a1)+                   | 0400249e  22d8
        dbf     %d0,.Lcopy_vectors              | 040024a0  51c8 fffc
        movea.l (cold_boot_record:w,%pc),%a2    | 040024a4  247a 0210
        move.l  #DUMP_PHYS,(0x30,%a2)           | 040024a8  257c 0400 1400 0030

        /* size the RAM, a bus error ending the walk */
        lea     (TRAP_PAGE_PHYS).l,%a2          | 040024b0  45f9 0400 2000
        movec   %a2,%vbr                        | 040024b6  4e7b a801
        move.l  (8,%a2),-(%sp)                  | 040024ba  2f2a 0008  the bus-error vector
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)  | 040024be  2b4f 02ba
        lea     (.Lmem_fault:w,%pc),%a0         | 040024c2  41fa 003c
        move.l  %a0,(8,%a2)                     | 040024c6  2548 0008
        movea.l #RAM_BASE,%a0                   | 040024ca  207c 0400 0000
        movea.l (cold_boot_record:w,%pc),%a4    | 040024d0  287a 01e4
        movea.l (4,%a4),%a4                     | 040024d4  286c 0004  the record's limit
        tst.l   (cold_mem_size-COLD:w,%a5)      | 040024d8  4aad 02ce
        beq.b   .Lmem_limit                     | 040024dc  670a
        cmpa.l  (cold_mem_size:w,%pc),%a4       | 040024de  b9fa 01ee
        bls.b   .Lmem_limit                     | 040024e2  6304
        movea.l (cold_mem_size:w,%pc),%a4       | 040024e4  287a 01e8
.Lmem_limit:
        adda.l  #RAM_BASE,%a4                   | 040024e8  d9fc 0400 0000
.Lmem_page:
        lea     (0x400,%a0),%a1                 | 040024ee  43e8 0400
        cmpa.l  %a0,%a4                         | 040024f2  b9c8
        bls.b   .Lmem_done                      | 040024f4  630e
.Lmem_word:
        move.l  (%a0),%d4                       | 040024f6  2810
        move.l  %d4,(%a0)+                      | 040024f8  20c4
        cmpa.l  %a0,%a1                         | 040024fa  b3c8
        bne.b   .Lmem_word                      | 040024fc  66f8
        bra.b   .Lmem_page                      | 040024fe  60ee
.Lmem_fault:
        movea.l (cold_saved_sp:w,%pc),%sp       | 04002500  2e7a 01b8
.Lmem_done:
        suba.l  #RAM_BASE,%a0                   | 04002504  91fc 0400 0000
        move.l  %a0,(cold_mem_size-COLD:w,%a5)  | 0400250a  2b48 02ce
        move.l  (%sp)+,(8,%a2)                  | 0400250e  255f 0008
        movea.l #0,%a2                          | 04002512  247c 0000 0000
        movec   %a2,%vbr                        | 04002518  4e7b a801
        btst    #2,(PROM_MACHINE_ID_LO).w       | 0400251c  0838 0002 0103
        beq.b   .Lno_flag                       | 04002522  6708
        ori.l   #4,(cold_mem_flags-COLD:w,%a5)  | 04002524  00ad 0000 0004 02d2
.Lno_flag:
        /* the kernel's translation tables */
        pea     (cold_status:w,%pc)             | 0400252c  487a 019c
        pea     (cold_mem_flags:w,%pc)          | 04002530  487a 01a0
        pea     (cold_mem_size:w,%pc)           | 04002534  487a 0198
        pea     (cold_boot_params:w,%pc)        | 04002538  487a 0154
        jsr     (OS_$COLD_START).l              | 0400253c  4eb9 0400 33e4
        adda.l  #12,%sp                         | 04002542  dffc 0000 000c
        tst.l   (cold_status-COLD:w,%a5)        | 04002548  4aad 02ca
        beq.b   .Ltables_ok                     | 0400254c  6702
        trap    #13                             | 0400254e  4e4d
.Ltables_ok:
        bsr.w   cold_mmu_on                     | 04002550  6100 00c8
        move.w  (COLD_REMAP_CSR_CNT:w,%pc),(REMAP_CSR_CNT).l | 04002554  33fa 0188 3c42 14be
        move.l  (COLD_REMAP_CSR_PPN:w,%pc),(REMAP_CSR_PPN).l | 0400255c  23fa 0178 3c42 14b6
        move.w  (COLD_REMAP_FRM_CNT:w,%pc),(REMAP_FRM_CNT).l | 04002564  33fa 017a 3c42 14c0
        move.l  (COLD_REMAP_FRM_PPN:w,%pc),(REMAP_FRM_PPN).l | 0400256c  23fa 016c 3c42 14ba

        /* the FPU: a line-F trap skips the store */
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)  | 04002574  2b4f 02ba
        lea     (.Lno_fpu:w,%pc),%a1            | 04002578  43fa 001e
        move.l  %a1,(FLINE_TRAP_VEC).l          | 0400257c  23c9 3c40 102c
        bclr    #7,(MMU_CCR).l                  | 04002582  08b9 0007 3ff9 f2d0
        fmove.l #0,%fpcr                        | 0400258a  f23c 9000 0000 0000
        st      (M68881_EXISTS).l               | 04002592  50f9 3c49 9f90
.Lno_fpu:
        movea.l (cold_saved_sp:w,%pc),%sp       | 04002598  2e7a 0120
        bclr    #2,(MMU_CCR).l                  | 0400259c  08b9 0002 3ff9 f2d0
        clr.b   (UTIL_PIC).l                    | 040025a4  4239 3ff9 f2e0
        clr.b   (UTIL_PIC+4).l                  | 040025aa  4239 3ff9 f2e4
        move.b  #0xff,(MMU_LEDR).l              | 040025b0  13fc 00ff 3ff9 f800

        /* OS_$INIT, on the process 1 stack */
        movea.l #P1_STACK_BASE,%sp              | 040025b8  2e7c 3c4d 2000
        movea.l (cold_boot_record:w,%pc),%a0    | 040025be  207a 00f6
        suba.l  #RAM_BASE,%a0                   | 040025c2  91fc 0400 0000
        adda.l  #OS_BEGIN,%a0                   | 040025c8  d1fc 3c40 0000  the record's VA
        move.l  (0x28,%a0),%d0                  | 040025ce  2028 0028
        beq.w   .Lno_ptr_28                     | 040025d2  6700 0012
        .short  0x90bc                          | 040025d6  90bc 0400 0000  sub.l #RAM_BASE,%d0
        .long   RAM_BASE
        .short  0xd0bc                          | 040025dc  d0bc 3c40 0000  add.l #OS_BEGIN,%d0
        .long   OS_BEGIN
        move.l  %d0,(0x28,%a0)                  | 040025e2  2140 0028
.Lno_ptr_28:
        move.l  (0x2c,%a0),%d0                  | 040025e6  2028 002c
        beq.w   .Lno_ptr_2c                     | 040025ea  6700 0012
        .short  0x90bc                          | 040025ee  90bc 0400 0000  sub.l #RAM_BASE,%d0
        .long   RAM_BASE
        .short  0xd0bc                          | 040025f4  d0bc 3c40 0000  add.l #OS_BEGIN,%d0
        .long   OS_BEGIN
        move.l  %d0,(0x2c,%a0)                  | 040025fa  2140 002c
.Lno_ptr_2c:
        move.l  %a0,-(%sp)                      | 040025fe  2f08
        pea     (cold_diskless_info:w,%pc)      | 04002600  487a 0098
        pea     (cold_boot_params:w,%pc)        | 04002604  487a 0088
        movea.l #OS_$INIT,%a0                   | 04002608  207c 3c43 9e2e
        btst    #15,(cold_boot_flags:w,%pc)     | 0400260e  083a 000f 0082
        beq.b   .Lno_debug                      | 04002614  6702
        trap    #15                             | 04002616  4e4f
.Lno_debug:
        jsr     (%a0)                           | 04002618  4e90

/* cold_mmu_on - 0x400261A: the MMU on, VBR = TRAP_PAGE, the PROM's
   vectors rebased to the PROM's VA, the data cache on. */
cold_mmu_on:
        lea     (cold_crp:w,%pc),%a0            | 0400261a  41fa 006a
        pmove   (%a0),%crp                      | 0400261e  f010 4c00
        pflusha                                 | 04002622  f000 2400
        move.l  #0x80a28750,(cold_tc-COLD:w,%a5) | 04002626  2b7c 80a2 8750 02e2
        lea     (cold_tc:w,%pc),%a0             | 0400262e  41fa 00b2
        pmove   (%a0),%tc                       | 04002632  f010 4000
        move.l  #TRAP_PAGE,%d1                  | 04002636  223c 3c40 1000
        movec   %d1,%vbr                        | 0400263c  4e7b 1801
        move.l  (PROM_$MACHINE_ID).l,%d1        | 04002640  2239 3c40 1100
        movea.l #TRAP_PAGE,%a0                  | 04002646  207c 3c40 1000
        move.l  #0xff,%d0                       | 0400264c  203c 0000 00ff
.Lrebase:
        cmpi.l  #0x20000,(%a0)                  | 04002652  0c90 0002 0000
        bge.b   .Lrebase_next                   | 04002658  6c06
        addi.l  #PROM,(%a0)                     | 0400265a  0690 3ffe 0000
.Lrebase_next:
        addq.l  #4,%a0                          | 04002660  5888
        dbf     %d0,.Lrebase                    | 04002662  51c8 ffee
        move.l  %d1,(PROM_$MACHINE_ID).l        | 04002666  23c1 3c40 1100
        move.b  #0xff,(TRAP_PAGE).l             | 0400266c  13fc 00ff 3c40 1000
        movec   %cacr,%d0                       | 04002674  4e7a 0002
        .short  0xc07c, 0xc0ff                  | 04002678  c07c c0ff  and.w #0xc0ff,%d0
        .short  0x807c, 0x2900                  | 0400267c  807c 2900  or.w #0x2900,%d0
        movec   %d0,%cacr                       | 04002680  4e7b 0002
        rts                                     | 04002684  4e75

/* ---- the cells (zero in the file but the CRP) --------------------------- */
cold_crp:                                       | 04002686  the CPU root pointer:
        .long   0x00ff0002                      |   limit 0xFF, 4-byte descriptors,
        .long   0x04001c00                      |   the root table (RARS's page)
cold_boot_params:                               | 0400268e  9 longwords (D1, D2, ...)
        .long   0
        .short  0
cold_boot_flags:                                | 04002694  D2's low word: the boot flags
        .short  0
        .space  4
cold_diskless_info:                             | 0400269a  7 longwords
        .space  28
cold_boot_record:                               | 040026b6  the PROM's boot record
        .long   0
cold_saved_sp:                                  | 040026ba
        .long   0
        .space  12                              | 040026be
cold_status:                                    | 040026ca  OS_$COLD_START's status
        .long   0
cold_mem_size:                                  | 040026ce
        .long   0
cold_mem_flags:                                 | 040026d2
        .long   0
COLD_REMAP_CSR_PPN:                             | 040026d6
        .long   0
COLD_REMAP_FRM_PPN:                             | 040026da
        .long   0
COLD_REMAP_CSR_CNT:                             | 040026de
        .short  0
COLD_REMAP_FRM_CNT:                             | 040026e0
        .short  0
cold_tc:                                        | 040026e2  the translation control
        .long   0

/* COLD's stack, to the end of COLD_START (0x4002FFC, where the OS_COLD
   module's data begins). */
        .space  0x4002ffc - 0x40026e6
cold_stack_top:
