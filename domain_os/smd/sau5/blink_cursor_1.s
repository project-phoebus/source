/*
 * smd/sau5/blink_cursor_1.s - SMD_$BLINK_CURSOR_1, SMD_$BLINK_CURSOR_2
 * and SMD_$BLINK_CURSOR, the cursor blink routines.
 *
 * Image addresses:
 *   sau5  0x00E280C2  SMD_$BLINK_CURSOR_1
 *   sau5  0x00E28176  SMD_$BLINK_CURSOR_2
 *   sau5  0x00E28200  SMD_$BLINK_CURSOR
 *
 * Hand-written code in SMD_WIRED's data segment, no frame.  Each blink
 * routine saves the caller's SR under the saved registers and puts it
 * back at the exit (only unit 1's monochrome case raises the IPL, to 7),
 * and toggles its unit's cursor: when the display is in a state to take
 * it, it calls SMD_$XOR_CURSOR (smd/sau5/cursor_thunks.s) with the
 * unit's display record and then inverts SMD_TIME_$COM's cursor_painted
 * byte (+2), as the SAU2's SMD_$BLINK_CURSOR_1.  SMD_$BLINK_CURSOR_CALLBACK
 * reaches them through the SMD block's table (smd/smd_internal.ins.pas);
 * nothing pushed, nothing returned.
 *
 * Unit 1 (SMD_$DISPLAY_COM), by its display type:
 *   - 5 (the DN580): when the board's status (KOLOR_CTL + 0x700E) has
 *     2 in bits 1..2 and bit 14 set, and the unit is not locked
 *     (lock_state zero), with KOLOR_CTL and DISP_MEM_2KX1K;
 *   - 6 (the DN570): when the unit is not locked, with KOLOR_CTL and
 *     DISP1_MEM;
 *   - any other: at IPL 7, when DISP1's status word is non-negative,
 *     with DISP1 and DISP1_MEM (the SAU2's case).
 *
 * Unit 2 (the record after SMD_$DISPLAY_COM), by its display type:
 *   - 3 or 4 (the DN6xx and DN550/560 controllers): when COLOR_SUP's
 *     status (+2) has bit 4 set and bit 5 clear, the unit is not locked
 *     and COLOR_SUP's byte at +0xA1 is zero, with COLOR_SUP and
 *     DISP2_MEM;
 *   - any other: when DISP2's status word is non-negative, with DISP2
 *     and DISP2_MEM.
 * Unit 1's three cases join unit 2's code for the call and the exit.
 *
 * SMD_$XOR_CURSOR's seven arguments, pushed right to left (the caller
 * cleans up): the controller's registers and the display memory base,
 * by value; then &cursor_painted, the display record, &disp_limits
 * (+0x4E), &cursor_pos (+0x32), &cursor_number (+0x36).
 *
 * SMD_$BLINK_CURSOR: with the longword argument (0x4,SP) equal to
 * DISP2's address, SMD_$BLINK_CURSOR_2, else SMD_$BLINK_CURSOR_1.
 * Nothing in the image calls it.
 *
 * A5 is loaded with the segment's base (twice on unit 1's paths); the
 * DN570 case loads A3.
 */

        .section ".text.SMD_$BLINK_CURSOR_1","ax",@progbits
        .globl  SMD_$BLINK_CURSOR_1
        .globl  SMD_$BLINK_CURSOR_2
        .globl  SMD_$BLINK_CURSOR

SMD_$BLINK_CURSOR_1:
        movem.l %d2/%a2-%a3/%a5,-(%sp)
        lea     (SMD_$DISP2_INT:w,%pc),%a5
        move.w  %sr,-(%sp)
        lea     (SMD_$DISPLAY_COM:w,%pc),%a0
        cmpi.w  #0x5,(%a0)
        beq.w   .L1_dn580
        cmpi.w  #0x6,(%a0)
        bne.b   .L1_mono

/* Unit 1, the DN570 */
        lea     (SMD_$DISP2_INT:w,%pc),%a5
        lea     (SMD_TIME_$COM+2:w,%pc),%a1
        lea     (SMD_$DISPLAY_COM:w,%pc),%a0
        movea.l (smd_$kolor_ctl_ptr:w,%pc),%a3
        cmpi.w  #0x0,(0x2,%a0)          /* locked */
        bne.w   .Ldone
        move.l  #KOLOR_CTL,-(%sp)
        move.l  #DISP1_MEM,-(%sp)
        bra.w   .Lcall

/* Unit 1, the DN580 */
.L1_dn580:
        lea     (SMD_$DISP2_INT:w,%pc),%a5
        lea     (SMD_TIME_$COM+2:w,%pc),%a1
        lea     (SMD_$DISPLAY_COM:w,%pc),%a0
        movea.l (smd_$kolor_ctl_ptr:w,%pc),%a3
        move.w  (0x700e,%a3),%d2
        .short  0xc47c, 0x0006          /* and.w #6,%d2 */
        .short  0xb47c, 0x0002          /* cmp.w #2,%d2 */
        bne.w   .Ldone
        move.w  (0x700e,%a3),%d2
        .short  0xc47c, 0x4000          /* and.w #0x4000,%d2 */
        beq.w   .Ldone
        cmpi.w  #0x0,(0x2,%a0)          /* locked */
        bne.w   .Ldone
        move.l  #KOLOR_CTL,-(%sp)
        move.l  #DISP_MEM_2KX1K,-(%sp)
        bra.w   .Lcall

/* Unit 1, the monochrome display */
.L1_mono:
        ori.w   #0x700,%sr
        lea     (SMD_$DISP2_INT:w,%pc),%a5
        tst.w   (DISP1).l
        bmi.w   .Ldone
        lea     (SMD_TIME_$COM+2:w,%pc),%a1
        lea     (SMD_$DISPLAY_COM:w,%pc),%a0
        move.l  #DISP1,-(%sp)
        move.l  #DISP1_MEM,-(%sp)
        bra.b   .Lcall

SMD_$BLINK_CURSOR_2:
        movem.l %d2/%a2-%a3/%a5,-(%sp)
        lea     (SMD_$DISP2_INT:w,%pc),%a5
        move.w  %sr,-(%sp)
        lea     (SMD_$DISPLAY_COM+0x60:w,%pc),%a0  /* unit 2's record */
        cmpi.w  #0x3,(%a0)
        beq.b   .L2_controller
        cmpi.w  #0x4,(%a0)
        bne.b   .L2_mono

/* Unit 2, the DN6xx or DN550/560 controller */
.L2_controller:
        btst    #0x4,(COLOR_SUP+2).l
        beq.w   .Ldone
        btst    #0x5,(COLOR_SUP+2).l
        bne.w   .Ldone
        cmpi.w  #0x0,(0x2,%a0)          /* locked */
        bne.w   .Ldone
        tst.b   (COLOR_SUP+0xa1).l
        bne.w   .Ldone
        pea     (COLOR_SUP).l
        bra.b   .L2_memory

/* Unit 2, the monochrome display */
.L2_mono:
        tst.w   (DISP2).l
        bmi.b   .Ldone
        move.l  #DISP2,-(%sp)
.L2_memory:
        lea     (SMD_TIME_$COM+2:w,%pc),%a1
        move.l  #DISP2_MEM,-(%sp)

/* Both units: the call, and cursor_painted inverted */
.Lcall:
        movea.l %a1,%a2
        pea     (%a1)
        pea     (%a0)
        pea     (0x4e,%a0)
        pea     (0x32,%a0)
        pea     (0x36,%a0)
        jsr     (SMD_$XOR_CURSOR:w,%pc)
        adda.w  #0x1c,%sp
        not.b   (%a2)

.Ldone:
        move.w  (%sp)+,%sr
        movem.l (%sp)+,%d2/%a2-%a3/%a5
        rts

SMD_$BLINK_CURSOR:
        cmpi.l  #DISP2,(0x4,%sp)
        beq.b   .Lblink_unit2
        bsr.w   SMD_$BLINK_CURSOR_1
        rts
.Lblink_unit2:
        bsr.w   SMD_$BLINK_CURSOR_2
        rts
