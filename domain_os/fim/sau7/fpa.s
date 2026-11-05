/*
 * fim/sau7/fpa.s - FPA_$DEBUG1 .. FPA_$DEBUG9, the floating-point
 * accelerator's bus error entry and its context switch (SAU7)
 *
 * SAU7 map, in "D 3C426334 FIM_WIRED size = 1804": FPA_$DEBUG1 ..
 * FPA_$DEBUG9 at 0x3C426642..0x3C426653, then the code with no map
 * name to 0x3C4269CB (FIM_$FLINE's section, fim/m68k/fline.s, starts at
 * its bus error entry 0x3C4269CC).  One section, keyed by FPA_$DEBUG1:
 *
 *   0x3C426642  FPA_$DEBUG1 .. 9   nine counter words (below)
 *   0x3C426654  fpa_$bus_err_entry FIM_$BUS_ERR's arm for an access at
 *                                  16#FFF80000 and up with FPA_$SAVEP set
 *   0x3C4266D4  fpa_$switch_owner     \  the owner switch, as the FPU's
 *   0x3C4266DA  fpa_$switch_owner_d2   | (fp/m68k/fp_context.s
 *   0x3C426710  fpa_$restore_state     | fp_$switch_owner ..
 *   0x3C42682C  fpa_$save_state       /  fp_$save_state)
 *   0x3C4268D2  fpa_$fp_init       FIM_$FP_INIT's arm (fim/m68k/fp_init.s)
 *   0x3C426936  fpa_$get_fp        FP_$GET_FP's arm (fp/m68k/fp_context.s)
 *   0x3C426962  fpa_$check_owner
 *   0x3C42699E  fpa_$put_fp        FP_$PUT_FP's arm
 *
 * The accelerator (`fpa_board', base/config.ins.pas) has the FPU's
 * cells again in fp/m68k/savep.s: FPA_$SAVEP, the base of its save-area
 * table, set when the board is there (PEB_$LOAD_WCS); FPA_$OWNER, the
 * address space whose state it holds; fpa_$exclusion, the lock of that
 * state.  Its registers are reached absolute short:
 *   16#FFFF8000 + n * 16#400   register n (0 .. 15), its two longwords
 *                              read at + 16#14 and + 16#18, written at
 *                              + 16#0C and + 16#14 (the window's
 *                              address picks the operation);
 *   16#FFFF8043 .. 16#FFFF805B six bytes, read and written in place;
 *   16#FFFF8083 .. 16#FFFF80BB the twelve WTK status bytes, read
 *                              (FIM_$FP_GET_WTK_STATUS), and written at
 *                              16#FFFF80C3 .. 16#FFFF80FB
 *                              (FIM_$FP_PUT_WTK_STATUS; fim/sau7/
 *                              fpa_regs.s);
 * and absolute long its control and status register (FPA_CSR, the
 * FPCSR) and its exception register (FPA_EIR).  Bit 31 of the register
 * is cleared while the state is read or written.  The CPU control
 * register's bit 1 (MMU + 16#101 and its copy, MMU_$PID_PRIV's low
 * byte, written at IPL 7) is set while no address space owns the
 * accelerator, so that an access traps; the owner switch clears it.
 *
 * The save-area table has 156 bytes per address space 1 .. n, the slot
 * of asid at (asid - 1) * 156: the flag word (1: a state saved), the 16
 * registers' 32 longwords, the 18 status bytes, the exception register
 * and the control and status register.
 *
 * Hand-written: register arguments (D0 and D2 the address spaces, A1
 * FPA_$SAVEP), routines falling through into one another, the bus error
 * frame and its scratch shared with FIM_$BUS_ERR (fim/sau7/bus_err.s).
 * The Apollo assembler's <ea>=#imm forms (add/sub/cmp #imm,Dn), which
 * gas spells addi/subi/cmpi, are written as `.short'.
 *
 * Byte gate (the SAU7 has no asm_compare tables yet): assembled with
 * `m68k-elf-as -m68030 -m68881' and compared with the image at the
 * map's addresses by tools/asm_compare.py's rules, modulo relocations.
 * The address and byte columns are the SAU7 image's.
 */

        .include "base/config.inc"
        .if fpa_board

        .section ".text.FPA_$DEBUG1","ax",@progbits
        .even

        .globl  FPA_$DEBUG1
        .globl  FPA_$DEBUG2
        .globl  FPA_$DEBUG3
        .globl  FPA_$DEBUG4
        .globl  FPA_$DEBUG5
        .globl  FPA_$DEBUG6
        .globl  FPA_$DEBUG7
        .globl  FPA_$DEBUG8
        .globl  FPA_$DEBUG9
        .globl  fpa_$bus_err_entry
        .globl  fpa_$switch_owner
        .globl  fpa_$switch_owner_d2
        .globl  fpa_$restore_state
        .globl  fpa_$save_state
        .globl  fpa_$fp_init
        .globl  fpa_$get_fp
        .globl  fpa_$check_owner
        .globl  fpa_$put_fp

        .extern FPA_$SAVEP              /* fp/m68k/savep.s */
        .extern FPA_$OWNER              /* fp/m68k/savep.s */
        .extern fpa_$exclusion          /* fp/m68k/savep.s */
        .extern MMU_$BUS_STATUS         /* fim/sau7/bus_err.s */
        .extern MMU_$PID_PRIV           /* mmu/: the CPU control register's copy */
        .extern MMU                     /* the MMU's page; + 0x101 the CPU control register */
        .extern PROC1_$AS_ID
        .extern ML_$EXCLUSION_START
        .extern ML_$EXCLUSION_STOP
        .extern FIM_$FP_INTERLUDE_HANDLER /* fim/: the accelerator's exception (FIM_FP) */
        .extern FIM_$EXIT               /* fim/m68k/exit.s */
        .extern FIM_COM                 /* fim/m68k/com.s: FIM_$COM */

        .equ    FPA_CSR,            0xFFF90000  /* the control and status register */
        .equ    FPA_EIR,            0xFFF80000  /* the exception register */
        .equ    FPA_CSR_FRESH,      0x83D00000  /* a fresh context's register */
        .equ    FPA_SAVE_AREA_SIZE, 156         /* bytes per address space */

        .equ    SIGFPE,             8
        .equ    FAULT_CLASS_FPA,    0xA008

/* The counters (FPA_$DEBUGn, nothing reads them):
 *   1  accesses by address space 0     2  accesses by the owner
 *   3  fresh contexts loaded           4  saved contexts loaded
 *   5  contexts saved                  6  FIM_$FSAVE saves for bit 4
 *   7  FIM_$FSAVE saves                8  FIM_$FRESTORE loads
 *   9  states the FSAVE-frame copier steps over */
FPA_$DEBUG1:                                    | 3c426642
        .short  0
FPA_$DEBUG2:                                    | 3c426644
        .short  0
FPA_$DEBUG3:                                    | 3c426646
        .short  0
FPA_$DEBUG4:                                    | 3c426648
        .short  0
FPA_$DEBUG5:                                    | 3c42664a
        .short  0
FPA_$DEBUG6:                                    | 3c42664c
        .short  0
FPA_$DEBUG7:                                    | 3c42664e
        .short  0
FPA_$DEBUG8:                                    | 3c426650
        .short  0
FPA_$DEBUG9:                                    | 3c426652
        .short  0

/* -------------------------------------------------------------------------
 * fpa_$bus_err_entry - 0x3C426654: FIM_$BUS_ERR's arm for an access to
 * the accelerator, with its registers D0-D3/A0-A2 saved over the 8-byte
 * fault descriptor scratch.  Bit 3 of the bus status (MMU_$BUS_STATUS)
 * set: an address space that does not own the accelerator touched it;
 * the owner is switched under the accelerator's lock and the instruction
 * retried (address space 0 and the owner itself only counted).  Clear:
 * the accelerator's exception, which FIM_$FP_INTERLUDE_HANDLER handles at
 * IPL 0; a status it returns is delivered as SIGFPE through FIM_$COM,
 * 0 retries.
 * ------------------------------------------------------------------------- */
fpa_$bus_err_entry:
        btst    #3,(MMU_$BUS_STATUS+1:w,%pc)    | 3c426654  083a 0003 fd4f
        bne.s   .Lbe_not_owner                  | 3c42665a  6636
        andi.w  #0xf8ff,%sr                     | 3c42665c  027c f8ff  IPL 0
        subq.w  #4,%sp                          | 3c426660  594f  the status
        pea     (%sp)                           | 3c426662  4857
        jsr     (FIM_$FP_INTERLUDE_HANDLER).l   | 3c426664  4eb9 3c46 e7f8
        addq.w  #4,%sp                          | 3c42666a  584f
        move.l  (%sp)+,%d1                      | 3c42666c  221f
        beq.w   .Lbe_retry                      | 3c42666e  6700 005a
        move.l  %d1,(0x1c,%sp)                  | 3c426672  2f41 001c  descriptor: status
        move.w  #SIGFPE,(0x20,%sp)              | 3c426676  3f7c 0008 0020  signal
        move.w  #FAULT_CLASS_FPA,(0x22,%sp)     | 3c42667c  3f7c a008 0022  class
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c426682  4cdf 070f
        pea     (%sp)                           | 3c426686  4857  &descriptor
        pea     (0xc,%sp)                       | 3c426688  486f 000c  &frame
        jmp     (FIM_COM).l                     | 3c42668c  4ef9 3c42 5844
.Lbe_not_owner:
        move.w  (PROC1_$AS_ID).l,%d2            | 3c426692  3439 3c42 4aa2
        bne.s   .Lbe_live                       | 3c426698  6608
        addq.w  #1,(FPA_$DEBUG1).l              | 3c42669a  5279 3c42 6642
        bra.s   .Lbe_retry                      | 3c4266a0  6028
.Lbe_live:
        cmp.w   (FPA_$OWNER:w,%pc),%d2          | 3c4266a2  b47a fcee
        bne.s   .Lbe_switch                     | 3c4266a6  6608
        addq.w  #1,(FPA_$DEBUG2).l              | 3c4266a8  5279 3c42 6644
        bra.s   .Lbe_retry                      | 3c4266ae  601a
.Lbe_switch:
        pea     (fpa_$exclusion:w,%pc)          | 3c4266b0  487a fce2
        jsr     (ML_$EXCLUSION_START).l         | 3c4266b4  4eb9 3c42 529a
        addq.l  #4,%sp                          | 3c4266ba  588f
        bsr.s   fpa_$switch_owner_d2            | 3c4266bc  611c
        pea     (fpa_$exclusion:w,%pc)          | 3c4266be  487a fcd4
        jsr     (ML_$EXCLUSION_STOP).l          | 3c4266c2  4eb9 3c42 5320
        addq.l  #4,%sp                          | 3c4266c8  588f
.Lbe_retry:
        movem.l (%sp)+,%d0-%d3/%a0-%a2          | 3c4266ca  4cdf 070f
        addq.w  #8,%sp                          | 3c4266ce  504f
        jmp     (FIM_$EXIT:w,%pc)               | 3c4266d0  4efa 141e  retry the instruction

/* -------------------------------------------------------------------------
 * fpa_$switch_owner - 0x3C4266D4: make the current address space the
 * accelerator's owner.  fpa_$switch_owner_d2 (0x3C4266DA): D2 the new
 * owner.  Leaves A1 = FPA_$SAVEP.  When D2 is not the owner: FPA_$OWNER
 * = D2, the accelerator enabled (CPU control bit 1 cleared), the old
 * owner's state saved (fpa_$save_state, D0 = the old owner), then falls
 * into fpa_$restore_state for D2.  Clobbers D0-D3, A0, A2.
 * ------------------------------------------------------------------------- */
fpa_$switch_owner:
        move.w  (PROC1_$AS_ID).l,%d2            | 3c4266d4  3439 3c42 4aa2
fpa_$switch_owner_d2:
        move.w  (FPA_$OWNER:w,%pc),%d0          | 3c4266da  303a fcb6
        movea.l (FPA_$SAVEP:w,%pc),%a1          | 3c4266de  227a fcae
        cmp.w   %d0,%d2                         | 3c4266e2  b440
        beq.w   .Lrs_done                       | 3c4266e4  6700 0144  already the owner
        move.w  %d2,(FPA_$OWNER).l              | 3c4266e8  33c2 3c42 6392
        move.w  %sr,%d3                         | 3c4266ee  40c3
        ori.w   #0x700,%sr                      | 3c4266f0  007c 0700
        move.w  (MMU_$PID_PRIV).l,%d1           | 3c4266f4  3239 3c42 8ff4  the CPU control copy
        bclr    #1,%d1                          | 3c4266fa  0881 0001  the accelerator on
        move.w  %d1,(MMU_$PID_PRIV).l           | 3c4266fe  33c1 3c42 8ff4
        move.b  %d1,(MMU+0x101).l               | 3c426704  13c1 3fff b501  the CPU control register
        move.w  %d3,%sr                         | 3c42670a  46c3
        bsr.w   fpa_$save_state                 | 3c42670c  6100 011e

/* fpa_$restore_state - 0x3C426710: load the state of address space D2
   (A1 = FPA_$SAVEP): its saved one when its slot's flag word is 1, else
   a fresh one.  Address space 0 has none.  Clobbers D0, D2, A0, A2. */
fpa_$restore_state:
        subq.w  #1,%d2                          | 3c426710  5342
        blt.w   .Lrs_done                       | 3c426712  6d00 0116  address space 0
        mulu.w  #FPA_SAVE_AREA_SIZE,%d2         | 3c426716  c4fc 009c
        cmpi.w  #1,(0,%a1,%d2.l)                | 3c42671a  0c71 0001 2800  a state saved?
        beq.s   .Lrs_saved                      | 3c426720  676c
        addq.w  #1,(FPA_$DEBUG3).l              | 3c426722  5279 3c42 6646
        move.l  (FPA_CSR).l,%d0                 | 3c426728  2039 fff9 0000
        bclr    #31,%d0                         | 3c42672e  0880 001f
        move.l  %d0,(FPA_CSR).l                 | 3c426732  23c0 fff9 0000
        move.b  #0x48,(0xffff80cb).w            | 3c426738  11fc 0048 80cb  the WTK status bytes, fresh
        move.b  #0xc8,(0xffff80c3).w            | 3c42673e  11fc 00c8 80c3
        move.b  #0xff,(0xffff80d3).w            | 3c426744  11fc 00ff 80d3
        move.b  #0,(0xffff80db).w               | 3c42674a  11fc 0000 80db
        move.b  #0,(0xffff80c7).w               | 3c426750  11fc 0000 80c7
        move.b  #0,(0xffff80cf).w               | 3c426756  11fc 0000 80cf
        move.b  #0,(0xffff80d7).w               | 3c42675c  11fc 0000 80d7
        move.b  #0,(0xffff80df).w               | 3c426762  11fc 0000 80df
        move.b  #0,(0xffff80e3).w               | 3c426768  11fc 0000 80e3
        move.b  #0,(0xffff80eb).w               | 3c42676e  11fc 0000 80eb
        move.b  #0,(0xffff80f3).w               | 3c426774  11fc 0000 80f3
        move.b  #0,(0xffff80fb).w               | 3c42677a  11fc 0000 80fb
        move.l  #FPA_CSR_FRESH,(FPA_CSR).l      | 3c426780  23fc 83d0 0000 fff9 0000
        bra.w   .Lrs_done                       | 3c42678a  6000 009e
.Lrs_saved:
        lea     (2,%a1,%d2.l),%a0               | 3c42678e  41f1 2802  past the flag word
        addq.w  #1,(FPA_$DEBUG4).l              | 3c426792  5279 3c42 6648
        move.l  (FPA_CSR).l,%d0                 | 3c426798  2039 fff9 0000
        bclr    #31,%d0                         | 3c42679e  0880 001f
        move.l  %d0,(FPA_CSR).l                 | 3c4267a2  23c0 fff9 0000
        move.l  #0x3c00,%d0                     | 3c4267a8  203c 0000 3c00  register 15 first
.Lrs_reg:
        movea.l %d0,%a2                         | 3c4267ae  2440
        adda.l  #0xffff8014,%a2                 | 3c4267b0  d5fc ffff 8014
        move.l  (%a0)+,(%a2)                    | 3c4267b6  2498
        adda.l  #-8,%a2                         | 3c4267b8  d5fc ffff fff8
        move.l  (%a0)+,(%a2)                    | 3c4267be  2498
        .short  0x90bc, 0x0000, 0x0400          | 3c4267c0  90bc 0000 0400  sub.l #0x400,%d0
        .short  0xb0bc, 0x0000, 0x0000          | 3c4267c6  b0bc 0000 0000  cmp.l #0,%d0
        bge.s   .Lrs_reg                        | 3c4267cc  6ce0
        move.l  (0xffffbc14).w,%d0              | 3c4267ce  2038 bc14
        move.l  %d0,(0xffffbc18).w              | 3c4267d2  21c0 bc18
        move.b  (%a0)+,(0xffff804f).w           | 3c4267d6  11d8 804f
        move.b  (%a0)+,(0xffff8047).w           | 3c4267da  11d8 8047
        move.b  (%a0)+,(0xffff805b).w           | 3c4267de  11d8 805b
        move.b  (%a0)+,(0xffff8053).w           | 3c4267e2  11d8 8053
        move.b  (%a0)+,(0xffff804b).w           | 3c4267e6  11d8 804b
        move.b  (%a0)+,(0xffff8043).w           | 3c4267ea  11d8 8043
        move.b  (%a0)+,(0xffff80fb).w           | 3c4267ee  11d8 80fb  the WTK status bytes
        move.b  (%a0)+,(0xffff80f3).w           | 3c4267f2  11d8 80f3
        move.b  (%a0)+,(0xffff80eb).w           | 3c4267f6  11d8 80eb
        move.b  (%a0)+,(0xffff80e3).w           | 3c4267fa  11d8 80e3
        move.b  (%a0)+,(0xffff80df).w           | 3c4267fe  11d8 80df
        move.b  (%a0)+,(0xffff80d7).w           | 3c426802  11d8 80d7
        move.b  (%a0)+,(0xffff80cf).w           | 3c426806  11d8 80cf
        move.b  (%a0)+,(0xffff80c7).w           | 3c42680a  11d8 80c7
        move.b  (%a0)+,(0xffff80db).w           | 3c42680e  11d8 80db
        move.b  (%a0)+,(0xffff80d3).w           | 3c426812  11d8 80d3
        move.b  (%a0)+,(0xffff80cb).w           | 3c426816  11d8 80cb
        move.b  (%a0)+,(0xffff80c3).w           | 3c42681a  11d8 80c3
        move.l  (%a0)+,(FPA_EIR).l              | 3c42681e  23d8 fff8 0000
        move.l  (%a0)+,(FPA_CSR).l              | 3c426824  23d8 fff9 0000
.Lrs_done:
        rts                                     | 3c42682a  4e75

/* fpa_$save_state - 0x3C42682C: save the accelerator's state into the
   slot of address space D0 (A1 = FPA_$SAVEP), from the slot's end down,
   and set its flag word to 1.  Address space 0 has none.  Clobbers D0,
   A0, A2. */
fpa_$save_state:
        mulu.w  #FPA_SAVE_AREA_SIZE,%d0         | 3c42682c  c0fc 009c
        beq.w   .Lss_done                       | 3c426830  6700 009e  address space 0
        lea     (0,%a1,%d0.l),%a0               | 3c426834  41f1 0800  the slot's end
        addq.w  #1,(FPA_$DEBUG5).l              | 3c426838  5279 3c42 664a
        move.l  (FPA_CSR).l,%d0                 | 3c42683e  2039 fff9 0000
        move.l  %d0,-(%a0)                      | 3c426844  2100
        move.l  (FPA_EIR).l,-(%a0)              | 3c426846  2139 fff8 0000
        bclr    #31,%d0                         | 3c42684c  0880 001f
        move.l  %d0,(FPA_CSR).l                 | 3c426850  23c0 fff9 0000
        move.b  (0xffff8083).w,-(%a0)           | 3c426856  1138 8083  the WTK status bytes
        move.b  (0xffff808b).w,-(%a0)           | 3c42685a  1138 808b
        move.b  (0xffff8093).w,-(%a0)           | 3c42685e  1138 8093
        move.b  (0xffff809b).w,-(%a0)           | 3c426862  1138 809b
        move.b  (0xffff8087).w,-(%a0)           | 3c426866  1138 8087
        move.b  (0xffff808f).w,-(%a0)           | 3c42686a  1138 808f
        move.b  (0xffff8097).w,-(%a0)           | 3c42686e  1138 8097
        move.b  (0xffff809f).w,-(%a0)           | 3c426872  1138 809f
        move.b  (0xffff80a3).w,-(%a0)           | 3c426876  1138 80a3
        move.b  (0xffff80ab).w,-(%a0)           | 3c42687a  1138 80ab
        move.b  (0xffff80b3).w,-(%a0)           | 3c42687e  1138 80b3
        move.b  (0xffff80bb).w,-(%a0)           | 3c426882  1138 80bb
        move.b  (0xffff8043).w,-(%a0)           | 3c426886  1138 8043
        move.b  (0xffff804b).w,-(%a0)           | 3c42688a  1138 804b
        move.b  (0xffff8053).w,-(%a0)           | 3c42688e  1138 8053
        move.b  (0xffff805b).w,-(%a0)           | 3c426892  1138 805b
        move.b  (0xffff8047).w,-(%a0)           | 3c426896  1138 8047
        move.b  (0xffff804f).w,-(%a0)           | 3c42689a  1138 804f
        moveq   #0,%d0                          | 3c42689e  7000  register 0 first
.Lss_reg:
        movea.l %d0,%a2                         | 3c4268a0  2440
        adda.l  #0xffff8014,%a2                 | 3c4268a2  d5fc ffff 8014
        move.l  (%a2),-(%a0)                    | 3c4268a8  2112
        addq.l  #4,%a2                          | 3c4268aa  588a
        move.l  (%a2),-(%a0)                    | 3c4268ac  2112
        .short  0xd0bc, 0x0000, 0x0400          | 3c4268ae  d0bc 0000 0400  add.l #0x400,%d0
        .short  0xb0bc, 0x0000, 0x3c00          | 3c4268b4  b0bc 0000 3c00  cmp.l #0x3c00,%d0
        ble.s   .Lss_reg                        | 3c4268ba  6fe4
        move.w  #1,-(%a0)                       | 3c4268bc  313c 0001  the flag word: saved
        move.l  (FPA_CSR).l,%d0                 | 3c4268c0  2039 fff9 0000
        bset    #31,%d0                         | 3c4268c6  08c0 001f
        move.l  %d0,(FPA_CSR).l                 | 3c4268ca  23c0 fff9 0000
.Lss_done:
        rts                                     | 3c4268d0  4e75

/* -------------------------------------------------------------------------
 * fpa_$fp_init - 0x3C4268D2: FIM_$FP_INIT's arm (asid at 8(SP), its
 * caller's argument): if asid owns the accelerator, under its lock (and
 * re-checked there) ownership is dropped, FPA_$OWNER = 0 and the
 * accelerator disabled (CPU control bit 1 set); in all cases asid's slot
 * flag word is cleared, so its next state is a fresh one.
 * ------------------------------------------------------------------------- */
fpa_$fp_init:
        move.w  (0x8,%sp),%d1                   | 3c4268d2  322f 0008  asid
        cmp.w   (FPA_$OWNER:w,%pc),%d1          | 3c4268d6  b27a faba
        bne.s   .Lfi_clear                      | 3c4268da  664a
        pea     (fpa_$exclusion:w,%pc)          | 3c4268dc  487a fab6
        jsr     (ML_$EXCLUSION_START).l         | 3c4268e0  4eb9 3c42 529a
        addq.l  #4,%sp                          | 3c4268e6  588f
        move.w  (0x8,%sp),%d1                   | 3c4268e8  322f 0008
        cmp.w   (FPA_$OWNER:w,%pc),%d1          | 3c4268ec  b27a faa4  still the owner?
        bne.s   .Lfi_unlock                     | 3c4268f0  6624
        clr.w   (FPA_$OWNER).l                  | 3c4268f2  4279 3c42 6392
        move.w  %sr,%d0                         | 3c4268f8  40c0
        ori.w   #0x700,%sr                      | 3c4268fa  007c 0700
        move.w  (MMU_$PID_PRIV).l,%d1           | 3c4268fe  3239 3c42 8ff4  the CPU control copy
        bset    #1,%d1                          | 3c426904  08c1 0001  the accelerator off
        move.w  %d1,(MMU_$PID_PRIV).l           | 3c426908  33c1 3c42 8ff4
        move.b  %d1,(MMU+0x101).l               | 3c42690e  13c1 3fff b501  the CPU control register
        move.w  %d0,%sr                         | 3c426914  46c0
.Lfi_unlock:
        pea     (fpa_$exclusion:w,%pc)          | 3c426916  487a fa7c
        jsr     (ML_$EXCLUSION_STOP).l          | 3c42691a  4eb9 3c42 5320
        addq.l  #4,%sp                          | 3c426920  588f
        move.w  (0x8,%sp),%d1                   | 3c426922  322f 0008
.Lfi_clear:
        movea.l (FPA_$SAVEP:w,%pc),%a0          | 3c426926  207a fa66
        subq.w  #1,%d1                          | 3c42692a  5341
        mulu.w  #FPA_SAVE_AREA_SIZE,%d1         | 3c42692c  c2fc 009c
        clr.w   (0,%a0,%d1.l)                   | 3c426930  4270 1800  the slot's flag word
        rts                                     | 3c426934  4e75

/* -------------------------------------------------------------------------
 * fpa_$get_fp - 0x3C426936: FP_$GET_FP's arm (asid at 8(SP)): under the
 * accelerator's lock the current address space takes it (fpa_$check_owner)
 * and asid's state is loaded (fpa_$restore_state).
 * ------------------------------------------------------------------------- */
fpa_$get_fp:
        pea     (fpa_$exclusion:w,%pc)          | 3c426936  487a fa5c
        jsr     (ML_$EXCLUSION_START).l         | 3c42693a  4eb9 3c42 529a
        addq.l  #4,%sp                          | 3c426940  588f
        movem.l %d2/%a2,-(%sp)                  | 3c426942  48e7 2020
        bsr.s   fpa_$check_owner                | 3c426946  611a  sets A1 = FPA_$SAVEP
        move.w  (0x10,%sp),%d2                  | 3c426948  342f 0010  asid
        bsr.w   fpa_$restore_state              | 3c42694c  6100 fdc2
        movem.l (%sp)+,%d2/%a2                  | 3c426950  4cdf 0404
        pea     (fpa_$exclusion:w,%pc)          | 3c426954  487a fa3e
        jsr     (ML_$EXCLUSION_STOP).l          | 3c426958  4eb9 3c42 5320
        addq.l  #4,%sp                          | 3c42695e  588f
        rts                                     | 3c426960  4e75

/* fpa_$check_owner - 0x3C426962: fpa_$switch_owner without the restore:
   the current address space becomes the owner and the old owner's state
   is saved.  Always leaves A1 = FPA_$SAVEP. */
fpa_$check_owner:
        move.w  (PROC1_$AS_ID).l,%d2            | 3c426962  3439 3c42 4aa2
        move.w  (FPA_$OWNER:w,%pc),%d0          | 3c426968  303a fa28
        movea.l (FPA_$SAVEP:w,%pc),%a1          | 3c42696c  227a fa20
        cmp.w   %d0,%d2                         | 3c426970  b440
        beq.s   .Lco_done                       | 3c426972  6728
        move.w  %d2,(FPA_$OWNER).l              | 3c426974  33c2 3c42 6392
        move.w  %sr,%d2                         | 3c42697a  40c2
        ori.w   #0x700,%sr                      | 3c42697c  007c 0700
        move.w  (MMU_$PID_PRIV).l,%d1           | 3c426980  3239 3c42 8ff4  the CPU control copy
        bclr    #1,%d1                          | 3c426986  0881 0001  the accelerator on
        move.w  %d1,(MMU_$PID_PRIV).l           | 3c42698a  33c1 3c42 8ff4
        move.b  %d1,(MMU+0x101).l               | 3c426990  13c1 3fff b501  the CPU control register
        move.w  %d2,%sr                         | 3c426996  46c2
        bsr.w   fpa_$save_state                 | 3c426998  6100 fe92  D0 = the old owner
.Lco_done:
        rts                                     | 3c42699c  4e75

/* -------------------------------------------------------------------------
 * fpa_$put_fp - 0x3C42699E: FP_$PUT_FP's arm (asid at 8(SP)): under the
 * accelerator's lock the current address space takes it, its state
 * loaded (fpa_$switch_owner), then the live state is saved as asid's.
 * ------------------------------------------------------------------------- */
fpa_$put_fp:
        pea     (fpa_$exclusion:w,%pc)          | 3c42699e  487a f9f4
        jsr     (ML_$EXCLUSION_START).l         | 3c4269a2  4eb9 3c42 529a
        addq.l  #4,%sp                          | 3c4269a8  588f
        movem.l %d2-%d3/%a2,-(%sp)              | 3c4269aa  48e7 3020
        bsr.w   fpa_$switch_owner               | 3c4269ae  6100 fd24  leaves A1 = FPA_$SAVEP
        move.w  (0x14,%sp),%d0                  | 3c4269b2  302f 0014  asid
        bsr.w   fpa_$save_state                 | 3c4269b6  6100 fe74
        movem.l (%sp)+,%d2-%d3/%a2              | 3c4269ba  4cdf 040c
        pea     (fpa_$exclusion:w,%pc)          | 3c4269be  487a f9d4
        jsr     (ML_$EXCLUSION_STOP).l          | 3c4269c2  4eb9 3c42 5320
        addq.l  #4,%sp                          | 3c4269c8  588f
        rts                                     | 3c4269ca  4e75

        .endif
