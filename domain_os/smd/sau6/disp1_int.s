/*
 * smd/sau6/disp1_int.s - SMD_$DISP2_INT and SMD_$DISP1_INT, the display
 * units' BLT interrupt handlers, and the BLT setup subroutine they share
 * with the scroll bodies.
 *
 * Image addresses:
 *   sau6  0x7802A2DC  SMD_WIRED data segment (WIRED_DATA, 0x71C bytes)
 *   sau6  0x7802A2DC  SMD_$DISP2_INT
 *   sau6  0x7802A2F6  SMD_$DISP1_INT
 *   sau6  0x7802A3F8  SMD_Invalid_Direction_From_SM_Err
 *   sau6  0x7802A3FC  SMD_Invalid_BLT_In_Use_Err
 *   sau6  0x7802A400  SMD_Invalid_BLT_Done_Interrupt_Err
 *   sau6  0x7802A404  SMD_Invalid_Interrupt_Routine_State_Err
 *   sau6  0x7802A408  smd_$disp1_setup_blt
 *   sau6  0x7802A442  smd_$setup_scroll_blt
 *   sau6  0x7802A596  smd_$kolor_ctl_ptr
 *
 * The map names none of the routines and cells after SMD_$DISP1_INT;
 * the six names before the last are the SAU2 tree's for the same code
 * (smd/sau2/disp1_int.s).
 *
 * The first section of the SAU6's SMD_WIRED data segment, hand-written
 * code in a data section (smd/README.md).  SMD_$DISP2_INT is the
 * segment's first byte, and its address is the base the module's other
 * code works from: the trampolines load it into A0 and the bodies in
 * smd/sau6/wired_proc.s reach the segment's cells at fixed
 * displacements from it.  This section runs to SMD_$XOR_CURSOR
 * (smd/sau6/cursor_thunks.s).
 *
 * SMD_$INTERRUPT_INIT (smd/sau6/interrupt_init.s) installs the two
 * handlers as VME level 3's handlers.  VME_$INT calls a level-3 handler
 * with the vector, a longword by value, which they do not read.
 *
 * The SAU5's two handlers and body (smd/sau5/disp1_int.s) with the
 * SAU2's entry and exits (smd/sau2/disp1_int.s): each handler saves
 * D0-D1/A0-A1, raises the IPL to 6 and switches to the interrupt stack
 * (IO_$USE_INT_STACK), takes its unit's display record in A1
 * (SMD_$DISPLAY_COM for unit 1, the record after it for unit 2) and the
 * controller's registers in A0 (DISP1, the SAU6 map's 0x7FFFA400, and
 * DISP2, 0x7FFFA000), and goes to the shared body, the SAU2's state
 * machine on the display record's lock_state (+0x02) with the SAU2's
 * crashes.  It leaves through PROC1_$INT_EXIT, or with the lock
 * eventcount (+0x04) through PROC1_$INT_ADVANCE.
 *
 * The register block the setup subroutine fills is the SAU5's BLT
 * (offsets 0x80..0xB2, longword pairs), not the SAU2's: the direction
 * cases store the source and destination corners and the extents there,
 * and the control word's constant pair at +0x80/+0x84.
 */

        .section ".text.SMD_$DISP2_INT","ax",@progbits
        .globl  SMD_$DISP2_INT
        .globl  SMD_$DISP1_INT
        .globl  SMD_Invalid_Direction_From_SM_Err
        .globl  SMD_Invalid_BLT_In_Use_Err
        .globl  SMD_Invalid_BLT_Done_Interrupt_Err
        .globl  SMD_Invalid_Interrupt_Routine_State_Err
        .globl  smd_$setup_scroll_blt
        .globl  smd_$kolor_ctl_ptr

SMD_$DISP2_INT:
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        ori.w   #0x600,%sr              /* IPL 6 */
        jsr     (IO_$USE_INT_STACK).l
        lea     (SMD_$DISPLAY_COM+0x60:w,%pc),%a1  /* unit 2's record */
        lea     (DISP2).l,%a0
        bra.b   .Lcommon

SMD_$DISP1_INT:
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        ori.w   #0x600,%sr              /* IPL 6 */
        jsr     (IO_$USE_INT_STACK).l
        lea     (SMD_$DISPLAY_COM:w,%pc),%a1       /* unit 1's record */
        lea     (DISP1).l,%a0

.Lcommon:
        /* Not a BLT-done interrupt (status byte non-negative) */
        tst.b   (0x1,%a0)
        bge.w   .Lnot_blt_done
        tst.w   (0x2,%a0)               /* read to acknowledge */

        /* By lock_state */
        move.w  (0x2,%a1),%d0
        lsl.w   #2,%d0
        jmp     (.Ltable:b,%pc,%d0.w)

.Ltable:
        bra.w   .Lclear_run_bit         /* state 0 */
        bra.w   .Lclear_run_bit         /* state 1 */
        bra.w   .Lcount_only            /* state 2 */
        bra.w   .Lnext_step             /* state 3 */
        bra.w   .Lcount_only            /* state 4 */
        bra.w   .Lclear_run_bit         /* state 5 */
        bra.w   .Lbad_state             /* state 6 */
        bra.w   .Lint_advance           /* state 7 */

.Lint_exit:
        jmp     (PROC1_$INT_EXIT).l

/* States 0, 1 and 5: clear bit 5 of the video flags and, when the
   controller is no longer busy, write them back. */
.Lclear_run_bit:
        move.w  (0x22,%a1),%d0
        .short  0xc07c, 0xffdf          /* and.w #0xffdf,%d0 */
        move.w  %d0,(0x22,%a1)
        tst.w   (%a0)
        bmi.b   .Lint_exit
        move.w  %d0,(%a0)
        bra.b   .Lint_exit

/* State 3: set up the next scroll step and start it; state 2. */
.Lnext_step:
        move.l  %d1,-(%sp)
        jsr     (smd_$disp1_setup_blt:w,%pc)
        move.l  (%sp)+,%d1
        move.w  #0x8010,%d0
        or.w    (0x22,%a1),%d0
        move.w  %d0,(%a0)               /* start the BLT */
        move.w  #0x2,(0x2,%a1)
        bra.b   .Lint_exit

/* States 2 and 4: count the interrupt. */
.Lcount_only:
        addq.w  #1,(0x24,%a1)
        bra.b   .Lint_exit

/* Not a BLT-done interrupt: a busy controller here is a crash. */
.Lnot_blt_done:
        tst.w   (%a0)
        bge.b   .Lcheck_state
        pea     (SMD_Invalid_BLT_Done_Interrupt_Err:w,%pc)
        jsr     (CRASH_SYSTEM).l
.Lcheck_state:
        move.w  (0x2,%a1),%d0
        .short  0xb07c, 0x0002          /* cmp.w #2,%d0 */
        beq.w   .Lstate2
        .short  0xb07c, 0x0001          /* cmp.w #1,%d0 */
        beq.b   .Lstate1

/* Any other state here, and the table's state 6. */
.Lbad_state:
        pea     (SMD_Invalid_Interrupt_Routine_State_Err:w,%pc)
        jsr     (CRASH_SYSTEM).l

/* State 1: the operation is done.  The video flags back, state 0, the
   operation eventcount (+0x10) advanced. */
.Lstate1:
        move.w  (0x22,%a1),(%a0)
        move.w  #0x0,(0x2,%a1)
        move.l  %a1,-(%sp)
        pea     (0x10,%a1)
        jsr     (ADVANCE).l
        addq.w  #4,%sp
        movea.l (%sp)+,%a1

/* The table's state 7, and the common end: advance the lock eventcount
   (+0x04), A0 its address for PROC1_$INT_ADVANCE. */
.Lint_advance:
        lea     (0x4,%a1),%a0
        jmp     (PROC1_$INT_ADVANCE).l

/* State 2: a scroll step is done. */
.Lstate2:
        tst.w   (0x2e,%a1)              /* steps left */
        bgt.b   .Lstate2_more
        andi.w  #0xffdf,(0x22,%a1)
        move.w  (0x22,%a1),(%a0)
        move.w  #0x0,(0x2,%a1)
        bra.b   .Lint_advance
.Lstate2_more:
        move.w  (0x22,%a1),(%a0)
        move.w  #0x3,(0x2,%a1)
        tst.b   (0x20,%a1)
        bge.w   .Lint_exit
        bra.b   .Lint_advance

/* The status codes this module crashes with. */
SMD_Invalid_Direction_From_SM_Err:
        .long   0x00130007
SMD_Invalid_BLT_In_Use_Err:
        .long   0x00130008
SMD_Invalid_BLT_Done_Interrupt_Err:
        .long   0x0013001c
SMD_Invalid_Interrupt_Routine_State_Err:
        .long   0x0013001d

/*
 * smd_$disp1_setup_blt and smd_$setup_scroll_blt: two entries of one
 * routine, set up the next step of a scroll in the BLT registers.
 * Entry: A0 the BLT registers, A1 the display record.  A busy BLT
 * (bit 15) is a crash.  Two lines are taken off the steps left (+0x2E);
 * D1 is 2 while more remain, 1 for the last step (and +0x24 cleared).
 * On the last step the operation eventcount (+0x10) is advanced: by the
 * interrupt-level entry with ADVANCE at IPL 7 (the SR saved and put
 * back), by the base-level entry with EC_$ADVANCE.  Then by the
 * direction (+0x30) the BLT's corners and extents from the scroll window
 * (+0x26..+0x2C) and D1.  D0 is not a result.
 */
smd_$disp1_setup_blt:
        tst.w   (%a0)
        bmi.w   .Lblt_in_use
        subq.w  #2,(0x2e,%a1)
        blt.b   .Llast_step_i
        moveq   #2,%d1
        bra.b   .Lcheck_steps_i
.Llast_step_i:
        moveq   #1,%d1
        clr.w   (0x24,%a1)
.Lcheck_steps_i:
        tst.w   (0x2e,%a1)
        bgt.b   .Lsetup_common
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        move.w  %sr,-(%sp)
        ori.w   #0x700,%sr
        pea     (0x10,%a1)
        jsr     (ADVANCE).l
        addq.w  #4,%sp
        move.w  (%sp)+,%sr
        movem.l (%sp)+,%d0-%d1/%a0-%a1
        bra.b   .Lsetup_common

smd_$setup_scroll_blt:
        tst.w   (%a0)
        bmi.w   .Lblt_in_use
        subq.w  #2,(0x2e,%a1)
        blt.b   .Llast_step_b
        moveq   #2,%d1
        bra.b   .Lcheck_steps_b
.Llast_step_b:
        moveq   #1,%d1
        clr.w   (0x24,%a1)
.Lcheck_steps_b:
        tst.w   (0x2e,%a1)
        bgt.b   .Lsetup_common
        movem.l %d0-%d1/%a0-%a1,-(%sp)
        pea     (0x10,%a1)
        jsr     (EC_$ADVANCE).l
        addq.w  #4,%sp
        movem.l (%sp)+,%d0-%d1/%a0-%a1

.Lsetup_common:
        move.w  (0x30,%a1),%d0
        .short  0xb07c, 0x0000          /* cmp.w #0,%d0 */
        beq.b   .Ldir0
        .short  0xb07c, 0x0001          /* cmp.w #1,%d0 */
        beq.b   .Ldir1
        .short  0xb07c, 0x0002          /* cmp.w #2,%d0 */
        beq.w   .Ldir2
        .short  0xb07c, 0x0003          /* cmp.w #3,%d0 */
        beq.w   .Ldir3
        pea     (SMD_Invalid_Direction_From_SM_Err:w,%pc)
        jsr     (CRASH_SYSTEM).l

/* Direction 0 */
.Ldir0:
        move.l  #0x02020020,%d0
        move.l  %d0,(0x84,%a0)
        move.l  %d0,(0x80,%a0)
        move.w  (0x26,%a1),%d0
        move.w  %d0,(0xae,%a0)
        move.w  %d0,(0xaa,%a0)
        move.w  (0x28,%a1),%d0
        move.w  %d0,(0xb2,%a0)
        move.w  (0x2a,%a1),%d0
        move.w  %d0,(0xa8,%a0)
        add.w   %d1,%d0
        move.w  %d0,(0xac,%a0)
        move.w  (0x2c,%a1),%d0
        sub.w   %d1,%d0
        move.w  %d0,(0xb0,%a0)
        rts

/* Direction 1 */
.Ldir1:
        move.l  #0x06060020,%d0
        move.l  %d0,(0x84,%a0)
        move.l  %d0,(0x80,%a0)
        move.w  (0x26,%a1),%d0
        move.w  %d0,(0xae,%a0)
        move.w  %d0,(0xaa,%a0)
        move.w  (0x28,%a1),%d0
        move.w  %d0,(0xb2,%a0)
        move.w  (0x2a,%a1),%d0
        add.w   %d1,%d0
        move.w  %d0,(0xb0,%a0)
        move.w  (0x2c,%a1),%d0
        move.w  %d0,(0xa8,%a0)
        sub.w   %d1,%d0
        move.w  %d0,(0xac,%a0)
        rts

/* Direction 2 */
.Ldir2:
        move.l  #0x02020020,%d0
        move.l  %d0,(0x84,%a0)
        move.l  %d0,(0x80,%a0)
        move.w  (0x26,%a1),%d0
        move.w  %d0,(0xaa,%a0)
        add.w   %d1,%d0
        move.w  %d0,(0xae,%a0)
        move.w  (0x28,%a1),%d0
        sub.w   %d1,%d0
        move.w  %d0,(0xb2,%a0)
        move.w  (0x2a,%a1),%d0
        move.w  %d0,(0xa8,%a0)
        move.w  %d0,(0xac,%a0)
        move.w  (0x2c,%a1),(0xb0,%a0)
        rts

/* Direction 3 */
.Ldir3:
        move.l  #0x02020020,%d0
        move.l  %d0,(0x84,%a0)
        move.l  %d0,(0x80,%a0)
        move.w  (0x26,%a1),%d0
        move.w  %d0,(0xae,%a0)
        add.w   %d1,%d0
        move.w  %d0,(0xaa,%a0)
        move.w  (0x28,%a1),(0xb2,%a0)
        move.w  (0x2a,%a1),%d0
        move.w  %d0,(0xa8,%a0)
        move.w  %d0,(0xac,%a0)
        move.w  (0x2c,%a1),(0xb0,%a0)
        rts

/* A busy BLT: a crash (CRASH_SYSTEM does not return; the loop is the
   original's). */
.Lblt_in_use:
        pea     (SMD_Invalid_BLT_In_Use_Err:w,%pc)
        jsr     (CRASH_SYSTEM).l
        addq.w  #4,%sp
        bra.b   .Lblt_in_use

/* The address of the base-level EC_$ADVANCE; nothing reads it, as on
   the SAU2. */
        .long   EC_$ADVANCE

/* KOLOR_CTL, the DN570/DN580 board's registers, for the blink routines
   (PC-relative) and the cursor body (+0x2BA from the base). */
smd_$kolor_ctl_ptr:
        .long   KOLOR_CTL
