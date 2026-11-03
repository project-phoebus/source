/*
 * smd/sau4/disp1_int.s - SMD_$DISP2_INT and SMD_$DISP1_INT, the display
 * units' BLT interrupt handlers, and the BLT setup subroutine they share
 * with the scroll bodies.
 *
 * Image addresses:
 *   sau4  0x0F8293BC  SMD_WIRED data segment (WIRED_DATA, 0x7C0 bytes)
 *   sau4  0x0F8293BC  SMD_$DISP2_INT
 *   sau4  0x0F8293D6  SMD_$DISP1_INT
 *   sau4  0x0F8294E4  SMD_Invalid_Direction_From_SM_Err
 *   sau4  0x0F8294E8  SMD_Invalid_BLT_In_Use_Err
 *   sau4  0x0F8294EC  SMD_Invalid_BLT_Done_Interrupt_Err
 *   sau4  0x0F8294F0  SMD_Invalid_Interrupt_Routine_State_Err
 *   sau4  0x0F8294F4  smd_$disp1_setup_blt
 *   sau4  0x0F82952E  smd_$setup_scroll_blt
 *
 * The map names none of the routines and cells after SMD_$DISP1_INT;
 * the names are the SAU2 and SAU5 trees' for the same code.
 *
 * The first section of the SAU4's SMD_WIRED data segment, hand-written
 * code in a data section (smd/README.md).  SMD_$DISP2_INT is the
 * segment's first byte, and its address is the base the module's other
 * code works from (smd/sau4/wired_proc.s).  This section runs to
 * SMD_$XOR_CURSOR (smd/sau4/cursor_thunks.s).
 *
 * SMD_$INTERRUPT_INIT (smd/sau4/interrupt_init.s) puts the two handlers
 * in their vectors, DISP1_VEC and DISP2_VEC.  Each saves D0-D1/A0-A1,
 * raises the IPL to 6, switches to the interrupt stack
 * (IO_$USE_INT_STACK), takes its unit's display record in A1
 * (SMD_$DISPLAY_COM for unit 1, the record 0xE0 bytes after it for unit
 * 2) and its controller's registers in A0 (DISP1, DISP2), and goes to the
 * shared body: the SAU2's state machine on the display record's
 * lock_state (+0x02), left through PROC1_$INT_EXIT and PROC1_$INT_ADVANCE
 * (the lock eventcount, +0x04), with one difference: when state 1 ends
 * with main-memory pages wired (mm_page_count, +0xDE, positive) the
 * state becomes 6, which SMD_$ACQ_DISPLAY clears after unwiring them.
 *
 * The setup subroutine fills the BLT's registers at 0x80..0xB2 (longword
 * pairs, as the SAU5's): the control word's constant pair at +0x80/+0x84
 * and, by the scroll's direction (+0x30), the corners and extents from
 * the scroll window (+0x26..+0x2C).
 *
 * Checked by assembly: `m68k-elf-as -m68010', linked with the SMD_WIRED
 * files at their map addresses and the SAU4 map's addresses for the
 * other symbols; every byte is the SAU4 image's.  The address and byte
 * columns are the SAU4 image's.  The CMP, AND, OR and ADD with an
 * immediate source and a data register destination in the Apollo
 * assembler's <ea>=#imm form (gas emits CMPI, ANDI, ORI and ADDI, the same
 * length), the MOVE.L of a small immediate (gas emits MOVEQ) and the
 * ADD.L #imm to a data register (gas emits ADDQ or ADDI) are `.short'
 * words, the instruction in the comment.
 */

        .globl  SMD_$DISP2_INT
        .globl  SMD_$DISP1_INT
        .globl  SMD_Invalid_Direction_From_SM_Err
        .globl  SMD_Invalid_BLT_In_Use_Err
        .globl  SMD_Invalid_BLT_Done_Interrupt_Err
        .globl  SMD_Invalid_Interrupt_Routine_State_Err
        .globl  smd_$setup_scroll_blt

        .section ".text.SMD_$DISP2_INT","ax",@progbits
SMD_$DISP2_INT:
        moveml %d0-%d1/%a0-%a1,%sp@-             | f8293bc  48e7 c0c0
        oriw #0x600,%sr                          | f8293c0  007c 0600
        jsr IO_$USE_INT_STACK                    | f8293c4  4eb9 0f83 1c26
        lea %pc@(SMD_$DISPLAY_COM+0xe0),%a1      | f8293ca  43fa 05a8
        lea DISP2,%a0                            | f8293ce  41f9 0fff 9400
        bras .Lf8293ee                           | f8293d4  6018
SMD_$DISP1_INT:
        moveml %d0-%d1/%a0-%a1,%sp@-             | f8293d6  48e7 c0c0
        oriw #0x600,%sr                          | f8293da  007c 0600
        jsr IO_$USE_INT_STACK                    | f8293de  4eb9 0f83 1c26
        lea %pc@(SMD_$DISPLAY_COM),%a1           | f8293e4  43fa 04ae
        lea DISP1,%a0                            | f8293e8  41f9 0fff 9800

/* The common body: not a BLT-done interrupt (status byte non-negative),
   else the state's arm (the status word read to acknowledge). */
.Lf8293ee:
        tstb %a0@(1)                             | f8293ee  4a28 0001
        bgew .Lf82945e                           | f8293f2  6c00 006a
        tstw %a0@(2)                             | f8293f6  4a68 0002
        movew %a1@(2),%d0                        | f8293fa  3029 0002
        lslw #2,%d0                              | f8293fe  e548
        jmp %pc@(.Lf829404,%d0:w)                | f829400  4efb 0002
.Lf829404:
        braw .Lf82942a                           | f829404  6000 0024
        braw .Lf82942a                           | f829408  6000 0020
        braw .Lf829458                           | f82940c  6000 004a
        braw .Lf82943e                           | f829410  6000 002c
        braw .Lf829458                           | f829414  6000 0042
        braw .Lf82942a                           | f829418  6000 0010
        braw .Lf82947e                           | f82941c  6000 0060
        braw .Lf8294ae                           | f829420  6000 008c
.Lf829424:
        jmp PROC1_$INT_EXIT                      | f829424  4ef9 0f82 1f0e

/* States 0, 1 and 5: the run bit (5) of the video flags cleared, and
   written back when the controller is not busy. */
.Lf82942a:
        movew %a1@(0x22),%d0                     | f82942a  3029 0022
        .short  0xc07c, 0xffdf | f82942e  andw #-33,%d0
        movew %d0,%a1@(0x22)                     | f829432  3340 0022
        tstw %a0@                                | f829436  4a50
        bmis .Lf829424                           | f829438  6bea
        movew %d0,%a0@                           | f82943a  3080
        bras .Lf829424                           | f82943c  60e6

/* State 3: the next scroll step set up and started; state 2. */
.Lf82943e:
        movel %d1,%sp@-                          | f82943e  2f01
        jsr %pc@(smd_$disp1_setup_blt)           | f829440  4eba 00b2
        movel %sp@+,%d1                          | f829444  221f
        movew #-0x7ff0,%d0                       | f829446  303c 8010
        orw %a1@(0x22),%d0                       | f82944a  8069 0022
        movew %d0,%a0@                           | f82944e  3080
        movew #2,%a1@(2)                         | f829450  337c 0002 0002
        bras .Lf829424                           | f829456  60cc

/* States 2 and 4: the interrupt counted. */
.Lf829458:
        addqw #1,%a1@(0x24)                      | f829458  5269 0024
        bras .Lf829424                           | f82945c  60c6

/* Not a BLT-done interrupt: a busy controller is a crash; state 2 or 1
   go on, any other state is a crash. */
.Lf82945e:
        tstw %a0@                                | f82945e  4a50
        bges .Lf82946c                           | f829460  6c0a
        pea %pc@(SMD_Invalid_BLT_Done_Interrupt_Err) | f829462  487a 0088
        jsr CRASH_SYSTEM                         | f829466  4eb9 0f81 faf8
.Lf82946c:
        movew %a1@(2),%d0                        | f82946c  3029 0002
        .short  0xb07c, 0x0002 | f829470  cmpw #2,%d0
        beqw .Lf8294b8                           | f829474  6700 0042
        .short  0xb07c, 0x0001 | f829478  cmpw #1,%d0
        beqs .Lf829488                           | f82947c  670a
.Lf82947e:
        pea %pc@(SMD_Invalid_Interrupt_Routine_State_Err) | f82947e  487a 0070
        jsr CRASH_SYSTEM                         | f829482  4eb9 0f81 faf8

/* State 1: the operation is done.  The video flags back, state 0 (6
   when main-memory pages are wired), the operation eventcount
   advanced. */
.Lf829488:
        movew %a1@(0x22),%a0@                    | f829488  30a9 0022
        movew #0,%a1@(2)                         | f82948c  337c 0000 0002
        tstw %a1@(0xde)                          | f829492  4a69 00de
        bles .Lf82949e                           | f829496  6f06
        movew #6,%a1@(2)                         | f829498  337c 0006 0002
.Lf82949e:
        movel %a1,%sp@-                          | f82949e  2f09
        pea %a1@(0x10)                           | f8294a0  4869 0010
        jsr ADVANCE                              | f8294a4  4eb9 0f82 1d38
        addqw #4,%sp                             | f8294aa  584f
        moveal %sp@+,%a1                         | f8294ac  225f

/* The table's state 7, and the common end: advance the lock eventcount
   and leave the interrupt. */
.Lf8294ae:
        lea %a1@(4),%a0                          | f8294ae  41e9 0004
        jmp PROC1_$INT_ADVANCE                   | f8294b2  4ef9 0f82 1f06

/* State 2: a scroll step is done; state 3 while steps remain. */
.Lf8294b8:
        tstw %a1@(0x2e)                          | f8294b8  4a69 002e
        bgts .Lf8294d0                           | f8294bc  6e12
        andiw #-0x21,%a1@(0x22)                  | f8294be  0269 ffdf 0022
        movew %a1@(0x22),%a0@                    | f8294c4  30a9 0022
        movew #0,%a1@(2)                         | f8294c8  337c 0000 0002
        bras .Lf8294ae                           | f8294ce  60de
.Lf8294d0:
        movew %a1@(0x22),%a0@                    | f8294d0  30a9 0022
        movew #3,%a1@(2)                         | f8294d4  337c 0003 0002
        tstb %a1@(0x20)                          | f8294da  4a29 0020
        bgew .Lf829424                           | f8294de  6c00 ff44
        bras .Lf8294ae                           | f8294e2  60ca

/* The status codes this module crashes with. */
SMD_Invalid_Direction_From_SM_Err:
        .long   0x00130007               | f8294e4
SMD_Invalid_BLT_In_Use_Err:
        .long   0x00130008               | f8294e8
SMD_Invalid_BLT_Done_Interrupt_Err:
        .long   0x0013001c               | f8294ec
SMD_Invalid_Interrupt_Routine_State_Err:
        .long   0x0013001d               | f8294f0

/* smd_$disp1_setup_blt (interrupt level) and smd_$setup_scroll_blt
   (base level): set up the next step of a scroll.  A0 the BLT
   registers, A1 the display record.  Two lines off the steps left
   (+0x2E); D1 2 while more remain, 1 for the last (+0x24 cleared), when
   the operation eventcount (+0x10) is advanced (ADVANCE at IPL 7, or
   EC_$ADVANCE).  Then the direction's corners and extents. */
smd_$disp1_setup_blt:
        tstw %a0@                                | f8294f4  4a50
        bmiw .Lf829670                           | f8294f6  6b00 0178
        subqw #2,%a1@(0x2e)                      | f8294fa  5569 002e
        blts .Lf829504                           | f8294fe  6d04
        moveq #2,%d1                             | f829500  7202
        bras .Lf82950a                           | f829502  6006
.Lf829504:
        moveq #1,%d1                             | f829504  7201
        clrw %a1@(0x24)                          | f829506  4269 0024
.Lf82950a:
        tstw %a1@(0x2e)                          | f82950a  4a69 002e
        bgts .Lf82955e                           | f82950e  6e4e
        moveml %d0-%d1/%a0-%a1,%sp@-             | f829510  48e7 c0c0
        movew %sr,%sp@-                          | f829514  40e7
        oriw #0x700,%sr                          | f829516  007c 0700
        pea %a1@(0x10)                           | f82951a  4869 0010
        jsr ADVANCE                              | f82951e  4eb9 0f82 1d38
        addqw #4,%sp                             | f829524  584f
        movew %sp@+,%sr                          | f829526  46df
        moveml %sp@+,%d0-%d1/%a0-%a1             | f829528  4cdf 0303
        bras .Lf82955e                           | f82952c  6030
smd_$setup_scroll_blt:
        tstw %a0@                                | f82952e  4a50
        bmiw .Lf829670                           | f829530  6b00 013e
        subqw #2,%a1@(0x2e)                      | f829534  5569 002e
        blts .Lf82953e                           | f829538  6d04
        moveq #2,%d1                             | f82953a  7202
        bras .Lf829544                           | f82953c  6006
.Lf82953e:
        moveq #1,%d1                             | f82953e  7201
        clrw %a1@(0x24)                          | f829540  4269 0024
.Lf829544:
        tstw %a1@(0x2e)                          | f829544  4a69 002e
        bgts .Lf82955e                           | f829548  6e14
        moveml %d0-%d1/%a0-%a1,%sp@-             | f82954a  48e7 c0c0
        pea %a1@(0x10)                           | f82954e  4869 0010
        jsr EC_$ADVANCE                          | f829552  4eb9 0f82 1cfe
        addqw #4,%sp                             | f829558  584f
        moveml %sp@+,%d0-%d1/%a0-%a1             | f82955a  4cdf 0303
.Lf82955e:
        movew %a1@(0x30),%d0                     | f82955e  3029 0030
        .short  0xb07c, 0x0000 | f829562  cmpw #0,%d0
        beqs .Lf829588                           | f829566  6720
        .short  0xb07c, 0x0001 | f829568  cmpw #1,%d0
        beqs .Lf8295c4                           | f82956c  6756
        .short  0xb07c, 0x0002 | f82956e  cmpw #2,%d0
        beqw .Lf829600                           | f829572  6700 008c
        .short  0xb07c, 0x0003 | f829576  cmpw #3,%d0
        beqw .Lf82963a                           | f82957a  6700 00be
        pea %pc@(SMD_Invalid_Direction_From_SM_Err) | f82957e  487a ff64
        jsr CRASH_SYSTEM                         | f829582  4eb9 0f81 faf8

/* Direction 0 */
.Lf829588:
        movel #0x2020020,%d0                     | f829588  203c 0202 0020
        movel %d0,%a0@(0x84)                     | f82958e  2140 0084
        movel %d0,%a0@(0x80)                     | f829592  2140 0080
        movew %a1@(0x26),%d0                     | f829596  3029 0026
        movew %d0,%a0@(0xae)                     | f82959a  3140 00ae
        movew %d0,%a0@(0xaa)                     | f82959e  3140 00aa
        movew %a1@(0x28),%d0                     | f8295a2  3029 0028
        movew %d0,%a0@(0xb2)                     | f8295a6  3140 00b2
        movew %a1@(0x2a),%d0                     | f8295aa  3029 002a
        movew %d0,%a0@(0xa8)                     | f8295ae  3140 00a8
        addw %d1,%d0                             | f8295b2  d041
        movew %d0,%a0@(0xac)                     | f8295b4  3140 00ac
        movew %a1@(0x2c),%d0                     | f8295b8  3029 002c
        subw %d1,%d0                             | f8295bc  9041
        movew %d0,%a0@(0xb0)                     | f8295be  3140 00b0
        rts                                      | f8295c2  4e75

/* Direction 1 */
.Lf8295c4:
        movel #0x6060020,%d0                     | f8295c4  203c 0606 0020
        movel %d0,%a0@(0x84)                     | f8295ca  2140 0084
        movel %d0,%a0@(0x80)                     | f8295ce  2140 0080
        movew %a1@(0x26),%d0                     | f8295d2  3029 0026
        movew %d0,%a0@(0xae)                     | f8295d6  3140 00ae
        movew %d0,%a0@(0xaa)                     | f8295da  3140 00aa
        movew %a1@(0x28),%d0                     | f8295de  3029 0028
        movew %d0,%a0@(0xb2)                     | f8295e2  3140 00b2
        movew %a1@(0x2a),%d0                     | f8295e6  3029 002a
        addw %d1,%d0                             | f8295ea  d041
        movew %d0,%a0@(0xb0)                     | f8295ec  3140 00b0
        movew %a1@(0x2c),%d0                     | f8295f0  3029 002c
        movew %d0,%a0@(0xa8)                     | f8295f4  3140 00a8
        subw %d1,%d0                             | f8295f8  9041
        movew %d0,%a0@(0xac)                     | f8295fa  3140 00ac
        rts                                      | f8295fe  4e75

/* Direction 2 */
.Lf829600:
        movel #0x2020020,%d0                     | f829600  203c 0202 0020
        movel %d0,%a0@(0x84)                     | f829606  2140 0084
        movel %d0,%a0@(0x80)                     | f82960a  2140 0080
        movew %a1@(0x26),%d0                     | f82960e  3029 0026
        movew %d0,%a0@(0xaa)                     | f829612  3140 00aa
        addw %d1,%d0                             | f829616  d041
        movew %d0,%a0@(0xae)                     | f829618  3140 00ae
        movew %a1@(0x28),%d0                     | f82961c  3029 0028
        subw %d1,%d0                             | f829620  9041
        movew %d0,%a0@(0xb2)                     | f829622  3140 00b2
        movew %a1@(0x2a),%d0                     | f829626  3029 002a
        movew %d0,%a0@(0xa8)                     | f82962a  3140 00a8
        movew %d0,%a0@(0xac)                     | f82962e  3140 00ac
        movew %a1@(0x2c),%a0@(0xb0)              | f829632  3169 002c 00b0
        rts                                      | f829638  4e75

/* Direction 3 */
.Lf82963a:
        movel #0x2020020,%d0                     | f82963a  203c 0202 0020
        movel %d0,%a0@(0x84)                     | f829640  2140 0084
        movel %d0,%a0@(0x80)                     | f829644  2140 0080
        movew %a1@(0x26),%d0                     | f829648  3029 0026
        movew %d0,%a0@(0xae)                     | f82964c  3140 00ae
        addw %d1,%d0                             | f829650  d041
        movew %d0,%a0@(0xaa)                     | f829652  3140 00aa
        movew %a1@(0x28),%a0@(0xb2)              | f829656  3169 0028 00b2
        movew %a1@(0x2a),%d0                     | f82965c  3029 002a
        movew %d0,%a0@(0xa8)                     | f829660  3140 00a8
        movew %d0,%a0@(0xac)                     | f829664  3140 00ac
        movew %a1@(0x2c),%a0@(0xb0)              | f829668  3169 002c 00b0
        rts                                      | f82966e  4e75

/* A busy BLT: a crash. */
.Lf829670:
        pea %pc@(SMD_Invalid_BLT_In_Use_Err)     | f829670  487a fe76
        jsr CRASH_SYSTEM                         | f829674  4eb9 0f81 faf8
        addqw #4,%sp                             | f82967a  584f
        bras .Lf829670                           | f82967c  60f2

/* The address of EC_$ADVANCE; nothing reads it, as on the SAU5. */
        .long   EC_$ADVANCE              | f82967e
