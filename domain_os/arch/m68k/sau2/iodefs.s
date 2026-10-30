/*
 * arch/m68k/sau2/iodefs.s - the SAU2 map's absolute symbols, as link-time
 * symbols
 *
 * The binder resolved references to the I/O pages, to the PTT/PROT
 * windows and to the trap page through absolute symbols (the map's IODEFS
 * module, and the zero-size PTT, PROT and TRAP_PAGE segments), which is
 * why those operand cells are in its fixup table (RELOC: 205 I/O cells,
 * 9 PTT cells and the low absolutes 0, 8, 0x2C.., 0x100).  The hand assembly and the Pascal
 * reference them by name, so each such cell is an R_68K_32 relocation the
 * fixup generator finds; this object defines them,
 * once, as absolute globals.  It has no bytes.
 *
 * Every value is the map's (`grep' the symbol in domain_os.10.2.map);
 * `tools/gen_layout_ld.py --check-elf' compares each one in the linked ELF
 * with the map (the fixed-VA check), so a typo here fails `make check'.
 *
 *   D52  F4FC00  IODEFS_GUARD       loaded at 25DF1A, size = 0
 *        FC0000  DISP1_MEM / IODEFS   ...   FFB400  MMU    FFB800  PFT
 *
 * IODEFS_GUARD itself is not defined here: it is VM_TABLES_END, the end of
 * the kernel's run-time VM-table windows, a layout position rather than
 * hardware, which kernel.ld defines past OS_PAGE_END and sau2.ld ASSERTs
 * below DISP1_MEM.
 *   D54  700000  PTT                loaded at 700000, size = 0
 *        CC0000  PROT
 *   D37       0  TRAP_PAGE          loaded at 0, size = 400
 *
 * The hardware addresses are the SAU2's (they are per-SAU).
 * The trap page's vectors are the 68000 family's exception
 * vector table and PROM_$MACHINE_ID a PROM cell, the same on every m68k
 * Apollo: they are here because the map lists them in the TRAP_PAGE
 * segment and the Makefile assembles only arch/m68k/<sau>/*.s; an
 * arch/m68k-wide file would be their home once there is a second SAU.
 */

/* The trap page (`D37 0 TRAP_PAGE size = 400'): the map's vectors (the
 * 68000 family's exception vector numbers in the comments), which the
 * kernel writes its handlers into by absolute address (PEB_$INIT `move.l
 * #0xe2446c,(0x00000070).l', peb/init.pas). */
        .globl  TRAP_PAGE
        .globl  BUS_ERROR_VEC
        .globl  ADDRESS_ERROR_VEC
        .globl  ILLEGAL_INST_VEC
        .globl  ZERO_DIVIDE_VEC
        .globl  CHK_INST_VEC
        .globl  TRAPV_INST_VEC
        .globl  PRIV_VIOL_VEC
        .globl  TRACE_VEC
        .globl  UNIMP_VEC
        .globl  INV_STACK_VEC
        .globl  SPURIOUS_INT_VEC
        .globl  SIO_VEC
        .globl  KEYBD_VEC
        .globl  RING_VEC
        .globl  DISP1_VEC
        .globl  PEB_VEC
        .globl  DISK_VEC
        .globl  WIN_VEC
        .globl  FLP_VEC
        .globl  TIMER_VEC
        .globl  PARITY_VEC
        .globl  TRAP_VEC
        .globl  PROM_$MACHINE_ID

        .equ    TRAP_PAGE,          0x00000000  /* the exception vector page (VBR) */
        .equ    BUS_ERROR_VEC,      0x00000008  /* vector 2 */
        .equ    ADDRESS_ERROR_VEC,  0x0000000C  /* vector 3 */
        .equ    ILLEGAL_INST_VEC,   0x00000010  /* vector 4 */
        .equ    ZERO_DIVIDE_VEC,    0x00000014  /* vector 5 */
        .equ    CHK_INST_VEC,       0x00000018  /* vector 6 */
        .equ    TRAPV_INST_VEC,     0x0000001C  /* vector 7 */
        .equ    PRIV_VIOL_VEC,      0x00000020  /* vector 8 */
        .equ    TRACE_VEC,          0x00000024  /* vector 9 */
        .equ    UNIMP_VEC,          0x00000028  /* vector 10, line 1010 */
        .equ    INV_STACK_VEC,      0x00000038  /* vector 14 (format error) */
        .equ    SPURIOUS_INT_VEC,   0x00000060  /* vector 24 */
        .equ    SIO_VEC,            0x00000064  /* autovector level 1 */
        .equ    KEYBD_VEC,          0x00000068  /* autovector level 2 */
        .equ    RING_VEC,           0x0000006C  /* autovector level 3 */
        .equ    DISP1_VEC,          0x00000070  /* autovector level 4 */
        .equ    PEB_VEC,            0x00000070  /* autovector level 4 (shared with DISP1_VEC) */
        .equ    DISK_VEC,           0x00000074  /* autovector level 5 */
        .equ    WIN_VEC,            0x00000074  /* autovector level 5 */
        .equ    FLP_VEC,            0x00000074  /* autovector level 5 */
        .equ    TIMER_VEC,          0x00000078  /* autovector level 6 */
        .equ    PARITY_VEC,         0x0000007C  /* autovector level 7 */
        .equ    TRAP_VEC,           0x00000080  /* vector 32, TRAP #0 */
        .equ    PROM_$MACHINE_ID,   0x00000100  /* the PROM's machine id cell (prom/prom.ins.pas) */

/* The PTT and PROT windows (`D54 700000 PTT size = 0'). */
        .globl  PTT
        .globl  PROT

        .equ    PTT,        0x00700000  /* page translation table window */
        .equ    PROT,       0x00CC0000  /* the PROT window (user space ends here); the 68020 fixups move it to 0x3AC0000 */

/* IODEFS (map symbols FC0000 DISP1_MEM / IODEFS .. FFB800 PFT, after
 * `D52 F4FC00 IODEFS_GUARD'), in map order: display memory, the PEB pages,
 * four one-page windows (CHK_BUFF, AST_$COPY_BUFF, AST_$ZERO_BUFF,
 * PAR_BUFF) and the device registers.  Names sharing an address are the
 * map's aliases. */
        .globl  IODEFS
        .globl  DISP1_MEM
        .globl  PEB_$M_CTRL_PAGE
        .globl  PEB_CTL
        .globl  FPU_CTL
        .globl  PEB
        .globl  PEB_$M_DCMD_PAGE
        .globl  FPU_CMD
        .globl  PEB_$M_CS_PAGE
        .globl  FPU_CS
        .globl  CHK_BUFF
        .globl  AST_$COPY_BUFF
        .globl  AST_$ZERO_BUFF
        .globl  PAR_BUFF
        .globl  DISP1
        .globl  RING2
        .globl  DMA
        .globl  CALENDAR
        .globl  FLOP
        .globl  DISK
        .globl  WIN
        .globl  TIMR
        .globl  SIO
        .globl  MMU
        .globl  PFT

        .equ    IODEFS,     0x00FC0000  /* the start of the I/O space; OS_$INIT compares IODEFS_GUARD with it (0x00E33982) */
        .equ    DISP1_MEM,  0x00FC0000  /* display memory */
        .equ    PEB_$M_CTRL_PAGE, 0x00FF7000  /* the PEB (FPU) control page */
        .equ    PEB_CTL,    0x00FF7000
        .equ    FPU_CTL,    0x00FF7000
        .equ    PEB,        0x00FF7000
        .equ    PEB_$M_DCMD_PAGE, 0x00FF7400  /* the PEB command page */
        .equ    FPU_CMD,    0x00FF7400
        .equ    PEB_$M_CS_PAGE, 0x00FF7800  /* the PEB control store page */
        .equ    FPU_CS,     0x00FF7800
        .equ    CHK_BUFF,   0x00FF8400
        .equ    AST_$COPY_BUFF, 0x00FF8800  /* AST's copy window (ast/ast.ins.pas) */
        .equ    AST_$ZERO_BUFF, 0x00FF8C00  /* AST's zeroing window (ast/ast.ins.pas) */
        .equ    PAR_BUFF,   0x00FF9000  /* the parity scratch page (parity/parity.ins.pas) */
        .equ    DISP1,      0x00FF9800  /* display controller */
        .equ    RING2,      0x00FF9C00  /* token ring controller */
        .equ    DMA,        0x00FFA000  /* DMA controller */
        .equ    CALENDAR,   0x00FFA800  /* calendar, floppy, disk and Winchester: one page */
        .equ    FLOP,       0x00FFA800
        .equ    DISK,       0x00FFA800
        .equ    WIN,        0x00FFA800
        .equ    TIMR,       0x00FFAC00  /* timer */
        .equ    SIO,        0x00FFB000  /* serial I/O */
        .equ    MMU,        0x00FFB400  /* MMU registers */
        .equ    PFT,        0x00FFB800  /* page frame table */
