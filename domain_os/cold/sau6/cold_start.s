/*
 * cold/sau6/cold_start.s - the RFC header, the info block and COLD_START
 * (SAU6)
 *
 * The SAU6's COLD, transcribed from the SAU6 image file (file 0..0x7FC,
 * loaded at 0x101EC00; sr10.2-install/.../sau6/domain_os), with the
 * SAU4's conventions (cold/sau4/cold_start.s: one section, A5 = COLD with
 * the cells at fixed displacements, the Apollo assembler's <ea>=#imm
 * forms as `.short', the image's branch sizes).  The SAU6 map:
 *
 *   D22 101EC00  COLD               loaded at 101EC00, size = 7FC
 *   D   101EC00  COLD_START         size = 7FC
 *       101EC00  COLD
 *       101EC20  MOVE_TO_PPN
 *
 * The DN5xxT's MMU translates through tables in memory (`region_mmu',
 * base/config.ins.pas; mmu/sau6/mmu_asm.s): COLD builds them and turns
 * translation on through the MMU's registers, which it reaches at their
 * physical page 0x8000 (MMU, PPN 0x20; the VME adapter's VME_CTL is
 * PPN 0x2F, physical 0xBC00).  In order:
 *   - A5 = COLD, VBR = 0; the boot record's first two longwords are
 *     sysboot's d1 and d2; with boot flag bit 7, or boot device 2 or 6,
 *     the diskless record is copied from the address it passed, and with
 *     boot flag bit 8 its first longword;
 *   - with a bus error handler of its own, COLD reads the ring
 *     controller's page (RING2, physical 0x9800): when that faults, the
 *     VME adapter is acknowledged (0x440 into its word + 8) and, unless
 *     bit 4 of MMU + 5 is set, "Please request ECO # 14202" is printed
 *     for ever through the PROM; with the bit, four bytes read through
 *     the MMU's index and data words (+ 0xA = 0x200..0x206, + 0xC) go to
 *     the boot record + 8;
 *   - the CPU check: `lsr.b' by 31 must leave CCR = Z alone, else a jump
 *     to the PROM's 0x414; the CPU's cache is enabled (CACR = 9);
 *   - the DUMP page is copied from where it was loaded (DUMP_LOW) to
 *     DUMP_PHYS, a new trap page is built at TRAP_PAGE_PHYS from the
 *     PROM's vectors, and the display memories' PPNs are set in the map
 *     table (boot flag bit 14 the other form: frame buffers at PPNs
 *     0x1100 and 0x1180 with their VAs swapped, the graphics processor's
 *     block at 0x1240); DUMP's physical address goes to physical
 *     0x10003DC;
 *   - the PBU controller's page (PBU_CTL, physical 0xA400) is probed and
 *     the answer kept (cold_pbu_present);
 *   - the kernel's size (OS_PAGE_END rounded up to a page, less
 *     OS_PROC) sets the low piece's page count, or, when it does not fit
 *     below the split, the high piece's count and PPN (MOVE_TO_PPN);
 *   - MMAP is cleared at its physical address, and every longword of
 *     memory from 16 MB to 48 MB but the trap page is read and written
 *     back (the memory's check bits), its MMAP entry marked present; a
 *     bus error moves on 256 KB (and 256 MMAP entries); then the VME
 *     adapter's word + 8 gets bit 3, and a present PBU controller the
 *     word 0x10 in its page, or 0x30 unless the page at 16 MB +
 *     0x2A0000 was found;
 *   - cold_map_pages (the map table); the VME adapter's words + 0xA and
 *     + 6 are written 0x8000, and the MMU's longword at + 0x14 gets bits
 *     0 and 8 and loses bit 3;
 *   - the floating-point hardware: with the FPX (MMU + 0x1B bits 7 and
 *     6) its revision goes to MMU_$SYSTEM_REV + 2 and FPX_EXISTS is set;
 *     else the FPU is enabled (MMU + 9 bit 7 clear) and an `fmove' to
 *     FPCR, with the line-F vector pointed past it, sets M68881_EXISTS;
 *   - SP = INT_STACK_GUARD; OS_$INIT(&cold_boot_params,
 *     &cold_diskless_info), after a trap to the debugger if boot flag
 *     bit 15 is set.
 * cold_map_pages clears the 4 KB at physical 0x10000 when the PBU
 * controller answered, clears COLD's RARS pages (RARS_PHYS, 0x1D000
 * bytes) and the OS page maps (OS_PMAPS to OS_PAGE_END) at their physical
 * addresses, enters every page of the map table in its segment's page map
 * and its segment map entry (SMAPS + 0x400 for the VAs with bit 30 set,
 * else the low segment's at SMAPS + 0x4400), records the page's MMAP
 * entry for PPNs from 0x4000, sets OS_PMAP0's first entry's bit 27, fills
 * RARS entries 238 and 240..255 with the segment maps' pages (valid and
 * global), makes ASID 0 current (MMU + 7) with its RARS at RARS_PHYS
 * (MMU + 0x12 = 0x4006), turns translation on (MMU + 3 bit 0), marks
 * byte 0 of the trap page, and leaves the tables' physical addresses in
 * DUMP_$RARS_PHADDR, DUMP_$SMAP_PHADDR, MMU_$RARS_PHADDR and
 * MMU_$OS_PMAPS_PHADDR.
 *
 * The image has no fixup table: physical addresses are literals (the
 * equates below), and kernel addresses are symbol references.
 *
 * Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau6 check-asm'):
 * encodings identical to the image; address operands resolve to our
 * objects.  Addresses in the comments are the SAU6 image's.
 */

        .section ".text.COLD","ax",@progbits
        .balign 4

        .globl  COLD
        .globl  MOVE_TO_PPN
        .globl  cold_start_entry
        .globl  cold_map_pages
        .globl  cold_map_table
        .globl  cold_boot_params
        .globl  cold_diskless_info

/* ---- physical layout of the loaded file (not relocated) ------------------ */
        .equ    COLD_LOW,       0x0101EC00  /* the RFC load address: file byte 0, COLD */
        .equ    DUMP_LOW,       0x0101F400  /* file 0x800: the DUMP page as loaded */
        .equ    DUMP_PHYS,      0x01000C00  /* PPN 0x4003: where COLD copies the DUMP page */
        .equ    RARS_PHYS,      0x01001800  /* PPN 0x4006: COLD's RARS (ASID 0) */
        .equ    TRAP_PAGE_PHYS, 0x0101E800  /* PPN 0x407A: the new trap page (VBR) */
        .equ    KERNEL_LO_BYTES, 0x00038000 /* (0x415F << 10) - 0x101FC00: kernel bytes below the split */
        .set    KERNEL_HI_VA,   OS_PROC + KERNEL_LO_BYTES /* map 0x78039000: the high piece's first VA */

/*
 * The RFC header, 0x101EC00 (12 bytes): load address, start address,
 * machine type WORD (SAU 6), zero word.  Physical addresses, literals.
 */
COLD:
        .long   COLD_LOW                /* 101ec00  load: file byte 0 lands here */
        .long   COLD_LOW + 0x24         /* 101ec04  start: cold_start_entry */
        .short  0x0006                  /* 101ec08  machine type: SAU 6 */
        .short  0x0000                  /* 101ec0a  0 */

/*
 * The info block, 0x101EC0C (24 bytes).  COLD reads only MOVE_TO_PPN;
 * sysboot reads the magic, the split PPN and MOVE_TO_PPN.
 */
rfc_info_block:
        .long   0x00001000              /* 101ec0c  file offset of the first kernel page (header + COLD + DUMP) */
        .long   OS_DATA                 /* 101ec10  OS_DATA */
        .long   OS_PROC                 /* 101ec14  the first kernel page */
        .long   0xFEED2B03              /* 101ec18  magic: word FEED, byte 2B, format version 0 */
        .long   0x0000415F              /* 101ec1c  split PPN (SPLIT_LOW >> 10) */
MOVE_TO_PPN:
        .long   0x00004200              /* 101ec20  where the pages past the split go (0x1080000) */

/*
 * cold_start_entry, 0x101EC24: entered from sysboot with d0..d2 and the
 * diskless record's address on the stack.
 */
cold_start_entry:
        movea.l #COLD,%a5                       | sau6 101ec24  2a7c 0101 ec00
        movea.l #0,%a0                          | sau6 101ec2a  207c 0000 0000
        movec   %a0,%vbr                        | sau6 101ec30  4e7b 8801
        movem.l (%sp)+,%d0-%d2                  | sau6 101ec34  4cdf 0007
        movea.l (%sp)+,%a1                      | sau6 101ec38  225f
        movem.l %d1-%d2,(0x730,%a5)             | sau6 101ec3a  48ed 0006 0730
        lea     (cold_stack_top:w,%pc),%sp      | sau6 101ec40  4ffa 07ba
        btst    #7,(cold_boot_params+7:w,%pc)   | sau6 101ec44  083a 0007 06ef
        bne.s   .L0101ec64                      | sau6 101ec4a  6618
        btst    #8,(cold_boot_params+6:w,%pc)   | sau6 101ec4c  083a 0008 06e6
        bne.s   .L0101ec70                      | sau6 101ec52  661c
        cmpi.w  #2,(0x730,%a5)                  | sau6 101ec54  0c6d 0002 0730
        beq.s   .L0101ec64                      | sau6 101ec5a  6708
        cmpi.w  #6,(0x730,%a5)                  | sau6 101ec5c  0c6d 0006 0730
        bne.s   .L0101ec74                      | sau6 101ec62  6610
.L0101ec64:
        movem.l (%a1)+,%d0-%d6                  | sau6 101ec64  4cd9 007f
        movem.l %d0-%d6,(0x73c,%a5)             | sau6 101ec68  48ed 007f 073c
        bra.s   .L0101ec74                      | sau6 101ec6e  6004
.L0101ec70:
        move.l  (%a1),(0x73c,%a5)               | sau6 101ec70  2b51 073c
.L0101ec74:
        lea     (TRAP_PAGE_PHYS).l,%a2          | sau6 101ec74  45f9 0101 e800
        movec   %a2,%vbr                        | sau6 101ec7a  4e7b a801
        move.l  %sp,(0x758,%a5)                 | sau6 101ec7e  2b4f 0758
        lea     (.L0101ec96:w,%pc),%a0          | sau6 101ec82  41fa 0012
        move.l  %a0,(0x8,%a2)                   | sau6 101ec86  2548 0008
        lea     (0x9800).l,%a0                  | sau6 101ec8a  41f9 0000 9800
        tst.b   (%a0)                           | sau6 101ec90  4a10
        bra.w   .L0101ed4a                      | sau6 101ec92  6000 00b6
.L0101ec96:
        movea.l #0xbc00,%a3                     | sau6 101ec96  267c 0000 bc00
        ori.w   #0x440,(0x8,%a3)                | sau6 101ec9c  006b 0440 0008
        btst    #4,(0x8005).l                   | sau6 101eca2  0839 0004 0000 8005
        bne.w   .L0101ed1e                      | sau6 101ecaa  6600 0072
        movea.l (cold_saved_sp:w,%pc),%sp       | sau6 101ecae  2e7a 06a8
        movea.l #0,%a2                          | sau6 101ecb2  247c 0000 0000
        movec   %a2,%vbr                        | sau6 101ecb8  4e7b a801
.L0101ecbc:
        lea     (cold_eco_msg:w,%pc),%a3        | sau6 101ecbc  47fa 0026
.L0101ecc0:
        move.b  (%a3)+,%d1                      | sau6 101ecc0  121b
        move.l  %a3,-(%sp)                      | sau6 101ecc2  2f0b
        .short  0xb23c, 0x0025                  | sau6 101ecc4  b23c 0025  cmp.b   #0x25,%d1
        beq.s   .L0101ece0                      | sau6 101ecc8  6716
        movea.l (0x108).w,%a0                   | sau6 101ecca  2078 0108
        tst.w   (PROM_$MACHINE_ID).w            | sau6 101ecce  4a78 0100
        bne.s   .L0101ecda                      | sau6 101ecd2  6606
        movea.l #0x24,%a0                       | sau6 101ecd4  207c 0000 0024
.L0101ecda:
        jsr     (%a0)                           | sau6 101ecda  4e90
        movea.l (%sp)+,%a3                      | sau6 101ecdc  265f
        bra.s   .L0101ecc0                      | sau6 101ecde  60e0
.L0101ece0:
        trap    #0xf                            | sau6 101ece0  4e4f
        bra.s   .L0101ecbc                      | sau6 101ece2  60d8
cold_eco_msg:
        .byte   0x0d, 0x0a                      | sau6 101ece4  0d0a
        .ascii  "*** Please request ECO # 14202 for your CPU pcb. ***" | sau6 101ece6
        .byte   0x0d, 0x0a, 0x25, 0x00          | sau6 101ed1a  0d0a 2500
.L0101ed1e:
        movea.w #0x200,%a1                      | sau6 101ed1e  327c 0200
        move.w  #3,%d0                          | sau6 101ed22  303c 0003
.L0101ed26:
        move.w  %a1,(0x800a).l                  | sau6 101ed26  33c9 0000 800a
        move.w  (0x800c).l,%d1                  | sau6 101ed2c  3239 0000 800c
        lsr.w   #8,%d1                          | sau6 101ed32  e049
        lsl.l   #8,%d2                          | sau6 101ed34  e18a
        move.b  %d1,%d2                         | sau6 101ed36  1401
        addq.l  #2,%a1                          | sau6 101ed38  5489
        dbf     %d0,.L0101ed26                  | sau6 101ed3a  51c8 ffea
        move.w  #0,(0x800a).l                   | sau6 101ed3e  33fc 0000 0000 800a
        move.l  %d2,(0x738,%a5)                 | sau6 101ed46  2b42 0738
.L0101ed4a:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau6 101ed4a  2e7a 060c
        movea.l #0,%a2                          | sau6 101ed4e  247c 0000 0000
        movec   %a2,%vbr                        | sau6 101ed54  4e7b a801
        moveq   #0x1f,%d1                       | sau6 101ed58  721f
        lsr.b   %d1,%d0                         | sau6 101ed5a  e228
        move.w  %ccr,%d0                        | sau6 101ed5c  42c0
        .short  0xb07c, 0x0004                  | sau6 101ed5e  b07c 0004  cmp.w   #4,%d0
        beq.s   .L0101ed68                      | sau6 101ed62  6704
        jmp     (0x414).w                       | sau6 101ed64  4ef8 0414
.L0101ed68:
        movea.l #9,%a0                          | sau6 101ed68  207c 0000 0009
        movec   %a0,%cacr                       | sau6 101ed6e  4e7b 8002
        movea.l #DUMP_PHYS,%a0                  | sau6 101ed72  207c 0100 0c00
        move.l  #0x1ff,%d0                      | sau6 101ed78  203c 0000 01ff
        movea.l #DUMP_LOW,%a1                   | sau6 101ed7e  227c 0101 f400
.L0101ed84:
        move.l  (%a1)+,(%a0)+                   | sau6 101ed84  20d9
        dbf     %d0,.L0101ed84                  | sau6 101ed86  51c8 fffc
        lea     (TRAP_PAGE_PHYS).l,%a1          | sau6 101ed8a  43f9 0101 e800
        move.l  (%a1),(%a1)+                    | sau6 101ed90  22d1
        move.l  (%a1),(%a1)+                    | sau6 101ed92  22d1
        lea     (BUS_ERROR_VEC).w,%a0           | sau6 101ed94  41f8 0008
        move.w  #0xfd,%d0                       | sau6 101ed98  303c 00fd
.L0101ed9c:
        move.l  (%a0)+,(%a1)+                   | sau6 101ed9c  22d8
        dbf     %d0,.L0101ed9c                  | sau6 101ed9e  51c8 fffc
        btst    #0xe,(cold_boot_params+6:w,%pc) | sau6 101eda2  083a 000e 0590
        beq.s   .L0101edbe                      | sau6 101eda8  6714
        move.w  #0x1100,(0x6ea,%a5)             | sau6 101edaa  3b7c 1100 06ea
        move.w  #0x1180,(0x6f4,%a5)             | sau6 101edb0  3b7c 1180 06f4
        move.w  #0x1240,(0x6fe,%a5)             | sau6 101edb6  3b7c 1240 06fe
        bra.s   .L0101edd0                      | sau6 101edbc  6012
.L0101edbe:
        move.w  #0x80,(0x6ea,%a5)               | sau6 101edbe  3b7c 0080 06ea
        move.w  #0x100,(0x6f4,%a5)              | sau6 101edc4  3b7c 0100 06f4
        move.w  #0x180,(0x6fe,%a5)              | sau6 101edca  3b7c 0180 06fe
.L0101edd0:
        btst    #0xe,(cold_boot_params+6:w,%pc) | sau6 101edd0  083a 000e 0562
        beq.s   .L0101ede6                      | sau6 101edd6  670e
        move.l  (cold_map_disp1_mem+4:w,%pc),%d4 | sau6 101edd8  283a 0512
        move.l  (cold_map_disp2_mem+4:w,%pc),(0x6ec,%a5) | sau6 101eddc  2b7a 0518 06ec
        move.l  %d4,(0x6f6,%a5)                 | sau6 101ede2  2b44 06f6
.L0101ede6:
        move.l  #DUMP_PHYS,(0x10003dc).l        | sau6 101ede6  23fc 0100 0c00 0100 03dc
        lea     (TRAP_PAGE_PHYS).l,%a2          | sau6 101edf0  45f9 0101 e800
        movec   %a2,%vbr                        | sau6 101edf6  4e7b a801
        move.l  (0x8,%a2),-(%sp)                | sau6 101edfa  2f2a 0008
        move.l  %sp,(0x758,%a5)                 | sau6 101edfe  2b4f 0758
        lea     (.L0101ee1c:w,%pc),%a0          | sau6 101ee02  41fa 0018
        move.l  %a0,(0x8,%a2)                   | sau6 101ee06  2548 0008
        tst.w   (0xa400).l                      | sau6 101ee0a  4a79 0000 a400
        move.w  #0,(0xa400).l                   | sau6 101ee10  33fc 0000 0000 a400
        st      (0x768,%a5)                     | sau6 101ee18  50ed 0768
.L0101ee1c:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau6 101ee1c  2e7a 053a
        movea.l #0xbc00,%a3                     | sau6 101ee20  267c 0000 bc00
        ori.w   #0x440,(0x8,%a3)                | sau6 101ee26  006b 0440 0008
        move.l  #OS_PAGE_END,%d4                | sau6 101ee2c  283c 7825 0800
        .short  0xd8bc, 0x0000, 0x03ff          | sau6 101ee32  d8bc 0000 03ff  add.l   #0x3ff,%d4
        .short  0xc87c, 0xfc00                  | sau6 101ee38  c87c fc00  and.w   #-0x400,%d4
        .short  0x98bc; .long OS_PROC           | sau6 101ee3c  98bc 7800 1000  sub.l   #OS_PROC,%d4
        .short  0xb8bc; .long KERNEL_LO_BYTES   | sau6 101ee42  b8bc 0003 8000  cmp.l   #KERNEL_LO_BYTES,%d4
        bhi.w   .L0101ee58                      | sau6 101ee48  6200 000e
        lsr.l   #5,%d4                          | sau6 101ee4c  ea8c
        lsr.l   #5,%d4                          | sau6 101ee4e  ea8c
        move.w  %d4,(0x648,%a5)                 | sau6 101ee50  3b44 0648
        bra.w   .L0101ee6c                      | sau6 101ee54  6000 0016
.L0101ee58:
        .short  0x98bc; .long KERNEL_LO_BYTES   | sau6 101ee58  98bc 0003 8000  sub.l   #KERNEL_LO_BYTES,%d4
        lsr.l   #5,%d4                          | sau6 101ee5e  ea8c
        lsr.l   #5,%d4                          | sau6 101ee60  ea8c
        swap    %d4                             | sau6 101ee62  4844
        move.w  (MOVE_TO_PPN+2:w,%pc),%d4       | sau6 101ee64  383a fdbc
        move.l  %d4,(0x652,%a5)                 | sau6 101ee68  2b44 0652
.L0101ee6c:
        move.l  (MOVE_TO_PPN:w,%pc),%d4         | sau6 101ee6c  283a fdb2
        lsl.l   #5,%d4                          | sau6 101ee70  eb8c
        lsl.l   #5,%d4                          | sau6 101ee72  eb8c
        .short  0x98bc; .long OS_PROC           | sau6 101ee74  98bc 7800 1000  sub.l   #OS_PROC,%d4
        .short  0x98bc; .long KERNEL_LO_BYTES   | sau6 101ee7a  98bc 0003 8000  sub.l   #KERNEL_LO_BYTES,%d4
        .short  0xd8bc; .long MMAP              | sau6 101ee80  d8bc 780d 4800  add.l   #MMAP,%d4
        movea.l %d4,%a4                         | sau6 101ee86  2844
        move.l  %a4,(0x75c,%a5)                 | sau6 101ee88  2b4c 075c
        lea     (cold_mem_bus_err:w,%pc),%a0    | sau6 101ee8c  41fa 0058
        move.l  %a0,(0x8,%a2)                   | sau6 101ee90  2548 0008
        move.w  #0xbfff,%d0                     | sau6 101ee94  303c bfff
.L0101ee98:
        clr.l   (%a4)+                          | sau6 101ee98  429c
        clr.l   (%a4)+                          | sau6 101ee9a  429c
        clr.l   (%a4)+                          | sau6 101ee9c  429c
        clr.l   (%a4)+                          | sau6 101ee9e  429c
        dbf     %d0,.L0101ee98                  | sau6 101eea0  51c8 fff6
        movea.l #0x1000000,%a0                  | sau6 101eea4  207c 0100 0000
        movea.l (cold_mmap_phys:w,%pc),%a4      | sau6 101eeaa  287a 04b0
        adda.l  #0,%a4                          | sau6 101eeae  d9fc 0000 0000
cold_mem_page:
        lea     (0x400,%a0),%a1                 | sau6 101eeb4  43e8 0400
        cmpa.l  #0x3000000,%a0                  | sau6 101eeb8  b1fc 0300 0000
        beq.s   .L0101ef12                      | sau6 101eebe  6752
        cmpa.l  #TRAP_PAGE_PHYS,%a0             | sau6 101eec0  b1fc 0101 e800
        beq.s   .L0101eefa                      | sau6 101eec6  6732
        cmpa.l  #0x3000000,%a0                  | sau6 101eec8  b1fc 0300 0000
        bge.s   .L0101eefa                      | sau6 101eece  6c2a
.L0101eed0:
        move.l  (%a0),%d4                       | sau6 101eed0  2810
        move.l  %d4,(%a0)+                      | sau6 101eed2  20c4
        cmpa.l  %a0,%a1                         | sau6 101eed4  b3c8
        bne.s   .L0101eed0                      | sau6 101eed6  66f8
        move.l  #0x40000000,(%a4)               | sau6 101eed8  28bc 4000 0000
        adda.l  #0x10,%a4                       | sau6 101eede  d9fc 0000 0010
        bra.s   cold_mem_page                   | sau6 101eee4  60ce
cold_mem_bus_err:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau6 101eee6  2e7a 0470
        bsr.s   .L0101ef04                      | sau6 101eeea  6118
        movea.l #0xbc00,%a3                     | sau6 101eeec  267c 0000 bc00
        ori.w   #0x440,(0x8,%a3)                | sau6 101eef2  006b 0440 0008
        bra.s   cold_mem_page                   | sau6 101eef8  60ba
.L0101eefa:
        adda.l  #0x10,%a4                       | sau6 101eefa  d9fc 0000 0010
        movea.l %a1,%a0                         | sau6 101ef00  2049
        bra.s   cold_mem_page                   | sau6 101ef02  60b0
.L0101ef04:
        adda.l  #0x1000,%a4                     | sau6 101ef04  d9fc 0000 1000
        adda.l  #0x40000,%a0                    | sau6 101ef0a  d1fc 0004 0000
        rts                                     | sau6 101ef10  4e75
.L0101ef12:
        lea     (0xbc00).l,%a0                  | sau6 101ef12  41f9 0000 bc00
        move.w  (0x8,%a0),%d7                   | sau6 101ef18  3e28 0008
        bset    #3,%d7                          | sau6 101ef1c  08c7 0003
        move.w  %d7,(0x8,%a0)                   | sau6 101ef20  3147 0008
        tst.b   (0x768,%a5)                     | sau6 101ef24  4a2d 0768
        beq.s   cold_mem_done                   | sau6 101ef28  6722
        move.w  #0x10,%d0                       | sau6 101ef2a  303c 0010
        movea.l (cold_mmap_phys:w,%pc),%a0      | sau6 101ef2e  207a 042c
        lea     (0x3800,%a0),%a0                | sau6 101ef32  41e8 3800
        lea     (0x7000,%a0),%a0                | sau6 101ef36  41e8 7000
        cmpi.l  #0x40000000,(%a0)               | sau6 101ef3a  0c90 4000 0000
        beq.s   .L0101ef46                      | sau6 101ef40  6704
        .short  0xd07c, 0x0020                  | sau6 101ef42  d07c 0020  add.w   #0x20,%d0
.L0101ef46:
        move.w  %d0,(0xa400).l                  | sau6 101ef46  33c0 0000 a400
cold_mem_done:
        move.l  (%sp)+,(0x8,%a2)                | sau6 101ef4c  255f 0008
        movea.l #0,%a2                          | sau6 101ef50  247c 0000 0000
        movec   %a2,%vbr                        | sau6 101ef56  4e7b a801
        lea     (cold_map_table:w,%pc),%a0      | sau6 101ef5a  41fa 02ba
        bsr.w   cold_map_pages                  | sau6 101ef5e  6100 00d4
        movea.l #VME_CTL,%a0                    | sau6 101ef62  207c 7fff 9400
        clr.w   %d0                             | sau6 101ef68  4240
        bset    #0xf,%d0                        | sau6 101ef6a  08c0 000f
        move.w  %d0,(0xa,%a0)                   | sau6 101ef6e  3140 000a
        clr.w   %d0                             | sau6 101ef72  4240
        bset    #0xf,%d0                        | sau6 101ef74  08c0 000f
        move.w  %d0,(0x6,%a0)                   | sau6 101ef78  3140 0006
        movea.l #MMU,%a0                        | sau6 101ef7c  207c 7fff b400
        move.l  (0x14,%a0),%d0                  | sau6 101ef82  2028 0014
        bclr    #3,%d0                          | sau6 101ef86  0880 0003
        bset    #0,%d0                          | sau6 101ef8a  08c0 0000
        bset    #8,%d0                          | sau6 101ef8e  08c0 0008
        move.l  %d0,(0x14,%a0)                  | sau6 101ef92  2140 0014
        move.l  %sp,(0x758,%a5)                 | sau6 101ef96  2b4f 0758
        move.l  #cold_fpu_probed,(0x2c).w       | sau6 101ef9a  21fc 0101 f008 002c
        movea.l #MMU,%a0                        | sau6 101efa2  207c 7fff b400
        btst    #7,(0x1b,%a0)                   | sau6 101efa8  0828 0007 001b
        beq.s   .L0101eff4                      | sau6 101efae  6744
        btst    #6,(0x1b,%a0)                   | sau6 101efb0  0828 0006 001b
        beq.s   .L0101eff4                      | sau6 101efb6  673c
        bclr    #5,(0x1b,%a0)                   | sau6 101efb8  08a8 0005 001b
        move.w  #1,(0xfc82).w                   | sau6 101efbe  31fc 0001 fc82
        move.l  (0xfffc).w,%d0                  | sau6 101efc4  2038 fffc
        move.w  #0,(0xfc82).w                   | sau6 101efc8  31fc 0000 fc82
        move.w  %d0,(MMU_$SYSTEM_REV+0x2).l     | sau6 101efce  33c0 7802 6dc8
        move.w  (0x1a,%a0),%d0                  | sau6 101efd4  3028 001a
        bset    #2,%d0                          | sau6 101efd8  08c0 0002
        bclr    #1,%d0                          | sau6 101efdc  0880 0001
        bset    #4,%d0                          | sau6 101efe0  08c0 0004
        bset    #5,%d0                          | sau6 101efe4  08c0 0005
        move.w  %d0,(0x1a,%a0)                  | sau6 101efe8  3140 001a
        st      (FPX_EXISTS).l                  | sau6 101efec  50f9 7809 bee4
        bra.s   cold_fpu_probed                 | sau6 101eff2  6014
.L0101eff4:
        bclr    #7,(0x9,%a0)                    | sau6 101eff4  08a8 0007 0009
        fmove.l #0,%fpcr                        | sau6 101effa  f23c 9000 0000 0000
        st      (M68881_EXISTS).l               | sau6 101f002  50f9 7809 bee6
cold_fpu_probed:
        movea.l (cold_saved_sp:w,%pc),%sp       | sau6 101f008  2e7a 034e
        ori.w   #0x440,(VME_CTL+0x8).l          | sau6 101f00c  0079 0440 7fff 9408
        movea.l #INT_STACK_GUARD,%sp            | sau6 101f014  2e7c 780d 2000
        pea     (cold_diskless_info:w,%pc)      | sau6 101f01a  487a 0320
        pea     (cold_boot_params:w,%pc)        | sau6 101f01e  487a 0310
        movea.l #OS_$INIT,%a0                   | sau6 101f022  207c 7803 cd62
        btst    #0xf,(cold_boot_params+6:w,%pc) | sau6 101f028  083a 000f 030a
        beq.s   cold_call_os_init               | sau6 101f02e  6702
        trap    #0xf                            | sau6 101f030  4e4f
cold_call_os_init:
        jsr     (%a0)                           | sau6 101f032  4e90
cold_map_pages:
        tst.b   (0x768,%a5)                     | sau6 101f034  4a2d 0768
        beq.s   .L0101f04a                      | sau6 101f038  6710
        lea     (0x10000).l,%a3                 | sau6 101f03a  47f9 0001 0000
        move.w  #0x3ff,%d4                      | sau6 101f040  383c 03ff
.L0101f044:
        clr.l   (%a3)+                          | sau6 101f044  429b
        dbf     %d4,.L0101f044                  | sau6 101f046  51cc fffc
.L0101f04a:
        move.l  (MOVE_TO_PPN:w,%pc),%d0         | sau6 101f04a  203a fbd4
        lsl.l   #5,%d0                          | sau6 101f04e  eb88
        lsl.l   #5,%d0                          | sau6 101f050  eb88
        .short  0x90bc; .long OS_PROC           | sau6 101f052  90bc 7800 1000  sub.l   #OS_PROC,%d0
        .short  0x90bc; .long KERNEL_LO_BYTES   | sau6 101f058  90bc 0003 8000  sub.l   #KERNEL_LO_BYTES,%d0
        move.l  %d0,%d1                         | sau6 101f05e  2200
        .short  0xd2bc; .long SMAPS             | sau6 101f060  d2bc 7821 4c00  add.l   #SMAPS,%d1
        move.l  %d1,(0x760,%a5)                 | sau6 101f066  2b41 0760
        move.l  %d0,%d1                         | sau6 101f06a  2200
        .short  0xd2bc; .long OS_PMAPS          | sau6 101f06c  d2bc 7819 4800  add.l   #OS_PMAPS,%d1
        move.l  %d1,(0x764,%a5)                 | sau6 101f072  2b41 0764
        movea.l #RARS_PHYS,%a2                  | sau6 101f076  247c 0100 1800
        move.l  #0x73ff,%d4                     | sau6 101f07c  283c 0000 73ff
.L0101f082:
        clr.l   (%a2)+                          | sau6 101f082  429a
        dbf     %d4,.L0101f082                  | sau6 101f084  51cc fffc
        movea.l (cold_os_pmaps_phys:w,%pc),%a2  | sau6 101f088  247a 02da
        move.l  #OS_PAGE_END+0x3,%d4            | sau6 101f08c  283c 7825 0803
        .short  0x98bc; .long OS_PMAPS          | sau6 101f092  98bc 7819 4800  sub.l   #OS_PMAPS,%d4
        lsr.l   #2,%d4                          | sau6 101f098  e48c
        subq.l  #1,%d4                          | sau6 101f09a  5384
.L0101f09c:
        clr.l   (%a2)+                          | sau6 101f09c  429a
        dbf     %d4,.L0101f09c                  | sau6 101f09e  51cc fffc
        clr.w   %d4                             | sau6 101f0a2  4244
        subq.l  #1,%d4                          | sau6 101f0a4  5384
        bcc.s   .L0101f09c                      | sau6 101f0a6  64f4
        movea.l (cold_mmap_phys:w,%pc),%a4      | sau6 101f0a8  287a 02b2
        clr.l   %d1                             | sau6 101f0ac  4281
        clr.l   %d3                             | sau6 101f0ae  4283
.L0101f0b0:
        move.w  (%a0)+,%d0                      | sau6 101f0b0  3018
        beq.w   .L0101f170                      | sau6 101f0b2  6700 00bc
        move.w  (%a0)+,%d1                      | sau6 101f0b6  3218
        move.l  (%a0)+,%d2                      | sau6 101f0b8  2418
        move.l  %d2,%d5                         | sau6 101f0ba  2a02
        lsr.l   #8,%d5                          | sau6 101f0bc  e08d
        lsr.l   #5,%d5                          | sau6 101f0be  ea8d
        .short  0xcabc, 0x0000, 0x3ffc          | sau6 101f0c0  cabc 0000 3ffc  and.l   #0x3ffc,%d5
        btst    #0x1e,%d2                       | sau6 101f0c6  0802 001e
        bne.s   .L0101f0fa                      | sau6 101f0ca  662e
        movea.l (cold_smaps_phys:w,%pc),%a2     | sau6 101f0cc  247a 0292
        movea.l (cold_os_pmaps_phys:w,%pc),%a3  | sau6 101f0d0  267a 0292
        adda.l  #0x4400,%a2                     | sau6 101f0d4  d5fc 0000 4400
        adda.l  #0x80000,%a3                    | sau6 101f0da  d7fc 0008 0000
        tst.w   %d5                             | sau6 101f0e0  4a45
        beq.s   .L0101f10e                      | sau6 101f0e2  672a
        adda.l  #0x400,%a2                      | sau6 101f0e4  d5fc 0000 0400
        adda.w  #0x80,%a3                       | sau6 101f0ea  d6fc 0080
        .short  0xcabc, 0x0000, 0x03fc          | sau6 101f0ee  cabc 0000 03fc  and.l   #0x3fc,%d5
        adda.l  %d5,%a2                         | sau6 101f0f4  d5c5
        bra.w   .L0101f10e                      | sau6 101f0f6  6000 0016
.L0101f0fa:
        movea.l (cold_smaps_phys:w,%pc),%a2     | sau6 101f0fa  247a 0264
        movea.l (cold_os_pmaps_phys:w,%pc),%a3  | sau6 101f0fe  267a 0264
        adda.l  #0x400,%a2                      | sau6 101f102  d5fc 0000 0400
        adda.l  %d5,%a2                         | sau6 101f108  d5c5
        lsl.l   #5,%d5                          | sau6 101f10a  eb8d
        adda.l  %d5,%a3                         | sau6 101f10c  d7c5
.L0101f10e:
        move.w  (%a0)+,%d4                      | sau6 101f10e  3818
        swap    %d4                             | sau6 101f110  4844
        move.l  %d4,%d3                         | sau6 101f112  2604
        lsl.l   #6,%d3                          | sau6 101f114  ed8b
        .short  0xc8bc, 0xfc00, 0x0000          | sau6 101f116  c8bc fc00 0000  and.l   #0xfc000000,%d4
        clr.w   %d4                             | sau6 101f11c  4244
        adda.l  %d4,%a3                         | sau6 101f11e  d7c4
        move.w  #0x7c00,%d3                     | sau6 101f120  363c 7c00
        and.w   %d2,%d3                         | sau6 101f124  c642
        bra.w   .L0101f13a                      | sau6 101f126  6000 0012
.L0101f12a:
        move.w  #0x7c00,%d3                     | sau6 101f12a  363c 7c00
        and.w   %d2,%d3                         | sau6 101f12e  c642
        bne.s   .L0101f13c                      | sau6 101f130  660a
        addq.l  #4,%a2                          | sau6 101f132  588a
        adda.l  #0x80,%a3                       | sau6 101f134  d7fc 0000 0080
.L0101f13a:
        move.l  %a3,(%a2)                       | sau6 101f13a  248b
.L0101f13c:
        lsr.w   #8,%d3                          | sau6 101f13c  e04b
        .short  0x82bc, 0x8000, 0x0000          | sau6 101f13e  82bc 8000 0000  or.l    #0x80000000,%d1
        move.l  %d1,(0x0,%a3,%d3.w)             | sau6 101f144  2781 3000
        .short  0xc6bc, 0xc000, 0x0000          | sau6 101f148  c6bc c000 0000  and.l   #0xc0000000,%d3
        clr.l   %d4                             | sau6 101f14e  4284
        move.w  %d1,%d4                         | sau6 101f150  3801
        .short  0x987c, 0x4000                  | sau6 101f152  987c 4000  sub.w   #0x4000,%d4
        bcs.s   .L0101f160                      | sau6 101f156  6508
        mulu.w  #0x10,%d4                       | sau6 101f158  c8fc 0010
        move.l  %d3,(0x0,%a4,%d4.l)             | sau6 101f15c  2983 4800
.L0101f160:
        addq.w  #1,%d1                          | sau6 101f160  5241
        .short  0xd4bc, 0x0000, 0x0400          | sau6 101f162  d4bc 0000 0400  add.l   #0x400,%d2
        subq.w  #1,%d0                          | sau6 101f168  5340
        bne.s   .L0101f12a                      | sau6 101f16a  66be
        bra.w   .L0101f0b0                      | sau6 101f16c  6000 ff42
.L0101f170:
        movea.l (cold_os_pmaps_phys:w,%pc),%a0  | sau6 101f170  207a 01f2
        adda.l  #0x80000,%a0                    | sau6 101f174  d1fc 0008 0000
        bset    #0x1b,(%a0)                     | sau6 101f17a  08d0 001b
        movea.l #RARS_PHYS+0x3b8,%a1            | sau6 101f17e  227c 0100 1bb8
        move.l  (cold_smaps_phys:w,%pc),%d4     | sau6 101f184  283a 01da
        .short  0x88bc, 0xc000, 0x0000          | sau6 101f188  88bc c000 0000  or.l    #0xc0000000,%d4
        move.w  #0,%d1                          | sau6 101f18e  323c 0000
.L0101f192:
        move.l  %d4,(%a1)+                      | sau6 101f192  22c4
        .short  0xd8bc, 0x0000, 0x0400          | sau6 101f194  d8bc 0000 0400  add.l   #0x400,%d4
        dbf     %d1,.L0101f192                  | sau6 101f19a  51c9 fff6
        movea.l #RARS_PHYS+0x3c0,%a1            | sau6 101f19e  227c 0100 1bc0
        move.w  #0xf,%d1                        | sau6 101f1a4  323c 000f
.L0101f1a8:
        move.l  %d4,(%a1)+                      | sau6 101f1a8  22c4
        .short  0xd8bc, 0x0000, 0x0400          | sau6 101f1aa  d8bc 0000 0400  add.l   #0x400,%d4
        dbf     %d1,.L0101f1a8                  | sau6 101f1b0  51c9 fff6
        eori.l  #0x40000000,%d4                 | sau6 101f1b4  0a84 4000 0000
        movea.l #RARS_PHYS,%a1                  | sau6 101f1ba  227c 0100 1800
        move.l  %d4,(%a1)                       | sau6 101f1c0  2284
        .short  0xd8bc, 0x0000, 0x0400          | sau6 101f1c2  d8bc 0000 0400  add.l   #0x400,%d4
        move.l  %d4,(0x8,%a1)                   | sau6 101f1c8  2344 0008
        movea.l #0x8000,%a0                     | sau6 101f1cc  207c 0000 8000
        move.b  #0,(0x7,%a0)                    | sau6 101f1d2  117c 0000 0007
        move.w  #0x4006,(0x12,%a0)              | sau6 101f1d8  317c 4006 0012
        clr.b   %d0                             | sau6 101f1de  4200
        bset    #0,%d0                          | sau6 101f1e0  08c0 0000
        move.b  %d0,(0x3,%a0)                   | sau6 101f1e4  1140 0003
        move.b  #0xff,(EC_$NIL_EC).l            | sau6 101f1e8  13fc 00ff 0000 0000
        move.l  #RARS_PHYS,(DUMP_$RARS_PHADDR).l | sau6 101f1f0  23fc 0100 1800 7800 0fe8
        move.l  (cold_smaps_phys:w,%pc),(DUMP_$SMAP_PHADDR).l | sau6 101f1fa  23fa 0164 7800 0e1e
        move.l  #RARS_PHYS,(MMU_$RARS_PHADDR).l | sau6 101f202  23fc 0100 1800 7802 68a0
        move.l  (cold_os_pmaps_phys:w,%pc),(MMU_$OS_PMAPS_PHADDR).l | sau6 101f20c  23fa 0156 7802 689c
        rts                                     | sau6 101f214  4e75
/*
 * cold_map_table, 0x101F216: what cold_map_pages maps, 10 bytes an entry
 * (page count, first PPN, VA, the protection word: its bits 9..8 the
 * MMAP flags, 2 wired, 1 COLD's), ended by a zero count.
 */
cold_map_table:
        .short  0x0001, 0x4000          /* 101f216  the CRASH_RECORD page */
        .long   OS_BEGIN
        .short  0xde00
        .short  0x0002, 0x4003          /* 101f220  DUMP, where COLD copied it */
        .long   DUMP
        .short  0xde00
        .short  0x0001, 0x407a          /* 101f22a  the new trap page */
        .long   TRAP_PAGE
        .short  0xce00
        .short  0x001f, 0x0001          /* 101f234  low memory identity */
        .long   0x00000400
        .short  0xcc00
        .short  0x0002, 0x407b          /* 101f23e  COLD itself */
        .long   COLD_LOW
        .short  0xdd00
cold_map_kernel_lo_count:
        .short  0x00e0, 0x407f          /* 101f248  kernel, low piece; the count is */
                                        /*          rewritten if the kernel fits */
        .long   OS_PROC
        .short  0xde00
cold_map_kernel_hi_count_ppn:
        .short  0x0000, 0x0000          /* 101f252  kernel, high piece: count and */
                                        /*          PPN filled by COLD */
        .long   KERNEL_HI_VA
        .short  0xde00
        .short  0x0074, 0x4006          /* 101f25c  RARS, 0x74 pages */
        .long   RARS
        .short  0xde00
        .short  0x0004, 0x0040          /* 101f266  IOMAP */
        .long   IOMAP
        .short  0xd800
        .short  0x0001, 0x0027          /* 101f270  TAPE (and WIN) */
        .long   TAPE
        .short  0xd800
        .short  0x0080, 0x0480          /* 101f27a  TAPE6 (and WIN6), 128 pages */
        .long   TAPE6
        .short  0xd800
        .short  0x0001, 0x0026          /* 101f284  RING2 */
        .long   RING2
        .short  0xd800
        .short  0x0001, 0x0020          /* 101f28e  MMU */
        .long   MMU
        .short  0xd800
        .short  0x0001, 0x0021          /* 101f298  SIO */
        .long   SIO
        .short  0xd800
        .short  0x0001, 0x0022          /* 101f2a2  TIMR (and CALENDAR) */
        .long   TIMR
        .short  0xd800
        .short  0x0001, 0x0029          /* 101f2ac  PBU_CTL */
        .long   PBU_CTL
        .short  0xd800
        .short  0x0003, 0x0038          /* 101f2b6  the color board's three pages */
        .long   COLOR_SUP
        .short  0xd800
        .short  0x0001, 0x003c          /* 101f2c0  DISP1 */
        .long   DISP1
        .short  0xd800
        .short  0x0001, 0x003d          /* 101f2ca  DISP2 */
        .long   DISP2
        .short  0xd800
        .short  0x0001, 0x003f          /* 101f2d4  MEM */
        .long   MEM
        .short  0xd800
        .short  0x0020, 0x01c0          /* 101f2de  the PBU's window, 32 pages */
        .long   PBU
        .short  0xd800
cold_map_disp1_mem:
        .short  0x0080, 0x0000          /* 101f2e8  DISP1_MEM, 128 pages; PPN */
        .long   DISP1_MEM               /*          and VA set by COLD */
        .short  0xd800
cold_map_disp2_mem:
        .short  0x0080, 0x0000          /* 101f2f2  DISP2_MEM, 128 pages; PPN */
        .long   DISP2_MEM               /*          and VA set by COLD */
        .short  0xd800
        .short  0x0040, 0x0000          /* 101f2fc  KOLOR_CTL, 64 pages; PPN set */
        .long   KOLOR_CTL               /*          by COLD */
        .short  0x9800
        .short  0x0001, 0x0025          /* 101f306  GPU */
        .long   GPU
        .short  0xd800
        .short  0x0001, 0x0500          /* 101f310  ETHERNET1 (IODEFS) */
        .long   ETHERNET1
        .short  0xd800
        .short  0x0001, 0x0540          /* 101f31a  ETHERNET2 */
        .long   ETHERNET2
        .short  0xd800
        .short  0x0001, 0x002f          /* 101f324  VME_CTL */
        .long   VME_CTL
        .short  0xd800
        .short  0x0000                  /* 101f32e  end */

/*
 * 0x101F330: the boot record OS_$INIT receives as its first argument
 * (d1 and d2 of the entry are its first two longwords) and 0x101F33C:
 * the diskless record, its second argument (the 7 copied longwords),
 * then COLD's own cells.  All zero in the file.
 */
cold_boot_params:
        .long   0, 0, 0                 /* 101f330 */
cold_diskless_info:
        .long   0, 0, 0, 0, 0, 0, 0     /* 101f33c */
cold_saved_sp:
        .long   0                       /* 101f358 */
cold_mmap_phys:
        .long   0                       /* 101f35c  MMAP's physical address */
cold_smaps_phys:
        .long   0                       /* 101f360  SMAPS's physical address */
cold_os_pmaps_phys:
        .long   0                       /* 101f364  OS_PMAPS's physical address */
cold_pbu_present:
        .byte   0                       /* 101f368  set when the PBU controller answers */

/* 0x101F369..0x101F3FC: COLD's stack, zero in the file. */
        .space  0x93
cold_stack_top:                         /* 101f3fc  the initial SP; COLD + 0x7FC, */
                                        /*          the map's segment end */
        .space  4                       /*          the file's pad up to DUMP at 0x800 */
