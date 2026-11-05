/*
 * cold/sau7/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU7)
 *
 * The SAU7's COLD, transcribed from the SAU7 image file (file 0..0xBFC,
 * loaded at 0x1001C00; sr10.2-install/.../sau7/domain_os).  The SAU7 map:
 *
 *   D25 1001C00  COLD               loaded at 1001C00, size = D58
 *   D   1001C00  COLD_START         size = BFC
 *       1001C00  COLD
 *       1001C20  MOVE_TO_PPN
 *       1002012  COLD_REMAP_CSR_PPN .. 100201C  COLD_REMAP_FRM_CNT
 *   D   10027FC  OS_COLD            size = 15C   (os/cold.pas's data)
 *   I 3 1002958  COLD_PROC          loaded at 1002958, size = 728
 *   I   1002958  OS_COLD            size = 728   (OS_$COLD_START 1002D1E)
 *
 * This file is COLD_START: the 12-byte header, the 24-byte info block,
 * the start code and its cells, and the stack COLD runs on up to
 * 0x10027FC (`cold_stack_top', the OS_COLD module's data).  The SAU9's
 * form (cold/sau9/cold_start.s: the kernel's tables built by
 * OS_$COLD_START in the identity-mapped COLD_PROC, the MMU turned on with
 * `pmove') for the SAU7's memory, which starts at 16 MB, with the SAU6's
 * info block and CPU check (cold/sau6/cold_start.s), on an MC68030 or an
 * MC68020 with the MC68851.  In order:
 *   1. A5 = COLD; VBR = 0 (the PROM's vectors); pops the PROM's frame:
 *      the boot record's first two longwords (D1, D2) into
 *      cold_boot_params and a 7-longword block (A1); SP = cold_stack_top;
 *      the master enable register (physical 0x11600) cleared.  The 7
 *      longwords go to cold_diskless_info when boot flag bit 7 is set,
 *      or, without boot flag bit 8, when the boot device type is 2 or 6;
 *      with bit 8 only the first.
 *   2. The CPU check: `lsr.b' by 31 must leave CCR = Z alone, else a
 *      jump to the PROM's 0x414.  CACR = 9 (the instruction cache on and
 *      cleared); bit 3 of the PROM's machine id's low byte (0x103) sets
 *      cold_roadrunner (the physical cache).
 *   3. Copies the DUMP page (file 0x1800, 0x800 bytes) to its physical
 *      home, 0x1000C00, and builds the new vector page at physical
 *      0x1001800 (TRAP_PAGE's): vectors 0 and 1 kept, 2..255 the PROM's.
 *   4. The display: when the PROM's cell at physical 0x10003D0 holds
 *      0xC4000, cold_mem_flags gets bit 3; else the byte at +1 of the
 *      display registers' page at physical 0x5E800 (8 or 0xA: nothing)
 *      or at 0x5D800 (0xB: bit 0; 9: bits 4 and 0).  DUMP's physical
 *      address goes to the PROM's cell at physical 0x10003DC.
 *   5. Sizes the RAM from 16 MB with the bus-error vector (of the new
 *      page, VBR = 0x1001800) pointing past the loop: reads and rewrites
 *      each longword up to 48 MB more (capped by a size already in
 *      cold_mem_size), and keeps the size found; VBR = 0.
 *   6. With cold_roadrunner: the physical cache off (physical MMU +
 *      0x200 = 0), its tags read (physical 0x3000000), the 64 KB at
 *      physical 0x4000000 cleared, and cold_mem_flags bit 1.  PROM
 *      machine id bit 2: cold_mem_flags bit 2.
 *   7. OS_$COLD_START(boot params, mem size, mem flags, status): the
 *      kernel's translation tables; a status stops in the debugger
 *      (`trap #13').
 *   8. Turns the MMU on (cold_mmu_on, below); ROADRUNNER =
 *      cold_roadrunner; hands the display's remap cells (COLD_REMAP_*,
 *      which OS_$COLD_START fills) to CRASH_SYSTEM's (REMAP_CSR_PPN ..);
 *      clears the CPU status register (MMU) and SC_PAGE's first word,
 *      writes 0xFF01 to the memory control register (MMU + 0x100) and to
 *      its copy MMU_$PID_PRIV; probes the FPU (a line-F trap through
 *      FLINE_TRAP_VEC skips the store of M68881_EXISTS); FPX_EXISTS when
 *      bit 3 of MMU + 0x200 is clear; on an MC68030 loads TT0 from
 *      cold_tt0.
 *   9. SP = P1_STACK_BASE; OS_$INIT(&cold_boot_params,
 *      &cold_diskless_info), after a `trap #15' when boot flag bit 15 is
 *      set.
 * cold_mmu_on clears the I/O map (physical 0x17000, 2 KB); builds the
 * PROM's root table at physical 0x1000400 (its entries 0xF0..0xFF copied
 * from COLD's root table at 0x1001400, entry 0 a table of two segment
 * descriptors mapping the first 64 KB of physical memory one to one) and
 * stores its root pointer in the PROM's cells at physical 0x10003D4 and
 * 0x10003D8; loads the CPU root pointer (cold_crp) and flushes; without
 * machine id bit 2 the physical cache is off; TC = 0x80A28750
 * (cold_tc); VBR = TRAP_PAGE, the PROM's vectors (values below 0x10000)
 * rebased to the PROM's VA (+ PROM 0x3FFA0000), keeping
 * PROM_$MACHINE_ID; the page marked (0xFF at its byte 0).  Bit 2 of the
 * machine id's low byte sets M68030: without it the MC68851's cache
 * status goes to MMU + 0x300, SC_PAGE + 0xE is cleared and the physical
 * cache's register gets 0x81; with it the data cache is set on (CACR:
 * write allocate, data cache on).
 *
 * Every address of the kernel is a symbol (the map's names), the
 * physical addresses equates: the SAU7 image has no fixup table, and
 * COLD runs before the MMU is on.  The Apollo assembler's <ea>=#imm
 * forms (cmp/and/or #imm,Dn), which gas spells cmpi/andi/ori, are
 * written as `.short'.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau7 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  The address and byte columns are the SAU7 image's.
 */

        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  MOVE_TO_PPN
        .globl  cold_start_entry
        .globl  cold_mmu_on
        .globl  cold_boot_params
        .globl  cold_diskless_info
        .globl  COLD_REMAP_CSR_PPN
        .globl  COLD_REMAP_FRM_PPN
        .globl  COLD_REMAP_CSR_CNT
        .globl  COLD_REMAP_FRM_CNT

/* ---- physical layout (the loaded file and the RAM; not relocated) -------- */
        .equ    RAM_BASE,       0x01000000  /* the RAM's first byte: OS_BEGIN's physical home */
        .equ    PROM_ROOT_PHYS, 0x01000400  /* the PROM's root table (cold_mmu_on) */
        .equ    DUMP_PHYS,      0x01000C00  /* DUMP's physical home */
        .equ    RARS_PHYS,      0x01001400  /* COLD's root table (RARS's page) */
        .equ    TRAP_PAGE_PHYS, 0x01001800  /* TRAP_PAGE's (the page below COLD) */
        .equ    DUMP_LOW,       0x01003400  /* file 0x1800: the DUMP page as loaded */
        .equ    PROM_DISP_TYPE, 0x010003D0  /* the PROM's cells in OS_BEGIN's page */
        .equ    PROM_CRP,       0x010003D4  /*   its root pointer, two longwords */
        .equ    PROM_DUMP_PHYS, 0x010003DC  /*   DUMP's physical address */
        .equ    RAM_LIMIT,      0x03000000  /* the RAM's size at most (48 MB) */
        .equ    CACHE_TAGS_PHYS, 0x03000000 /* the physical cache's tags (CACHE_TAGS) */
        .equ    CACHE_RAM_PHYS, 0x04000000  /* the 64 KB cleared with the physical cache */
        .equ    MMU_PHYS,       0x00010000  /* MMU's page */
        .equ    MAST_ENBL_PHYS, 0x00011600  /* MAST_ENBL_REG's */
        .equ    IOMAP_PHYS,     0x00017000  /* IOMAP's (2 pages) */
        .equ    DISP_A_PHYS,    0x0005E800  /* the display registers' pages (DISP1) */
        .equ    DISP_B_PHYS,    0x0005D800
        .equ    PROM_MACHINE_ID_LO, 0x00000103  /* low byte of the PROM's machine id (its own page) */

/* ---- the RFC header (12 bytes) and the info block (24 bytes) ------------ */
COLD:
        .long   COLD                            | 01001c00  load address
        .long   cold_start_entry                | 01001c04  start address
        .short  7                               | 01001c08  machine type
        .short  0                               | 01001c0a
        .long   0x2000                          | 01001c0c  the kernel file offset
        .long   OS_DATA                         | 01001c10  the map's .DATA
        .long   OS_PROC                         | 01001c14  the first kernel page
        .long   0xFEED2B03                      | 01001c18  magic: word FEED, byte 2B, format version 0
        .long   0x0000415F                      | 01001c1c  split PPN: the kernel's first 0x54000 bytes stay
MOVE_TO_PPN:
        .long   0x00004200                      | 01001c20  where the pages past the split go (0x1080000)

/* ---- COLD_START --------------------------------------------------------- */
cold_start_entry:
        movea.l #COLD,%a5                       | 01001c24  2a7c 0100 1c00
        movea.l #0,%a0                          | 01001c2a  207c 0000 0000
        movec   %a0,%vbr                        | 01001c30  4e7b 8801  the PROM's vectors
        movem.l (%sp)+,%d0-%d2                  | 01001c34  4cdf 0007  D0: the return address
        movea.l (%sp)+,%a1                      | 01001c38  225f  the 7-longword block
        movem.l %d1-%d2,(cold_boot_params-COLD:w,%a5) | 01001c3a  48ed 0006 03ce
        lea     (cold_stack_top:w,%pc),%sp      | 01001c40  4ffa 0bba
        move.b  #0,(MAST_ENBL_PHYS).l           | 01001c44  13fc 0000 0001 1600
        btst    #7,(cold_boot_flags+1:w,%pc)    | 01001c4c  083a 0007 0385
        bne.s   .Lcopy_diskless                 | 01001c52  6618
        btst    #8,(cold_boot_flags:w,%pc)      | 01001c54  083a 0008 037c
        bne.s   .Lcopy_first                    | 01001c5a  661c
        cmpi.w  #2,(cold_boot_params-COLD:w,%a5) | 01001c5c  0c6d 0002 03ce  the boot device type
        beq.s   .Lcopy_diskless                 | 01001c62  6708
        cmpi.w  #6,(cold_boot_params-COLD:w,%a5) | 01001c64  0c6d 0006 03ce
        bne.s   .Lcpu_check                     | 01001c6a  6610
.Lcopy_diskless:
        movem.l (%a1)+,%d0-%d6                  | 01001c6c  4cd9 007f
        movem.l %d0-%d6,(cold_diskless_info-COLD:w,%a5) | 01001c70  48ed 007f 03da
        bra.s   .Lcpu_check                     | 01001c76  6004
.Lcopy_first:
        move.l  (%a1),(cold_diskless_info-COLD:w,%a5) | 01001c78  2b51 03da
.Lcpu_check:
        moveq   #31,%d1                         | 01001c7c  721f
        lsr.b   %d1,%d0                         | 01001c7e  e228
        move.w  %ccr,%d0                        | 01001c80  42c0
        .short  0xb07c, 0x0004                  | 01001c82  b07c 0004  cmp.w #4,%d0 (<ea>=#imm form)
        beq.s   .Lcpu_ok                        | 01001c86  6704
        jmp     (0x414).w                       | 01001c88  4ef8 0414  the PROM's
.Lcpu_ok:
        movea.l #9,%a0                          | 01001c8c  207c 0000 0009
        movec   %a0,%cacr                       | 01001c92  4e7b 8002  the instruction cache
        btst    #3,(PROM_MACHINE_ID_LO).w       | 01001c96  0838 0003 0103
        sne     (cold_roadrunner-COLD:w,%a5)    | 01001c9c  56ed 0422

        /* the DUMP page to its physical home */
        movea.l #DUMP_PHYS,%a0                  | 01001ca0  207c 0100 0c00
        move.l  #0x1ff,%d0                      | 01001ca6  203c 0000 01ff
        movea.l #DUMP_LOW,%a1                   | 01001cac  227c 0100 3400
.Lcopy_dump:
        move.l  (%a1)+,(%a0)+                   | 01001cb2  20d9
        dbf     %d0,.Lcopy_dump                 | 01001cb4  51c8 fffc

        /* the new vector page: 0 and 1 kept, 2..255 the PROM's */
        lea     (TRAP_PAGE_PHYS).l,%a1          | 01001cb8  43f9 0100 1800
        move.l  (%a1),(%a1)+                    | 01001cbe  22d1
        move.l  (%a1),(%a1)+                    | 01001cc0  22d1
        lea     (0x8).w,%a0                     | 01001cc2  41f8 0008
        move.w  #0xfd,%d0                       | 01001cc6  303c 00fd
.Lcopy_vectors:
        move.l  (%a0)+,(%a1)+                   | 01001cca  22d8
        dbf     %d0,.Lcopy_vectors              | 01001ccc  51c8 fffc

        /* the display's kind, in cold_mem_flags */
        cmpi.l  #0xc4000,(PROM_DISP_TYPE).l     | 01001cd0  0cb9 000c 4000 0100 03d0
        bne.w   .Lprobe_disp                    | 01001cda  6600 000c
        ori.l   #8,(cold_mem_flags-COLD:w,%a5)  | 01001cde  00ad 0000 0008 040e
        bra.s   .Ldisp_done                     | 01001ce6  603c
.Lprobe_disp:
        lea     (DISP_A_PHYS).l,%a0             | 01001ce8  41f9 0005 e800
        cmpi.b  #8,(1,%a0)                      | 01001cee  0c28 0008 0001
        beq.s   .Ldisp_done                     | 01001cf4  672e
        cmpi.b  #0xa,(1,%a0)                    | 01001cf6  0c28 000a 0001
        beq.s   .Ldisp_done                     | 01001cfc  6726
        lea     (DISP_B_PHYS).l,%a0             | 01001cfe  41f9 0005 d800
        cmpi.b  #0xb,(1,%a0)                    | 01001d04  0c28 000b 0001
        beq.s   .Ldisp_b                        | 01001d0a  6710
        cmpi.b  #9,(1,%a0)                      | 01001d0c  0c28 0009 0001
        bne.s   .Ldisp_done                     | 01001d12  6610
        ori.l   #0x10,(cold_mem_flags-COLD:w,%a5) | 01001d14  00ad 0000 0010 040e
.Ldisp_b:
        ori.l   #1,(cold_mem_flags-COLD:w,%a5)  | 01001d1c  00ad 0000 0001 040e
.Ldisp_done:
        move.l  #DUMP_PHYS,(PROM_DUMP_PHYS).l   | 01001d24  23fc 0100 0c00 0100 03dc

        /* size the RAM, a bus error ending the walk */
        lea     (TRAP_PAGE_PHYS).l,%a2          | 01001d2e  45f9 0100 1800
        movec   %a2,%vbr                        | 01001d34  4e7b a801
        move.l  (8,%a2),-(%sp)                  | 01001d38  2f2a 0008  the bus-error vector
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)  | 01001d3c  2b4f 03f6
        lea     (.Lmem_fault:w,%pc),%a0         | 01001d40  41fa 003a
        move.l  %a0,(8,%a2)                     | 01001d44  2548 0008
        movea.l #RAM_BASE,%a0                   | 01001d48  207c 0100 0000
        movea.l #RAM_LIMIT,%a4                  | 01001d4e  287c 0300 0000
        tst.l   (cold_mem_size-COLD:w,%a5)      | 01001d54  4aad 040a
        beq.s   .Lmem_limit                     | 01001d58  670a
        cmpa.l  (cold_mem_size:w,%pc),%a4       | 01001d5a  b9fa 02ae
        bls.s   .Lmem_limit                     | 01001d5e  6304
        movea.l (cold_mem_size:w,%pc),%a4       | 01001d60  287a 02a8
.Lmem_limit:
        adda.l  #RAM_BASE,%a4                   | 01001d64  d9fc 0100 0000
.Lmem_page:
        lea     (0x400,%a0),%a1                 | 01001d6a  43e8 0400
        cmpa.l  %a0,%a4                         | 01001d6e  b9c8
        bls.s   .Lmem_done                      | 01001d70  630e
.Lmem_word:
        move.l  (%a0),%d4                       | 01001d72  2810
        move.l  %d4,(%a0)+                      | 01001d74  20c4
        cmpa.l  %a0,%a1                         | 01001d76  b3c8
        bne.s   .Lmem_word                      | 01001d78  66f8
        bra.s   .Lmem_page                      | 01001d7a  60ee
.Lmem_fault:
        movea.l (cold_saved_sp:w,%pc),%sp       | 01001d7c  2e7a 0278
.Lmem_done:
        suba.l  #RAM_BASE,%a0                   | 01001d80  91fc 0100 0000
        move.l  %a0,(cold_mem_size-COLD:w,%a5)  | 01001d86  2b48 040a
        move.l  (%sp)+,(8,%a2)                  | 01001d8a  255f 0008
        movea.l #0,%a2                          | 01001d8e  247c 0000 0000
        movec   %a2,%vbr                        | 01001d94  4e7b a801

        /* the physical cache */
        tst.b   (cold_roadrunner-COLD:w,%a5)    | 01001d98  4a2d 0422
        beq.s   .Lno_cache                      | 01001d9c  672c
        move.b  #0,(MMU_PHYS+0x200).l           | 01001d9e  13fc 0000 0001 0200  off
        clr.w   (CACHE_TAGS_PHYS).l             | 01001da6  4279 0300 0000
        move.w  (CACHE_TAGS_PHYS).l,%d0         | 01001dac  3039 0300 0000
        movea.l #CACHE_RAM_PHYS,%a0             | 01001db2  207c 0400 0000
.Lclear_cache_ram:
        clr.l   (%a0)+                          | 01001db8  4298
        cmpa.l  #CACHE_RAM_PHYS+0x10000,%a0     | 01001dba  b1fc 0401 0000
        bne.s   .Lclear_cache_ram               | 01001dc0  66f6
        ori.l   #2,(cold_mem_flags-COLD:w,%a5)  | 01001dc2  00ad 0000 0002 040e
.Lno_cache:
        btst    #2,(PROM_MACHINE_ID_LO).w       | 01001dca  0838 0002 0103
        beq.s   .Lno_flag                       | 01001dd0  6708
        ori.l   #4,(cold_mem_flags-COLD:w,%a5)  | 01001dd2  00ad 0000 0004 040e
.Lno_flag:
        /* the kernel's translation tables */
        pea     (cold_status:w,%pc)             | 01001dda  487a 022a
        pea     (cold_mem_flags:w,%pc)          | 01001dde  487a 022e
        pea     (cold_mem_size:w,%pc)           | 01001de2  487a 0226
        pea     (cold_boot_params:w,%pc)        | 01001de6  487a 01e6
        jsr     (OS_$COLD_START).l              | 01001dea  4eb9 0100 2d1e
        adda.l  #12,%sp                         | 01001df0  dffc 0000 000c
        tst.l   (cold_status-COLD:w,%a5)        | 01001df6  4aad 0406
        beq.s   .Ltables_ok                     | 01001dfa  6702
        trap    #13                             | 01001dfc  4e4d
.Ltables_ok:
        bsr.w   cold_mmu_on                     | 01001dfe  6100 00a4
        move.b  (cold_roadrunner:w,%pc),(ROADRUNNER).l | 01001e02  13fa 021e 3c42 90ec
        move.w  (COLD_REMAP_CSR_CNT:w,%pc),(REMAP_CSR_CNT).l | 01001e0a  33fa 020e 3c42 2cf0
        move.l  (COLD_REMAP_CSR_PPN:w,%pc),(REMAP_CSR_PPN).l | 01001e12  23fa 01fe 3c42 2ce8
        move.w  (COLD_REMAP_FRM_CNT:w,%pc),(REMAP_FRM_CNT).l | 01001e1a  33fa 0200 3c42 2cf2
        move.l  (COLD_REMAP_FRM_PPN:w,%pc),(REMAP_FRM_PPN).l | 01001e22  23fa 01f2 3c42 2cec

        /* the CPU's registers */
        movea.l #MMU,%a0                        | 01001e2a  207c 3fff b400
        clr.w   (%a0)                           | 01001e30  4250  the CPU status register
        clr.w   (SC_PAGE).l                     | 01001e32  4279 3ffb 0000
        move.w  #0xff01,(0x100,%a0)             | 01001e38  317c ff01 0100  the memory control register
        move.w  #0xff01,(MMU_$PID_PRIV).l       | 01001e3e  33fc ff01 3c42 8ff4

        /* the FPU: a line-F trap skips the store */
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)  | 01001e46  2b4f 03f6
        lea     (.Lno_fpu:w,%pc),%a1            | 01001e4a  43fa 0016
        move.l  %a1,(FLINE_TRAP_VEC).l          | 01001e4e  23c9 3c40 082c
        fmove.l #0,%fpcr                        | 01001e54  f23c 9000 0000 0000
        st      (M68881_EXISTS).l               | 01001e5c  50f9 3c4a aafe
.Lno_fpu:
        movea.l (cold_saved_sp:w,%pc),%sp       | 01001e62  2e7a 0192
        btst    #3,(MMU+0x200).l                | 01001e66  0839 0003 3fff b600
        seq     (FPX_EXISTS).l                  | 01001e6e  57f9 3c4a aafc
        tst.b   (M68030).l                      | 01001e74  4a39 3c42 90ea
        beq.s   .Lno_tt0                        | 01001e7a  6708
        lea     (cold_tt0:w,%pc),%a0            | 01001e7c  41fa 01a0
        pmove   (%a0),%tt0                      | 01001e80  f010 0800
.Lno_tt0:
        /* OS_$INIT, on the process 1 stack */
        movea.l #P1_STACK_BASE,%sp              | 01001e84  2e7c 3c4e 2000
        pea     (cold_diskless_info:w,%pc)      | 01001e8a  487a 014e
        pea     (cold_boot_params:w,%pc)        | 01001e8e  487a 013e
        movea.l #OS_$INIT,%a0                   | 01001e92  207c 3c43 cdf6
        btst    #15,(cold_boot_flags:w,%pc)     | 01001e98  083a 000f 0138
        beq.s   .Lno_debug                      | 01001e9e  6702
        trap    #15                             | 01001ea0  4e4f
.Lno_debug:
        jsr     (%a0)                           | 01001ea2  4e90

/* cold_mmu_on - 0x1001EA4: the PROM's root table, the MMU on, VBR =
   TRAP_PAGE, the PROM's vectors rebased to the PROM's VA, M68030 and
   the caches. */
cold_mmu_on:
        lea     (IOMAP_PHYS).l,%a3              | 01001ea4  47f9 0001 7000
        move.w  #0x3ff,%d4                      | 01001eaa  383c 03ff
.Lclear_iomap:
        clr.w   (%a3)+                          | 01001eae  425b
        dbf     %d4,.Lclear_iomap               | 01001eb0  51cc fffc
        movea.l #RARS_PHYS+0x3C0,%a1            | 01001eb4  227c 0100 17c0  root entries 0xF0..0xFF
        movea.l #PROM_ROOT_PHYS+0x3C0,%a0       | 01001eba  207c 0100 07c0
        move.w  #15,%d1                         | 01001ec0  323c 000f
.Lcopy_root:
        move.l  (%a1)+,(%a0)+                   | 01001ec4  20d9
        dbf     %d1,.Lcopy_root                 | 01001ec6  51c9 fffc
        movea.l #PROM_ROOT_PHYS,%a0             | 01001eca  207c 0100 0400
        move.l  #PROM_ROOT_PHYS+0x13,(%a0)      | 01001ed0  20bc 0100 0413  entry 0: the table at +0x10
        adda.l  #0x10,%a0                       | 01001ed6  d1fc 0000 0010
        move.l  #0x1f0102,(%a0)+                | 01001edc  20fc 001f 0102  two segment descriptors
        move.l  #PROM_ROOT_PHYS+0x20,(%a0)+     | 01001ee2  20fc 0100 0420
        move.l  #0x1f0102,(%a0)+                | 01001ee8  20fc 001f 0102
        move.l  #PROM_ROOT_PHYS+0xA0,(%a0)+     | 01001eee  20fc 0100 04a0
        move.w  #63,%d1                         | 01001ef4  323c 003f  64 page descriptors
        moveq   #0,%d0                          | 01001ef8  7000
        .short  0x80bc, 0x0000, 0x0001          | 01001efa  80bc 0000 0001  or.l #1,%d0 (<ea>=#imm form)
.Lpage_desc:
        move.l  %d0,(%a0)+                      | 01001f00  20c0
        .short  0xd0bc, 0x0000, 0x0400          | 01001f02  d0bc 0000 0400  add.l #0x400,%d0 (<ea>=#imm form)
        dbf     %d1,.Lpage_desc                 | 01001f08  51c9 fff6
        move.l  #0xff0002,(PROM_CRP).l          | 01001f0c  23fc 00ff 0002 0100 03d4
        move.l  #PROM_ROOT_PHYS,(PROM_CRP+4).l  | 01001f16  23fc 0100 0400 0100 03d8
        lea     (cold_crp:w,%pc),%a0            | 01001f20  41fa 00a4
        pmove   (%a0),%crp                      | 01001f24  f010 4c00
        pflusha                                 | 01001f28  f000 2400
        btst    #2,(PROM_MACHINE_ID_LO).w       | 01001f2c  0838 0002 0103
        bne.s   .Lcache_kept                    | 01001f32  6608
        move.b  #0,(MMU_PHYS+0x200).l           | 01001f34  13fc 0000 0001 0200  the physical cache off
.Lcache_kept:
        move.l  #0x80a28750,(cold_tc-COLD:w,%a5) | 01001f3c  2b7c 80a2 8750 0424
        lea     (cold_tc:w,%pc),%a0             | 01001f44  41fa 00de
        pmove   (%a0),%tc                       | 01001f48  f010 4000
        move.l  #TRAP_PAGE,%d1                  | 01001f4c  223c 3c40 0800
        movec   %d1,%vbr                        | 01001f52  4e7b 1801
        move.l  (PROM_$MACHINE_ID).l,%d1        | 01001f56  2239 3c40 0900
        movea.l #TRAP_PAGE,%a0                  | 01001f5c  207c 3c40 0800
        move.l  #0xff,%d0                       | 01001f62  203c 0000 00ff
.Lrebase:
        cmpi.l  #0x10000,(%a0)                  | 01001f68  0c90 0001 0000
        bge.s   .Lrebase_next                   | 01001f6e  6c06
        addi.l  #PROM,(%a0)                     | 01001f70  0690 3ffa 0000
.Lrebase_next:
        addq.l  #4,%a0                          | 01001f76  5888
        dbf     %d0,.Lrebase                    | 01001f78  51c8 ffee
        move.l  %d1,(PROM_$MACHINE_ID).l        | 01001f7c  23c1 3c40 0900
        move.b  #0xff,(TRAP_PAGE).l             | 01001f82  13fc 00ff 3c40 0800
        btst    #2,(PROM_$MACHINE_ID+3).l       | 01001f8a  0839 0002 3c40 0903
        sne     (M68030).l                      | 01001f92  56f9 3c42 90ea
        bne.s   .Lcpu_68030                     | 01001f98  661a
        pmove   %pcsr,(MMU+0x300).l             | 01001f9a  f039 6600 3fff b700
        move.b  #0,(SC_PAGE+0xE).l              | 01001fa2  13fc 0000 3ffb 000e
        move.b  #0x81,(MMU+0x200).l             | 01001faa  13fc 0081 3fff b600
        bra.s   .Lcpu_done                      | 01001fb2  6010
.Lcpu_68030:
        movec   %cacr,%d0                       | 01001fb4  4e7a 0002
        .short  0xc07c, 0xc0ff                  | 01001fb8  c07c c0ff  and.w #0xc0ff,%d0 (<ea>=#imm form)
        .short  0x807c, 0x2900                  | 01001fbc  807c 2900  or.w #0x2900,%d0 (<ea>=#imm form)
        movec   %d0,%cacr                       | 01001fc0  4e7b 0002
.Lcpu_done:
        rts                                     | 01001fc4  4e75

/* ---- the cells (zero in the file but the CRP and TT0) ------------------- */
cold_crp:                                       | 01001fc6  the CPU root pointer:
        .long   0x00ff0002                      |   limit 0xFF, 4-byte descriptors,
        .long   RARS_PHYS                       |   the root table (RARS's page)
cold_boot_params:                               | 01001fce  D1, D2
        .long   0
        .short  0
cold_boot_flags:                                | 01001fd4  D2's low word: the boot flags
        .short  0
        .space  4
cold_diskless_info:                             | 01001fda  7 longwords
        .space  28
cold_saved_sp:                                  | 01001ff6
        .long   0
        .space  12                              | 01001ffa
cold_status:                                    | 01002006  OS_$COLD_START's status
        .long   0
cold_mem_size:                                  | 0100200a
        .long   0
cold_mem_flags:                                 | 0100200e
        .long   0
COLD_REMAP_CSR_PPN:                             | 01002012
        .long   0
COLD_REMAP_FRM_PPN:                             | 01002016
        .long   0
COLD_REMAP_CSR_CNT:                             | 0100201a
        .short  0
COLD_REMAP_FRM_CNT:                             | 0100201c
        .short  0
cold_tt0:                                       | 0100201e  TT0 for an MC68030: logical
        .long   0xf8078507                      |   0xF8xxxxxx..0xFFxxxxxx, cache inhibited
cold_roadrunner:                                | 01002022  the physical cache (machine id bit 3)
        .byte   0
        .byte   0
cold_tc:                                        | 01002024  the translation control
        .long   0

/* COLD's stack, to the end of COLD_START (0x10027FC, where the OS_COLD
   module's data begins). */
        .space  0x10027fc - 0x1002028
cold_stack_top:
