|
| cold/sau8/cold_start.s - the RFC header, the info block and COLD_START
| (SAU8)
|
| The SAU8's COLD, transcribed from the SAU8 image file (file 0..0xC00,
| loaded at 0x101C00; sr10.2-install/.../sau8/domain_os) in the
| conventions of the SAU2's (cold/sau2/cold_start.s, whose description of
| the RFC header, the info block, the fixup table and the MMU map table
| applies): one section, A5 = COLD with every displacement a difference
| of two of its labels, every RELOC cell a symbol reference, the Apollo
| assembler's <ea>=#imm forms as `.short', the image's branch sizes.
| The SAU8 map:
|
|   D23  101C00  COLD               loaded at 101C00, size = BFC
|   D    101C00  COLD_START         size = BFC
|        101C00  COLD
|        101C20  MOVE_TO_PPN
|        1022DE  COLD_REMAP_CSR_PPN
|        1022E2  COLD_REMAP_FRM_PPN
|        1022E6  COLD_REMAP_CSR_CNT
|        1022E8  COLD_REMAP_FRM_CNT
|
| The section is 0xC00 bytes: the map's 0xBFC and the image's four zero
| bytes before DUMP at file 0xC00.
|
| What COLD does, in order (addresses are the SAU8 image's):
|   - takes the PROM's boot parameters off the stack (D1, D2 into
|     cold_boot_params; for a diskless boot, boot devices 2 and 6, or
|     with the boot flags' bit 7, the seven longwords of
|     cold_diskless_info, else one);
|   - checks the CPU is an MC68020 (`lsr.b' by 31 leaves Z set only
|     there; else the PROM's abort at 0x414) and turns its cache on;
|   - with the MC68851 (bit 5 of the boot flags' low byte; MMU_$HAVE_PMMU
|     is set from it) applies the RFC fixup table: every cell's value,
|     masked to 26 bits, from PROT up is moved by the window it falls in
|     (PROT .. OS_PMAP0, OS_PMAP0 .. SMAPS_END, .. RARS_END, .. MST,
|     .. 0x3F80000, the rest), for the PMMU's 32-bit layout
|     (`run_time_layout'), and the first map entry's VA with them;
|   - copies the DUMP page (file 0xC00) to physical 0x100C00, and the
|     PROM's vectors to the new trap page at physical 0x101800 (VBR);
|   - finds the display (the boards at physical 0x5E800, 0x5D800: their
|     type bytes 8/0xA, 0xB, 9) and fills the display entries of the map
|     table and the COLD_REMAP_* cells from them (CRASH_SYSTEM's
|     REMAP_DISPLAY maps them, `crash_remap_cold_display');
|   - sizes the kernel's page counts (the low piece up to the split, the
|     high piece at MOVE_TO_PPN), clears the MMAP, sizes the memory from
|     physical 0x100000 to 0x900000 a page at a time with the bus-error
|     vector pointed at the probe's recovery (a missing 256 KB is
|     skipped), marking each page's MMAP entry present;
|   - builds the translation tables from the map table (cold_map_pages):
|     the root tables at physical 0x101400, the segment descriptors in
|     SMAPS and the page descriptors in OS_PMAPS, global or private by
|     the entry's VA, the MMAP's wire bits from the entry's flags;
|   - turns the translation on: with the MC68851 `pmove crp', `pflusha'
|     and `pmove tc' (0x80A47650), else the DN3000 MMU's registers
|     through the function-code space (`moves');
|   - sets the PROM's I/O table at 0x200 (OS_BEGIN, OS_BEGIN + 0x180,
|     DISP1, DISP1_MEM, SIO, MMU, MMU + 0x100), the tables' physical
|     addresses in DUMP and MMU_ASM, the CPU control register and
|     MMU_$PID_PRIV, MMU_$HAVE_PMMU, the function codes; probes the
|     MC68881 (M68881_EXISTS) with the line-F vector pointed past it;
|   - enters OS_$INIT on the P1 stack with the boot parameters and the
|     diskless info (`trap #15' first with boot flag 15).
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau8 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU8 image's (physical,
| as loaded).
|

        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  MOVE_TO_PPN
        .globl  COLD_REMAP_CSR_PPN
        .globl  COLD_REMAP_FRM_PPN
        .globl  COLD_REMAP_CSR_CNT
        .globl  COLD_REMAP_FRM_CNT
        .globl  cold_start_entry
        .globl  cold_map_pages
        .globl  cold_map_table
        .globl  cold_boot_params
        .globl  cold_diskless_info

/* ---- the kernel's layout: symbols the linker script defines        */
/*      OS_DATA      map 0x3C8D800: VA of `.DATA'                      */
/*      OS_PROC      map 0x3C00C00: the first kernel page              */
/*      OS_BEGIN     map 0x3C00000: the bottom of the kernel's VA window */
/*      RELOC        map 0x3CA65F8: the first byte after the last loaded byte */
/*      OS_PAGE_END  map 0x3CF6400: the end of the pages COLD maps      */

/* ---- physical layout of the loaded file (not relocated) ----------- */
        .equ    COLD_LOW,       0x00101C00  /* the RFC load address: file byte 0, COLD */
        .equ    KERNEL_LOW,     0x00103000  /* file 0x1400: the first kernel page, PPN 0x40C */
        .equ    SPLIT_LOW,      0x00157C00  /* 0x55F << 10: file pages from here on are loaded at MOVE_TO_PPN */
        .equ    KERNEL_LO_BYTES, 0x00054C00 /* SPLIT_LOW - KERNEL_LOW: kernel bytes in the low piece */

/* ---- MMU map table entry flags (bits 31..29 of the VA field) ------ */
        .equ    MAP_WIRED,      0x80000000  /* kernel page: MMAP wire_count 0x80 */
        .equ    MAP_COLD,       0x40000000  /* COLD's pages: MMAP wire_count 0x40 */

/*
 * The RFC header, 0x101C00 (12 bytes): load address, start address,
 * machine type WORD (SAU 8), zero word; then the info block (24 bytes).
 * The loader reads them as physical addresses; the binder listed only
 * the info block's OS_DATA and OS_PROC in RELOC.
 */
COLD:
        .long   COLD_LOW                | 101c00  load: file byte 0 lands here
        .long   COLD_LOW + 0x24         | 101c04  start: cold_start_entry
        .short  0x0008                  | 101c08  machine type: SAU 8
        .short  0x0000                  | 101c0a
        .long   0x00001400              | 101c0c  file offset of the first kernel page
        .long   OS_DATA                 | 101c10  OS_DATA; a RELOC cell
        .long   OS_PROC                 | 101c14  the first kernel page; a RELOC cell
        .long   0xFEED2B03              | 101c18  magic: word FEED, byte 2B, format version 3
        .long   0x0000055F              | 101c1c  split PPN (SPLIT_LOW >> 10)
MOVE_TO_PPN:
        .long   0x00000600              | 101c20  where the pages past the split go (0x180000)

cold_start_entry:
        movea.l #COLD,%a5                       | 101c24  2a7c 0010 1c00
        movea.l #0,%a0                          | 101c2a  207c 0000 0000
        movec   %a0,%vbr                        | 101c30  4e7b 8801
        movem.l (%sp)+,%d0-%d2                  | 101c34  4cdf 0007
        movea.l (%sp)+,%a1                      | 101c38  225f
        movem.l %d1-%d2,(cold_boot_params-COLD:w,%a5)             | 101c3a  48ed 0006 06a6
        lea     (cold_stack_top,%pc),%sp              | 101c40  4ffa 0bba
        btst    #7,(cold_boot_params+7,%pc)               | 101c44  083a 0007 0665
        bne.s   .Lcopy_diskless                        | 101c4a  6618
        btst    #8,(cold_boot_params+6,%pc)               | 101c4c  083a 0008 065c
        bne.s   .Lcopy_one                        | 101c52  661c
        cmpi.w  #2,(cold_boot_params-COLD:w,%a5)                  | 101c54  0c6d 0002 06a6
        beq.s   .Lcopy_diskless                        | 101c5a  6708
        cmpi.w  #6,(cold_boot_params-COLD:w,%a5)                  | 101c5c  0c6d 0006 06a6
        bne.s   .Lcpu_check                        | 101c62  6610
.Lcopy_diskless:
        movem.l (%a1)+,%d0-%d6                  | 101c64  4cd9 007f
        movem.l %d0-%d6,(cold_diskless_info-COLD:w,%a5)             | 101c68  48ed 007f 06b2
        bra.s   .Lcpu_check                        | 101c6e  6004
.Lcopy_one:
        move.l  (%a1),(cold_diskless_info-COLD:w,%a5)               | 101c70  2b51 06b2
.Lcpu_check:
        moveq   #0x1f,%d1                       | 101c74  721f
        lsr.b   %d1,%d0                         | 101c76  e228
        move.w  %ccr,%d0                        | 101c78  42c0
        .short  0xb07c, 0x0004                  | 101c7a  b07c 0004  cmp.w #4,%d0 (<ea>=#imm form)
        beq.s   .Lcpu_ok                        | 101c7e  6704
        jmp     (0x414).w                       | 101c80  4ef8 0414
.Lcpu_ok:
        movea.l #9,%a0                          | 101c84  207c 0000 0009
        movec   %a0,%cacr                       | 101c8a  4e7b 8002
        btst    #5,(cold_boot_params+7,%pc)               | 101c8e  083a 0005 061b
        beq.w   .Lno_fixups                        | 101c94  6700 00c4
        movea.l #RELOC,%a0                      | 101c98  207c 03ca 65f8
        suba.l  #OS_PROC,%a0              | 101c9e  91fc 03c0 0c00
        adda.l  #0x103000,%a0                   | 101ca4  d1fc 0010 3000
        cmpa.l  #0x157c00,%a0                   | 101caa  b1fc 0015 7c00
        bgt.s   .Lreloc_high                        | 101cb0  6e02
        trap    #0xf                            | 101cb2  4e4f
.Lreloc_high:
        suba.l  #0x157c00,%a0                   | 101cb4  91fc 0015 7c00
        move.l  (MOVE_TO_PPN,%pc),%d2           | 101cba  243a ff64
        lsl.l   #5,%d2                          | 101cbe  eb8a
        lsl.l   #5,%d2                          | 101cc0  eb8a
        movea.l %d2,%a2                         | 101cc2  2442
        adda.l  %a2,%a0                         | 101cc4  d1ca
        move.w  (%a0)+,%d0                      | 101cc6  3018
        subq.w  #1,%d0                          | 101cc8  5340
        move.l  #PROT,%d1                       | 101cca  223c 039c 0000
        move.l  #OS_PMAP0,%d2                   | 101cd0  243c 03cf 2800
        move.l  #RARS_END,%d3                   | 101cd6  263c 03db 6c00
        move.l  #SMAPS_END,%d4                  | 101cdc  283c 03da f800
        move.l  #MST,%d5                        | 101ce2  2a3c 03e4 dc00
        move.l  #0x3f80000,%d6                  | 101ce8  2c3c 03f8 0000
.Lfixup_next:
        movea.l (%a0)+,%a1                      | 101cee  2258
        cmpa.l  #0x157c00,%a1                   | 101cf0  b3fc 0015 7c00
        blt.s   .Lfixup_cell                        | 101cf6  6d08
        suba.l  #0x157c00,%a1                   | 101cf8  93fc 0015 7c00
        adda.l  %a2,%a1                         | 101cfe  d3ca
.Lfixup_cell:
        move.l  (%a1),%d7                       | 101d00  2e11
        .short  0xcebc, 0x03ff, 0xffff          | 101d02  cebc 03ff ffff  and.l #0x3ffffff,%d7 (<ea>=#imm form)
        cmp.l   %d1,%d7                         | 101d08  be81
        blt.s   .Lfixup_step                        | 101d0a  6d42
        cmp.l   %d2,%d7                         | 101d0c  be82
        bge.s   .Lfixup_w2                        | 101d0e  6c08
        addi.l  #0xb600000,(%a1)                | 101d10  0691 0b60 0000
        bra.s   .Lfixup_step                        | 101d16  6036
.Lfixup_w2:
        cmp.l   %d4,%d7                         | 101d18  be84
        bge.s   .Lfixup_w3                        | 101d1a  6c08
        addi.l  #0xb60a000,(%a1)                | 101d1c  0691 0b60 a000
        bra.s   .Lfixup_step                        | 101d22  602a
.Lfixup_w3:
        cmp.l   %d3,%d7                         | 101d24  be83
        bge.s   .Lfixup_w4                        | 101d26  6c08
        addi.l  #0xb896800,(%a1)                | 101d28  0691 0b89 6800
        bra.s   .Lfixup_step                        | 101d2e  601e
.Lfixup_w4:
        cmp.l   %d5,%d7                         | 101d30  be85
        bge.s   .Lfixup_w5                        | 101d32  6c08
        addi.l  #0xb89c000,(%a1)                | 101d34  0691 0b89 c000
        bra.s   .Lfixup_step                        | 101d3a  6012
.Lfixup_w5:
        cmp.l   %d6,%d7                         | 101d3c  be86
        bge.s   .Lfixup_w6                        | 101d3e  6c08
        addi.l  #0xb9d5800,(%a1)                | 101d40  0691 0b9d 5800
        bra.s   .Lfixup_step                        | 101d46  6006
.Lfixup_w6:
        addi.l  #0xc000000,(%a1)                | 101d48  0691 0c00 0000
.Lfixup_step:
        dbf     %d0,.Lfixup_next                    | 101d4e  51c8 ff9e
        addi.l  #0xb600000,(cold_map_table-COLD+4:w,%a5)          | 101d52  06ad 0b60 0000 060a
.Lno_fixups:
        movea.l #0x100c00,%a0                   | 101d5a  207c 0010 0c00
        move.l  #0x1ff,%d0                      | 101d60  203c 0000 01ff
        movea.l #0x102800,%a1                   | 101d66  227c 0010 2800
.Lcopy_dump:
        move.l  (%a1)+,(%a0)+                   | 101d6c  20d9
        dbf     %d0,.Lcopy_dump                    | 101d6e  51c8 fffc
        lea     (0x101800).l,%a1                | 101d72  43f9 0010 1800
        move.l  (%a1),(%a1)+                    | 101d78  22d1
        move.l  (%a1),(%a1)+                    | 101d7a  22d1
        lea     (0x8).w,%a0                     | 101d7c  41f8 0008
        move.w  #0xfd,%d0                       | 101d80  303c 00fd
.Lcopy_vectors:
        move.l  (%a0)+,(%a1)+                   | 101d84  22d8
        dbf     %d0,.Lcopy_vectors                    | 101d86  51c8 fffc
        lea     (0x5e800).l,%a0                 | 101d8a  41f9 0005 e800
        cmpi.b  #8,(1,%a0)                      | 101d90  0c28 0008 0001
        beq.s   .Ldisp_found                        | 101d96  6730
        cmpi.b  #0xa,(1,%a0)                    | 101d98  0c28 000a 0001
        beq.s   .Ldisp_found                        | 101d9e  6728
        lea     (0x5d800).l,%a0                 | 101da0  41f9 0005 d800
        cmpi.b  #0xb,(1,%a0)                    | 101da6  0c28 000b 0001
        beq.s   .Ldisp_csr                        | 101dac  670e
        cmpi.b  #9,(1,%a0)                      | 101dae  0c28 0009 0001
        bne.s   .Ldisp_done                        | 101db4  662a
        move.w  #0x100,(cold_map_disp_frm-COLD:w,%a5)              | 101db6  3b7c 0100 0692
.Ldisp_csr:
        move.w  #0x176,(cold_map_disp_csr-COLD+2:w,%a5)              | 101dbc  3b7c 0176 068a
        move.w  #0x3e80,(cold_map_disp_frm-COLD+2:w,%a5)             | 101dc2  3b7c 3e80 0694
.Ldisp_found:
        move.w  (cold_map_disp_csr,%pc),(COLD_REMAP_CSR_CNT-COLD:w,%a5)      | 101dc8  3b7a 04be 06e6
        move.w  (cold_map_disp_csr+2,%pc),(COLD_REMAP_CSR_PPN-COLD+2:w,%a5)      | 101dce  3b7a 04ba 06e0
        move.w  (cold_map_disp_frm,%pc),(COLD_REMAP_FRM_CNT-COLD:w,%a5)      | 101dd4  3b7a 04bc 06e8
        move.w  (cold_map_disp_frm+2,%pc),(COLD_REMAP_FRM_PPN-COLD+2:w,%a5)      | 101dda  3b7a 04b8 06e4
.Ldisp_done:
        move.l  #0x100c00,(0x1003dc).l          | 101de0  23fc 0010 0c00 0010 03dc
        lea     (0x101800).l,%a2                | 101dea  45f9 0010 1800
        movec   %a2,%vbr                        | 101df0  4e7b a801
        move.l  (8,%a2),-(%sp)                  | 101df4  2f2a 0008
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)                 | 101df8  2b4f 06ce
        move.l  #OS_PAGE_END,%d4                | 101dfc  283c 03cf 6400
        .short  0xd8bc, 0x0000, 0x03ff          | 101e02  d8bc 0000 03ff  add.l #0x3ff,%d4 (<ea>=#imm form)
        .short  0xc87c, 0xfc00                  | 101e08  c87c fc00  and.w #-0x400,%d4 (<ea>=#imm form)
        .short  0x98bc; .long   OS_PROC   | 101e0c  98bc 03c0 0c00  sub.l #OS_PROC,%d4 (<ea>=#imm form)
        .short  0xb8bc, 0x0005, 0x4c00          | 101e12  b8bc 0005 4c00  cmp.l #0x54c00,%d4 (<ea>=#imm form)
        bhi.w   .Lkernel_hi                        | 101e18  6200 000e
        lsr.l   #5,%d4                          | 101e1c  ea8c
        lsr.l   #5,%d4                          | 101e1e  ea8c
        move.w  %d4,(cold_map_kernel_lo-COLD:w,%a5)                 | 101e20  3b44 0638
        bra.w   .Lmmap                        | 101e24  6000 0016
.Lkernel_hi:
        .short  0x98bc, 0x0005, 0x4c00          | 101e28  98bc 0005 4c00  sub.l #0x54c00,%d4 (<ea>=#imm form)
        lsr.l   #5,%d4                          | 101e2e  ea8c
        lsr.l   #5,%d4                          | 101e30  ea8c
        swap    %d4                             | 101e32  4844
        move.w  (MOVE_TO_PPN+2,%pc),%d4              | 101e34  383a fdec
        move.l  %d4,(cold_map_kernel_hi-COLD:w,%a5)                 | 101e38  2b44 0642
.Lmmap:
        move.l  (MOVE_TO_PPN,%pc),%d4           | 101e3c  283a fde2
        lsl.l   #5,%d4                          | 101e40  eb8c
        lsl.l   #5,%d4                          | 101e42  eb8c
        .short  0x98bc; .long   OS_PROC   | 101e44  98bc 03c0 0c00  sub.l #OS_PROC,%d4 (<ea>=#imm form)
        .short  0x98bc, 0x0005, 0x4c00          | 101e4a  98bc 0005 4c00  sub.l #0x54c00,%d4 (<ea>=#imm form)
        .short  0xd8bc; .long   MMAP            | 101e50  d8bc 03cc c800  add.l #MMAP,%d4 (<ea>=#imm form)
        movea.l %d4,%a4                         | 101e56  2844
        move.l  %a4,(cold_mmap_phys-COLD:w,%a5)                 | 101e58  2b4c 06d2
        lea     (.Lsize_bus_error,%pc),%a0              | 101e5c  41fa 0058
        move.l  %a0,(8,%a2)                     | 101e60  2548 0008
        move.w  #0x1fff,%d0                     | 101e64  303c 1fff
.Lclear_mmap:
        clr.l   (%a4)+                          | 101e68  429c
        clr.l   (%a4)+                          | 101e6a  429c
        clr.l   (%a4)+                          | 101e6c  429c
        clr.l   (%a4)+                          | 101e6e  429c
        dbf     %d0,.Lclear_mmap                    | 101e70  51c8 fff6
        movea.l #0x100000,%a0                   | 101e74  207c 0010 0000
        movea.l (cold_mmap_phys,%pc),%a4              | 101e7a  287a 0456
        adda.l  #0,%a4                          | 101e7e  d9fc 0000 0000
.Lsize_next:
        lea     (0x400,%a0),%a1                 | 101e84  43e8 0400
        cmpa.l  #0x900000,%a0                   | 101e88  b1fc 0090 0000
        beq.s   .Lsize_done                        | 101e8e  6746
        cmpa.l  #0x101800,%a0                   | 101e90  b1fc 0010 1800
        beq.s   .Lsize_skip                        | 101e96  6726
        cmpa.l  #0x900000,%a0                   | 101e98  b1fc 0090 0000
        bge.s   .Lsize_skip                        | 101e9e  6c1e
.Lsize_touch:
        move.l  (%a0),%d4                       | 101ea0  2810
        move.l  %d4,(%a0)+                      | 101ea2  20c4
        cmpa.l  %a0,%a1                         | 101ea4  b3c8
        bne.s   .Lsize_touch                        | 101ea6  66f8
        move.l  #0x40000000,(%a4)               | 101ea8  28bc 4000 0000
        adda.l  #0x10,%a4                       | 101eae  d9fc 0000 0010
        bra.s   .Lsize_next                        | 101eb4  60ce
.Lsize_bus_error:
        movea.l (cold_saved_sp,%pc),%sp              | 101eb6  2e7a 0416
        bsr.s   .Lsize_hole                        | 101eba  610c
        bra.s   .Lsize_next                        | 101ebc  60c6
.Lsize_skip:
        adda.l  #0x10,%a4                       | 101ebe  d9fc 0000 0010
        movea.l %a1,%a0                         | 101ec4  2049
        bra.s   .Lsize_next                        | 101ec6  60bc
.Lsize_hole:
        adda.l  #0x1000,%a4                     | 101ec8  d9fc 0000 1000
        adda.l  #0x40000,%a0                    | 101ece  d1fc 0004 0000
        rts                                     | 101ed4  4e75
.Lsize_done:
        move.l  (%sp)+,(8,%a2)                  | 101ed6  255f 0008
        movea.l #0,%a2                          | 101eda  247c 0000 0000
        movec   %a2,%vbr                        | 101ee0  4e7b a801
        lea     (cold_map_table,%pc),%a0              | 101ee4  41fa 0320
        bsr.w   cold_map_pages                        | 101ee8  6100 0096
        move.w  (COLD_REMAP_CSR_CNT,%pc),(REMAP_CSR_CNT).l | 101eec  33fa 03f8 03c2 00b6
        move.l  (COLD_REMAP_CSR_PPN,%pc),(REMAP_CSR_PPN).l | 101ef4  23fa 03e8 03c2 00ae
        move.w  (COLD_REMAP_FRM_CNT,%pc),(REMAP_FRM_CNT).l | 101efc  33fa 03ea 03c2 00b8
        move.l  (COLD_REMAP_FRM_PPN,%pc),(REMAP_FRM_PPN).l | 101f04  23fa 03dc 03c2 00b2
        movea.l #MMU,%a0                        | 101f0c  207c 03ff b400
        clr.w   (%a0)                           | 101f12  4250
        move.w  #-0xff,(0x100,%a0)              | 101f14  317c ff01 0100
        move.w  #-0xff,(MMU_$PID_PRIV).l        | 101f1a  33fc ff01 03c2 56a4
        movea.l #MMU_$HAVE_PMMU,%a0             | 101f22  207c 03c2 579a
        .short  0x10bc, 0x00ff                  | 101f28  10bc 00ff  move.b #-1,(%a0)
        btst    #5,(cold_boot_params+7,%pc)               | 101f2c  083a 0005 037d
        bne.s   .Lfpu_probe                        | 101f32  660c
        clr.b   (%a0)                           | 101f34  4210
        moveq   #3,%d1                          | 101f36  7203
        movec   %d1,%sfc                        | 101f38  4e7b 1000
        movec   %d1,%dfc                        | 101f3c  4e7b 1001
.Lfpu_probe:
        move.l  %sp,(cold_saved_sp-COLD:w,%a5)                 | 101f40  2b4f 06ce
        lea     (.Lno_fpu,%pc),%a1              | 101f44  43fa 0016
        move.l  %a1,(FLINE_TRAP_VEC).l          | 101f48  23c9 0000 002c
        fmove.l #0,%fpcr                        | 101f4e  f23c 9000 0000 0000
        st      (M68881_EXISTS).l               | 101f56  50f9 03c9 a2fc
.Lno_fpu:
        movea.l (cold_saved_sp,%pc),%sp              | 101f5c  2e7a 0370
        movea.l #P1_STACK_BASE,%sp            | 101f60  2e7c 03cc a000
        pea     (cold_diskless_info,%pc)                  | 101f66  487a 034a
        pea     (cold_boot_params,%pc)                  | 101f6a  487a 033a
        movea.l #OS_$INIT,%a0                   | 101f6e  207c 03c3 7034
        btst    #0xf,(cold_boot_params+6,%pc)             | 101f74  083a 000f 0334
        beq.s   .Lcall_init                        | 101f7a  6702
        trap    #0xf                            | 101f7c  4e4f
.Lcall_init:
        jsr     (%a0)                           | 101f7e  4e90
cold_map_pages:
        move.l  (MOVE_TO_PPN,%pc),%d0           | 101f80  203a fc9e
        lsl.l   #5,%d0                          | 101f84  eb88
        lsl.l   #5,%d0                          | 101f86  eb88
        .short  0x90bc; .long   OS_PROC   | 101f88  90bc 03c0 0c00  sub.l #OS_PROC,%d0 (<ea>=#imm form)
        .short  0x90bc, 0x0005, 0x4c00          | 101f8e  90bc 0005 4c00  sub.l #0x54c00,%d0 (<ea>=#imm form)
        move.l  %d0,%d1                         | 101f94  2200
        .short  0xd2bc; .long   SMAPS           | 101f96  d2bc 03cf 3000  add.l #SMAPS,%d1 (<ea>=#imm form)
        move.l  %d1,(cold_smaps_phys-COLD:w,%a5)                 | 101f9c  2b41 06d6
        move.l  %d0,%d1                         | 101fa0  2200
        .short  0xd2bc; .long   OS_PMAPS        | 101fa2  d2bc 03ce c800  add.l #OS_PMAPS,%d1 (<ea>=#imm form)
        move.l  %d1,(cold_os_pmaps_phys-COLD:w,%a5)                 | 101fa8  2b41 06da
        movea.l #0x101400,%a2                   | 101fac  247c 0010 1400
        move.l  #0xff,%d4                       | 101fb2  283c 0000 00ff
.Lclear_rars:
        clr.l   (%a2)+                          | 101fb8  429a
        dbf     %d4,.Lclear_rars                    | 101fba  51cc fffc
        movea.l (cold_os_pmaps_phys,%pc),%a2              | 101fbe  247a 031a
        move.l  #OS_PAGE_END+0x3,%d4            | 101fc2  283c 03cf 6403
        .short  0x98bc; .long   OS_PMAPS        | 101fc8  98bc 03ce c800  sub.l #OS_PMAPS,%d4 (<ea>=#imm form)
        lsr.l   #2,%d4                          | 101fce  e48c
        subq.l  #1,%d4                          | 101fd0  5384
.Lclear_pmaps:
        clr.l   (%a2)+                          | 101fd2  429a
        dbf     %d4,.Lclear_pmaps                    | 101fd4  51cc fffc
        clr.w   %d4                             | 101fd8  4244
        subq.l  #1,%d4                          | 101fda  5384
        bcc.s   .Lclear_pmaps                        | 101fdc  64f4
        movea.l (cold_mmap_phys,%pc),%a4              | 101fde  287a 02f2
        clr.l   %d1                             | 101fe2  4281
        clr.l   %d3                             | 101fe4  4283
.Lmap_entry:
        move.w  (%a0)+,%d0                      | 101fe6  3018
        beq.w   .Lmap_roots                        | 101fe8  6700 0116
        move.w  (%a0)+,%d1                      | 101fec  3218
        move.l  (%a0)+,%d2                      | 101fee  2418
        move.l  %d2,%d5                         | 101ff0  2a02
        lsr.l   #8,%d5                          | 101ff2  e08d
        lsr.l   #4,%d5                          | 101ff4  e88d
        btst    #5,(cold_boot_params+7,%pc)               | 101ff6  083a 0005 02b3
        bne.s   .Lmap_pmmu_seg                        | 101ffc  6614
        .short  0xcabc, 0x0000, 0x07f8          | 101ffe  cabc 0000 07f8  and.l #0x7f8,%d5 (<ea>=#imm form)
        btst    #0x19,%d2                       | 102004  0802 0019
        beq.s   .Lmap_private                        | 102008  671c
        .short  0x9abc, 0x0000, 0x0200          | 10200a  9abc 0000 0200  sub.l #0x200,%d5 (<ea>=#imm form)
        bra.s   .Lmap_global                        | 102010  6050
.Lmap_pmmu_seg:
        .short  0xcabc, 0x0000, 0x0ff8          | 102012  cabc 0000 0ff8  and.l #0xff8,%d5 (<ea>=#imm form)
        btst    #0x1b,%d2                       | 102018  0802 001b
        beq.s   .Lmap_private                        | 10201c  6708
        .short  0x9abc, 0x0000, 0x0000          | 10201e  9abc 0000 0000  sub.l #0,%d5 (<ea>=#imm form)
        bra.s   .Lmap_global                        | 102024  603c
.Lmap_private:
        movea.l (cold_smaps_phys,%pc),%a2              | 102026  247a 02ae
        movea.l (cold_os_pmaps_phys,%pc),%a3              | 10202a  267a 02ae
        adda.l  #0xc00,%a2                      | 10202e  d5fc 0000 0c00
        adda.l  #0x6000,%a3                     | 102034  d7fc 0000 6000
        btst    #5,(cold_boot_params+7,%pc)               | 10203a  083a 0005 026f
        beq.s   .Lmap_private_seg                        | 102040  670c
        adda.l  #0xc00,%a2                      | 102042  d5fc 0000 0c00
        adda.l  #0xa000,%a3                     | 102048  d7fc 0000 a000
.Lmap_private_seg:
        tst.w   %d5                             | 10204e  4a45
        beq.s   .Lmap_prot                        | 102050  6732
        adda.w  #0x80,%a3                       | 102052  d6fc 0080
        .short  0xcabc, 0x0000, 0x01f8          | 102056  cabc 0000 01f8  and.l #0x1f8,%d5 (<ea>=#imm form)
        adda.l  %d5,%a2                         | 10205c  d5c5
        bra.w   .Lmap_prot                        | 10205e  6000 0024
.Lmap_global:
        movea.l (cold_smaps_phys,%pc),%a2              | 102062  247a 0272
        movea.l (cold_os_pmaps_phys,%pc),%a3              | 102066  267a 0272
        adda.l  #0x600,%a2                      | 10206a  d5fc 0000 0600
        btst    #5,(cold_boot_params+7,%pc)               | 102070  083a 0005 0239
        beq.s   .Lmap_global_seg                        | 102076  6706
        adda.l  #0x200,%a2                      | 102078  d5fc 0000 0200
.Lmap_global_seg:
        adda.l  %d5,%a2                         | 10207e  d5c5
        lsl.l   #4,%d5                          | 102080  e98d
        adda.l  %d5,%a3                         | 102082  d7c5
.Lmap_prot:
        move.w  (%a0)+,%d4                      | 102084  3818
        move.l  %d4,%d7                         | 102086  2e04
        .short  0xcebc, 0x0000, 0x000f          | 102088  cebc 0000 000f  and.l #0xf,%d7 (<ea>=#imm form)
        add.l   %a3,%d7                         | 10208e  de8b
        move.l  #0x1f0302,%d6                   | 102090  2c3c 001f 0302
        btst    #2,%d4                          | 102096  0804 0002
        bne.s   .Lmap_first                        | 10209a  6604
        bset    #2,%d6                          | 10209c  08c6 0002
.Lmap_first:
        move.l  %d2,%d3                         | 1020a0  2602
        move.w  #0x7c00,%d3                     | 1020a2  363c 7c00
        and.w   %d2,%d3                         | 1020a6  c642
        bra.w   .Lmap_segdesc                        | 1020a8  6000 0018
.Lmap_page:
        move.w  #0x7c00,%d3                     | 1020ac  363c 7c00
        and.w   %d2,%d3                         | 1020b0  c642
        bne.s   .Lmap_pagedesc                        | 1020b2  6614
        addq.l  #8,%a2                          | 1020b4  508a
        adda.l  #0x80,%a3                       | 1020b6  d7fc 0000 0080
        .short  0xdebc, 0x0000, 0x0080          | 1020bc  debc 0000 0080  add.l #0x80,%d7 (<ea>=#imm form)
.Lmap_segdesc:
        move.l  %d6,(%a2)                       | 1020c2  2486
        move.l  %d7,(4,%a2)                     | 1020c4  2547 0004
.Lmap_pagedesc:
        lsr.w   #8,%d3                          | 1020c8  e04b
        move.l  %d1,%d4                         | 1020ca  2801
        lsl.l   #8,%d4                          | 1020cc  e18c
        lsl.l   #2,%d4                          | 1020ce  e58c
        bset    #0,%d4                          | 1020d0  08c4 0000
        move.l  %d4,(0,%a3,%d3.w)               | 1020d4  2784 3000
        .short  0xc6bc, 0xc000, 0x0000          | 1020d8  c6bc c000 0000  and.l #-0x40000000,%d3 (<ea>=#imm form)
        clr.l   %d4                             | 1020de  4284
        move.w  %d1,%d4                         | 1020e0  3801
        .short  0x987c, 0x0400                  | 1020e2  987c 0400  sub.w #0x400,%d4 (<ea>=#imm form)
        bcs.s   .Lmap_mmap_done                        | 1020e6  6508
        mulu.w  #0x10,%d4                       | 1020e8  c8fc 0010
        move.l  %d3,(0,%a4,%d4.l)               | 1020ec  2983 4800
.Lmap_mmap_done:
        addq.w  #1,%d1                          | 1020f0  5241
        .short  0xd4bc, 0x0000, 0x0400          | 1020f2  d4bc 0000 0400  add.l #0x400,%d2 (<ea>=#imm form)
        subq.w  #1,%d0                          | 1020f8  5340
        bne.s   .Lmap_page                        | 1020fa  66b0
        bra.w   .Lmap_entry                        | 1020fc  6000 fee8
.Lmap_roots:
        movea.l #0x101464,%a1                   | 102100  227c 0010 1464
        move.l  (cold_smaps_phys,%pc),%d4              | 102106  283a 01ce
        .short  0x887c, 0x0003                  | 10210a  887c 0003  or.w #3,%d4 (<ea>=#imm form)
        move.w  #2,%d1                          | 10210e  323c 0002
        btst    #5,(cold_boot_params+7,%pc)               | 102112  083a 0005 0197
        beq.s   .Lroot_global_a                        | 102118  670a
        adda.l  #0x168,%a1                      | 10211a  d3fc 0000 0168
        move.w  #3,%d1                          | 102120  323c 0003
.Lroot_global_a:
        move.l  %d4,(%a1)+                      | 102124  22c4
        .short  0xd8bc, 0x0000, 0x0200          | 102126  d8bc 0000 0200  add.l #0x200,%d4 (<ea>=#imm form)
        dbf     %d1,.Lroot_global_a                    | 10212c  51c9 fff6
        movea.l #0x101474,%a1                   | 102130  227c 0010 1474
        move.w  #2,%d1                          | 102136  323c 0002
        btst    #5,(cold_boot_params+7,%pc)               | 10213a  083a 0005 016f
        beq.s   .Lroot_global_b                        | 102140  670a
        adda.l  #0x16c,%a1                      | 102142  d3fc 0000 016c
        move.w  #7,%d1                          | 102148  323c 0007
.Lroot_global_b:
        move.l  %d4,(%a1)+                      | 10214c  22c4
        .short  0xd8bc, 0x0000, 0x0200          | 10214e  d8bc 0000 0200  add.l #0x200,%d4 (<ea>=#imm form)
        dbf     %d1,.Lroot_global_b                    | 102154  51c9 fff6
        movea.l #0x101400,%a1                   | 102158  227c 0010 1400
        move.l  %d4,(%a1)                       | 10215e  2284
        btst    #5,(cold_boot_params+7,%pc)               | 102160  083a 0005 0149
        bne.s   .Lpmmu_on                        | 102166  661c
        moveq   #3,%d1                          | 102168  7203
        movec   %d1,%dfc                        | 10216a  4e7b 1001
        moves.l %d0,(0x8000000).l               | 10216e  0eb9 0800 0800 0000
        move.l  #0xc02028,%d2                   | 102176  243c 00c0 2028
        moves.l %d2,(0x0).w                     | 10217c  0eb8 2800 0000
        bra.s   .Lprom_table                        | 102182  601c
.Lpmmu_on:
        lea     (cold_crp,%pc),%a0              | 102184  41fa 0118
        pmove   (%a0),%crp                      | 102188  f010 4c00
        pflusha                                 | 10218c  f000 2400
        move.l  #-0x7f5b89b0,(cold_tc-COLD:w,%a5)        | 102190  2b7c 80a4 7650 06ea
        lea     (cold_tc,%pc),%a0              | 102198  41fa 0150
        pmove   (%a0),%tc                       | 10219c  f010 4000
.Lprom_table:
        move.l  #OS_BEGIN,(0x200).w        | 1021a0  21fc 03c0 0000 0200
        move.l  #OS_BEGIN+0x180,(0x204).w | 1021a8  21fc 03c0 0180 0204
        move.l  #DISP1,(0x208).w            | 1021b0  21fc 03ff 9400 0208
        move.l  #DISP1_MEM,(0x20c).w            | 1021b8  21fc 03fa 0000 020c
        move.l  #SIO,(0x210).w                  | 1021c0  21fc 03ff b000 0210
        move.l  #MMU,(0x214).w                  | 1021c8  21fc 03ff b400 0214
        move.l  #MMU+0x100,(0x218).w            | 1021d0  21fc 03ff b500 0218
        .short  0x13fc, 0x00ff; .long   TRAP_PAGE | 1021d8  13fc 00ff 0000 0000  move.b #-1,(TRAP_PAGE).l
        move.l  #0x101400,(DUMP_$RARS_PHADDR).l | 1021e0  23fc 0010 1400 03c0 0be8
        move.l  (cold_smaps_phys,%pc),(DUMP_$SMAP_PHADDR).l | 1021ea  23fa 00ea 03c0 0a4e
        move.l  #0x101400,(MMU_$RARS_PHADDR).l  | 1021f2  23fc 0010 1400 03c2 56b2
        move.l  (cold_os_pmaps_phys,%pc),(MMU_$OS_PMAPS_PHADDR).l | 1021fc  23fa 00dc 03c2 56ae
        rts                                     | 102204  4e75

/*
 * The MMU map table, 0x102206: entries of (count.w, PPN.w, VA.l with the
 * flags in bits 31..29, protection.w), a zero count ends it.  The VA
 * fields of the kernel's pages and of the I/O pages are RELOC cells.
 * COLD fills the kernel's counts (cold_map_kernel_lo, _hi) and the
 * display's entries; with the MC68851 the fixups move the first entry.
 */
cold_map_table:
        .short  0x0002, 0x0400          | 102206  OS_BEGIN: the crash record page
        .long   MAP_WIRED + 0x03C00000  | 10220a  OS_BEGIN as a literal: not a RELOC
                                        |   cell, COLD moves it with the fixups
        .short  0x0017
        .short  0x0002, 0x0403          | 102210  the DUMP page
        .long   MAP_WIRED + DUMP
        .short  0x0017
        .short  0x0001, 0x0406          | 10221a  the trap page
        .long   MAP_WIRED + TRAP_PAGE
        .short  0x0017
        .short  0x001F, 0x0001          | 102224  the low pages, at their own VA
        .long   0x00000400
        .short  0x0017
        .short  0x0003, 0x0407          | 10222e  COLD's pages
        .long   MAP_COLD + COLD_LOW
        .short  0x0017
cold_map_kernel_lo:
        .short  0x0153, 0x040C          | 102238  the kernel's low piece (count: COLD)
        .long   MAP_WIRED + OS_PROC
        .short  0x0017
cold_map_kernel_hi:
        .short  0x0000, 0x0000          | 102242  the high piece (count, PPN: COLD)
        .long   MAP_WIRED + OS_PROC + KERNEL_LO_BYTES
        .short  0x0017
        .short  0x0001, 0x0405          | 10224c  RARS
        .long   MAP_WIRED + RARS
        .short  0x0016
        .short  0x0001, 0x0020          | 102256
        .long   MMU
        .short  0x0016
        .short  0x0001, 0x0021          | 102260
        .long   SIO
        .short  0x0016
        .short  0x0001, 0x0022          | 10226a
        .long   TIMR
        .short  0x0016
        .short  0x0001, 0x0024          | 102274
        .long   DMA
        .short  0x0016
        .short  0x0001, 0x0025          | 10227e  the AT bus's interrupt controllers
        .long   PIC1
        .short  0x0016
cold_map_disp_csr:
        .short  0x0002, 0x017A          | 102288  the display's control pages (COLD)
        .long   DISP1
        .short  0x0016
cold_map_disp_frm:
        .short  0x0080, 0x0280          | 102292  the display's frame buffer (COLD)
        .long   DISP1_MEM
        .short  0x0016
        .short  0x0000                  | 10229c  the end

cold_crp:                               | 10229e  the CPU root pointer for `pmove':
        .long   0x007F0002              |   limit 0x7F, a valid 8-byte table,
        .long   0x00101400              |   the root tables (physical)

/* The cells COLD writes (zero in the image). */
cold_boot_params:                       | 1022a6  D1, D2 from the PROM and a longword
        .space  12
cold_diskless_info:                     | 1022b2  seven longwords for a diskless boot
        .space  28
cold_saved_sp:                          | 1022ce
        .long   0
cold_mmap_phys:                         | 1022d2  the MMAP's physical address
        .long   0
cold_smaps_phys:                        | 1022d6  SMAPS's
        .long   0
cold_os_pmaps_phys:                     | 1022da  OS_PMAPS's
        .long   0
COLD_REMAP_CSR_PPN:                     | 1022de
        .long   0
COLD_REMAP_FRM_PPN:                     | 1022e2
        .long   0
COLD_REMAP_CSR_CNT:                     | 1022e6
        .short  0
COLD_REMAP_FRM_CNT:                     | 1022e8
        .short  0
cold_tc:                                | 1022ea  the MC68851's translation control
        .long   0
        .space  0x50E                   | 1022ee  COLD's stack
cold_stack_top:                         | 1027fc
        .long   0                       |   the four bytes before DUMP (file 0xBFC)
