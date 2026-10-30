/*
 * smd/sau5/wired_proc.s - the code segment of the hand-written SMD_WIRED
 * module: the cursor XOR/OR body and the scroll and BLT bodies (its
 * SMD_$LOCK_DISPLAY and SMD_$BIT_SET are the SAU2's code, in
 * smd/m68k/lock_display.s and smd/m68k/bit_set.s).
 *
 * Image addresses:
 *   sau5  0x00E15D3C  SMD_WIRED code segment (WIRED_PROC, 0x69C bytes)
 *   sau5  0x00E15D3C  smd_$xor_cursor_body
 *   sau5  0x00E15D46  smd_$or_cursor_body
 *   sau5  0x00E162BA  smd_$start_scroll_body
 *   sau5  0x00E162EE  smd_$continue_scroll_body
 *   sau5  0x00E16320  SMD_$LOCK_DISPLAY (smd/m68k/lock_display.s)
 *   sau5  0x00E16364  SMD_$BIT_SET (smd/m68k/bit_set.s)
 *   sau5  0x00E16370  smd_$start_blt_body
 *
 * The SAU5's SMD_WIRED is different code from the SAU2's (smd/sau2/*.s):
 * the cursor body drives the color displays as well as the monochrome
 * one, the scroll and BLT bodies address the SAU5's BLT registers, and
 * the module's data segment (smd/sau5/disp1_int.s and the files after
 * it) holds two display interrupts and two blink routines.  The map gives
 * the segment two symbols, SMD_$LOCK_DISPLAY and SMD_$BIT_SET; the bodies
 * before and after them are reached only from the trampolines in the
 * data segment (smd/sau5/cursor_thunks.s, scroll.s, start_blt.s), which
 * jump to them by absolute address, so they are globals of ours here.
 * The segment is four sections in the map's order: .text.SMD_WIRED
 * (the segment's start to SMD_$LOCK_DISPLAY, named by the map's segment),
 * the shared files' .text.SMD_$LOCK_DISPLAY and .text.SMD_$BIT_SET, and
 * .text.smd_$start_blt_body (from 0x00E16370 to the segment's end).  The
 * bodies reach nothing in the shared routines, and nothing reaches into
 * the bodies but the trampolines' absolute jumps, so the cuts move no
 * operand.  Neither of this file's sections defines a map symbol: the
 * SAU5's layout must key them by their image addresses (as
 * tools/gen_layout_ld.py's ANCHORS do the SAU2's .text.FIM_UNWIRED; that
 * tool reads only the SAU2 map so far), and tools/asm_compare.py anchors
 * them by its SAU5 LOCAL_SYMBOLS.
 *
 * The bodies take the SMD_WIRED data segment's base (SMD_$DISP2_INT) in
 * A0 from their trampoline, copy it to A5 and reach the segment's cells
 * at fixed displacements from it (written as numbers, the cell named on
 * each line):
 *   +0x15C  smd_$setup_scroll_blt, the base-level BLT setup entry
 *   +0x2B0  the cell holding KOLOR_CTL, the DN570/DN580 board's registers
 *   +0x2C8  the cell holding PROC1_$SET_LOCK
 *   +0x2CC  the cell holding PROC1_$CLR_LOCK
 *   +0x2D2  the DN570 board's status bit 12, as last sampled
 *   +0x2D4  COLOR3_$CR_CONTENTS, the DN570 control register as last
 *           written
 *   +0x2D8  0x40 bytes: the DN580 board's registers saved around the
 *           cursor's drawing
 *   +0x318  the DN580 board's mode word, saved
 *   +0x31E  the DN6xx/DN550 command blocks and the DN570's cursor
 *           commands (smd/sau5/wired_data.s)
 *   +0x52E  SMD_$CURSOR_TABLE
 *   +0x63E  SMD_$DISPLAY_COM + 0x60, unit 2's display record
 * Those distances hold because the data segment's sections are laid out
 * contiguously in the map's order (one section per map symbol run, no
 * section of ours between them).
 *
 * Several instructions are in the forms the Apollo assembler wrote and
 * gas does not: CMP, AND, OR and ADD with an immediate source and a data
 * register destination (gas emits CMPI, ANDI, ORI and ADDI, the same
 * length), and one MOVE.L of a small immediate (gas emits MOVEQ).  They
 * are `.short' words here, the instruction in the comment.
 * Where the image does use ANDI or ORI on a data register, the mnemonic
 * is written.
 */

        .section ".text.SMD_WIRED","ax",@progbits
        .globl  smd_$xor_cursor_body
        .globl  smd_$or_cursor_body
        .globl  smd_$start_scroll_body
        .globl  smd_$continue_scroll_body

/*
 * The body of SMD_$XOR_CURSOR and SMD_$OR_CURSOR: draw or remove a
 * cursor pattern at a display position, under PROC1 lock 8.
 *
 * Entry, from the trampolines (A0 = SMD_WIRED's data base); the caller's
 * arguments are pushed right to left and it cleans them up, and the
 * displacements are 0x20 over the usual (0x4,SP) because of the movem:
 *   (0x24,SP)  the cursor number, by reference (an index into
 *              SMD_$CURSOR_TABLE, 0x28-byte patterns)
 *   (0x28,SP)  the cursor position, by reference: y in the high word,
 *              x in the low
 *   (0x2C,SP)  the display's limits, by reference (+2 and +6 read)
 *   (0x30,SP)  the display record (its display type at +0)
 *   (0x34,SP)  the erase flag, by reference (a Domain boolean)
 *   (0x38,SP)  the display memory base, by value
 *   (0x3C,SP)  the display controller's registers, by value
 * Exit: D0's low byte true (0xFF); the upper bytes are whatever D2 held.
 *
 * D3 tells the two entries apart for the monochrome display: 0 combines
 * the pattern with EOR, 1 with OR.  The color displays draw their cursor
 * in hardware: the DN6xx and DN550/560 controllers (types 3 and 4) take
 * command blocks, the DN580 (type 5) and the DN570 (type 6) boards take
 * register writes through KOLOR_CTL, and for them the erase flag, not
 * D3, chooses drawing or removing.
 */
smd_$xor_cursor_body:
        movem.l %d2-%d4/%d7/%a2-%a5,-(%sp)
        movea.l %a0,%a5                 /* A5 = the data segment's base */
        clr.b   %d3                     /* 0: EOR */
        bra.b   .Lbody

smd_$or_cursor_body:
        movem.l %d2-%d4/%d7/%a2-%a5,-(%sp)
        movea.l %a0,%a5
        moveq   #1,%d3                  /* 1: OR */

.Lbody:
        move.w  #0x8,-(%sp)             /* lock 8 */
        movea.l (0x2c8,%a5),%a0         /* PROC1_$SET_LOCK */
        jsr     (%a0)
        addq.l  #2,%sp

        /* A1 = &SMD_$CURSOR_TABLE[cursor number] */
        move.w  #0x28,%d0
        movea.l (0x24,%sp),%a0
        mulu.w  (%a0),%d0
        lea     (0x52e,%a5),%a1         /* SMD_$CURSOR_TABLE */
        adda.w  %d0,%a1

        movea.l (0x28,%sp),%a0
        move.l  (%a0),%d0               /* D0 = the position */
        movea.l (0x2c,%sp),%a2          /* A2 = the limits */

        /* x - the pattern's hot spot x, floored at 0 and capped at
           limits[1] - width + 1 */
        sub.w   (0x4,%a1),%d0
        bpl.b   .Lx_nonneg
        clr.w   %d0
.Lx_nonneg:
        move.w  (0x2,%a2),%d1
        sub.w   (%a1),%d1
        addq.w  #1,%d1
        cmp.w   %d1,%d0
        ble.b   .Lx_done
        move.w  %d1,%d0
.Lx_done:
        swap    %d0                     /* now y */

        /* y + the hot spot y, floored at height - 1 and capped at
           limits[3] */
        add.w   (0x6,%a1),%d0
        cmp.w   (0x2,%a1),%d0
        bge.b   .Ly_ok
        move.w  (0x2,%a1),%d0
        subq.w  #1,%d0
.Ly_ok:
        cmp.w   (0x6,%a2),%d0
        ble.b   .Ly_done
        move.w  (0x6,%a2),%d0
.Ly_done:

        /* By the display's type */
        movea.l (0x30,%sp),%a0
        cmpi.w  #0x3,(%a0)
        beq.w   .Lcmd_controller
        cmpi.w  #0x4,(%a0)
        beq.w   .Lcmd_controller
        cmpi.w  #0x5,(%a0)
        beq.w   .Ldn580
        cmpi.w  #0x6,(%a0)
        beq.w   .Ldn570
        bra.w   .Lmono

/*
 * Types 3 and 4: the controller at (0x3C,SP) takes command blocks a word
 * at a time.  Wait for it to be idle (bit 5 of its status word); when its
 * register at +0x80 has all of bits 4..7 set, or bit 2 of its register at
 * +0xC2 is clear, it takes the cursor as a pattern command block, else
 * it loads the pattern into its own cursor memory and takes a position
 * command.
 */
.Lcmd_controller:
        movea.l (0x3c,%sp),%a0
.Lcmd_idle:
        btst    #0x5,(0x2,%a0)
        bne.b   .Lcmd_idle
        move.w  (0x80,%a0),%d1
        .short  0xc27c, 0x00f0          /* and.w #0xf0,%d1 */
        .short  0xb27c, 0x00f0          /* cmp.w #0xf0,%d1 */
        beq.b   .Lcmd_block
        move.w  (0xc2,%a0),%d1
        btst    #0x2,%d1
        bne.w   .Lcmd_cursor_memory

.Lcmd_block:
        move.w  (%a1),(0x32c,%a5)       /* the pattern's width, height */
        move.w  (0x2,%a1),(0x32e,%a5)
        sub.w   (0x2,%a1),%d0
        lea     (0x31e,%a5),%a1         /* A1 = the command block */
        movea.l (0x34,%sp),%a0
        tst.b   (%a0)
        bpl.b   .Lcmd_draw
        /* erase: 9 words */
        move.l  %d0,(0x328,%a5)
        move.l  #0x400,(0x324,%a5)
        move.w  #0x8,%d0
        bra.w   .Lcmd_send
.Lcmd_draw:
        /* draw: 19 words, the pattern's source in the cursor table */
        move.l  %d0,(0x324,%a5)
        move.l  #0x400,(0x328,%a5)
        move.l  %d0,(0x33c,%a5)
        movea.l (0x24,%sp),%a0
        move.w  (%a0),%d0
        lsl.w   #5,%d0
        .short  0xd07c, 0x0020          /* add.w #0x20,%d0 */
        move.w  %d0,(0x338,%a5)
        move.w  (0x32c,%a5),(0x340,%a5)
        move.w  (0x32e,%a5),(0x342,%a5)
        .short  0x203c, 0x0000, 0x0012  /* move.l #0x12,%d0 (gas: moveq) */
        bra.w   .Lcmd_send

/* The pattern into the controller's cursor memory, when it is not the
   one unit 2's record says is loaded there; then a 3-word position
   command (1 word to erase). */
.Lcmd_cursor_memory:
        sub.w   (0x2,%a1),%d0
        addq.w  #1,%d0
        movea.l (0x24,%sp),%a0
        lea     (0x63e,%a5),%a2         /* unit 2's display record */
        move.w  (0x3a,%a2),%d1
        cmp.w   (%a0),%d1
        beq.b   .Lcmd_position
        movea.l (0x3c,%sp),%a0
        clr.l   %d1
        move.w  (0xa6,%a0),%d1
        .short  0xd2bc, 0x0000, 0x0040  /* add.l #0x40,%d1 */
        rol.l   #1,%d1
        adda.l  %d1,%a0
        move.w  (%a1),(%a0)+
        move.w  (0x2,%a1),(%a0)+
        clr.l   (%a0)+
        move.l  #0x2e222222,(%a0)+
        move.w  #0xf,%d1
.Lcmd_copy_rows:
        move.w  (0x8,%a1),(%a0)+
        addq.l  #2,%a1
        dbf     %d1,.Lcmd_copy_rows
        movea.l (0x24,%sp),%a0
        move.w  (%a0),(0x3a,%a2)
.Lcmd_position:
        lea     (0x344,%a5),%a1
        movea.l (0x34,%sp),%a0
        tst.b   (%a0)
        bpl.b   .Lcmd_position_draw
        clr.l   %d0
        move.w  #0x9001,(0x344,%a5)
        bra.b   .Lcmd_send
.Lcmd_position_draw:
        move.l  %d0,(0x346,%a5)
        move.w  #0x9000,(0x344,%a5)
        moveq   #2,%d0

/* Send D0 + 1 words from A1, each when the controller is ready (bit 15
   of its status word clear), the controller's byte at +0x9A first put
   into the block; then wait for it to finish. */
.Lcmd_send:
        movea.l (0x3c,%sp),%a0
        move.b  (0x9a,%a0),(0x320,%a5)
.Lcmd_send_word:
        tst.w   (0x2,%a0)
        bmi.b   .Lcmd_send_word
        move.w  (%a1)+,(0x9e,%a0)
        dbf     %d0,.Lcmd_send_word
.Lcmd_done:
        btst    #0x5,(0x2,%a0)
        bne.b   .Lcmd_done
        bra.w   .Lunlock

/*
 * Type 5, the DN580: the board's registers through KOLOR_CTL.  Save its
 * mode word and set bit 6 in it; unless the board is busy (bit 7 of its
 * status, then the mode is put back), wait for it, save 0x40 bytes of
 * its registers, run its BLT twice to draw the cursor or once to remove
 * it, wait on bit 14 of its status, and restore the registers.
 */
.Ldn580:
        movea.l (0x2b0,%a5),%a3         /* KOLOR_CTL */
        move.w  (0x700c,%a3),(0x318,%a5)
        ori.w   #0x40,(0x700c,%a3)
        move.w  (0x700e,%a3),%d7
        tst.b   %d7
        bmi.w   .Ldn580_restore_mode
.Ldn580_wait1:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_wait1
.Ldn580_wait2:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_wait2
        lea     (0x2d8,%a5),%a4         /* the save area */
        move.w  (0x7000,%a3),(%a4)+
        move.w  (0x7042,%a3),(%a4)+
        move.l  (0x7044,%a3),(%a4)+
        move.l  (0x7048,%a3),(%a4)+
        move.l  (0x704c,%a3),(%a4)+
        move.l  (0x7050,%a3),(%a4)+
        move.l  (0x7054,%a3),(%a4)+
        move.l  (0x7058,%a3),(%a4)+
        move.l  (0x705c,%a3),(%a4)+
        move.l  (0x7060,%a3),(%a4)+
        move.l  (0x7064,%a3),(%a4)+
        move.l  (0x7068,%a3),(%a4)+
        move.l  (0x706c,%a3),(%a4)+
        move.l  (0x7070,%a3),(%a4)+
        move.l  (0x7074,%a3),(%a4)+
        move.l  (0x7078,%a3),(%a4)+
        move.l  (0x707c,%a3),(%a4)+
        move.w  (%a1),(0x32c,%a5)       /* the pattern's width, height */
        move.w  (0x2,%a1),(0x32e,%a5)
        sub.w   (0x2,%a1),%d0
        addq.w  #1,%d0
        movea.l (0x34,%sp),%a0
        tst.b   (%a0)
        bpl.b   .Ldn580_draw
        bra.w   .Ldn580_erase

.Ldn580_draw:
.Ldn580_draw_wait1:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_draw_wait1
        move.l  %d0,(0x3004,%a3)
        move.w  #0x5f0,(0x3008,%a3)
        move.w  #0x20,(0x300a,%a3)
        move.w  #0xf600,(0x3000,%a3)
        move.w  #0x6,(0x3002,%a3)
        move.l  (0x32c,%a5),(0x300c,%a3)
        clr.w   (0x363e,%a3)
.Ldn580_draw_wait2:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_draw_wait2
        move.l  %d0,(0x3008,%a3)
        move.w  #0x5e0,(0x3004,%a3)
        movea.l (0x24,%sp),%a0
        move.w  (%a0),%d0
        addq.w  #2,%d0
        lsl.w   #4,%d0
        move.w  %d0,(0x3006,%a3)
        move.w  #0xf500,(0x3000,%a3)
        move.w  #0x8,(0x3002,%a3)
        move.l  (0x32c,%a5),(0x300c,%a3)
        clr.w   (0x3010,%a3)
        clr.w   (0x3012,%a3)
        clr.w   (0x363e,%a3)
        bra.w   .Ldn580_bit14

.Ldn580_erase:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_erase
        move.l  %d0,(0x3008,%a3)
        move.w  #0x5f0,(0x3004,%a3)
        move.w  #0x20,(0x3006,%a3)
        move.w  #0xf600,(0x3000,%a3)
        move.w  #0x6,(0x3002,%a3)
        move.l  (0x32c,%a5),(0x300c,%a3)
        clr.w   (0x363e,%a3)

/* Wait (up to 101 polls) for bit 14 of the status to clear, then for
   it to be set, then for the board to be idle (bit 15 clear). */
.Ldn580_bit14:
        move.w  #0x64,%d4
.Ldn580_bit14_poll:
        move.w  (0x700e,%a3),%d2
        .short  0xc47c, 0x4000          /* and.w #0x4000,%d2 */
        beq.b   .Ldn580_bit14_set
        dbf     %d4,.Ldn580_bit14_poll
.Ldn580_bit14_set:
        move.w  (0x700e,%a3),%d2
        .short  0xc47c, 0x4000          /* and.w #0x4000,%d2 */
        beq.b   .Ldn580_bit14_set
.Ldn580_idle:
        tst.w   (0x700e,%a3)
        bmi.b   .Ldn580_idle
        move.l  -(%a4),(0x303c,%a3)     /* the saved registers, back */
        move.l  -(%a4),(0x3038,%a3)
        move.l  -(%a4),(0x3034,%a3)
        move.l  -(%a4),(0x3030,%a3)
        move.l  -(%a4),(0x302c,%a3)
        move.l  -(%a4),(0x3028,%a3)
        move.l  -(%a4),(0x3024,%a3)
        move.l  -(%a4),(0x3020,%a3)
        move.l  -(%a4),(0x301c,%a3)
        move.l  -(%a4),(0x3018,%a3)
        move.l  -(%a4),(0x3014,%a3)
        move.l  -(%a4),(0x3010,%a3)
        move.l  -(%a4),(0x300c,%a3)
        move.l  -(%a4),(0x3008,%a3)
        move.l  -(%a4),(0x3004,%a3)
        move.l  -(%a4),(0x3000,%a3)

/* Put bit 6 of the mode word back as it was. */
.Ldn580_restore_mode:
        move.w  (0x318,%a5),%d2
        .short  0xc47c, 0x0040          /* and.w #0x40,%d2 */
        bne.w   .Lunlock
        andi.w  #0xffbf,(0x700c,%a3)
        bra.w   .Lunlock

/*
 * Type 6, the DN570: the board's registers through KOLOR_CTL.  Unless
 * bit 13 of its status is set, toggle bit 0 of the control register
 * (COLOR3_$CR_CONTENTS, its copy) on, waiting for bit 11 of the status
 * to clear, and off, waiting for it to set, remembering bit 12 each
 * time; then write the cursor's commands to the board's command port
 * (+0x3000), each once the status's low four bits are at least a count
 * (8 or 10 for the commands, 4 for the last, then 15), and wait for
 * bit 12 to come back to the value remembered.
 */
.Ldn570:
        movea.l (0x2b0,%a5),%a3         /* KOLOR_CTL */
        move.w  (0x7030,%a3),%d2
        andi.w  #0x1000,%d2
        move.w  %d2,(0x2d2,%a5)
        move.w  (0x7030,%a3),%d2
        .short  0xc47c, 0x2000          /* and.w #0x2000,%d2 */
        bne.w   .Ldn570_commands
        move.w  (0x2d4,%a5),%d2         /* COLOR3_$CR_CONTENTS */
        ori.w   #0x1,%d2
        move.w  %d2,(0x2d4,%a5)
        move.w  %d2,(0x7020,%a3)
.Ldn570_wait_set:
        move.w  (0x7030,%a3),%d2
        .short  0xc47c, 0x0800          /* and.w #0x800,%d2 */
        bne.b   .Ldn570_wait_set
        move.w  (0x7030,%a3),%d2
        andi.w  #0x1000,%d2
        move.w  %d2,(0x2d2,%a5)
        move.w  (0x2d4,%a5),%d2
        andi.w  #0xfffe,%d2
        move.w  %d2,(0x2d4,%a5)
        move.w  %d2,(0x7020,%a3)
.Ldn570_wait_clear:
        move.w  (0x7030,%a3),%d2
        .short  0xc47c, 0x0800          /* and.w #0x800,%d2 */
        beq.b   .Ldn570_wait_clear

.Ldn570_commands:
        move.w  (%a1),(0x32c,%a5)       /* the pattern's width, height */
        move.w  (0x2,%a1),(0x32e,%a5)
        sub.w   (0x2,%a1),%d0
        addq.w  #1,%d0
        movea.l (0x34,%sp),%a0
        tst.b   (%a0)
        bpl.b   .Ldn570_draw
        /* erase */
        move.l  %d0,(0x328,%a5)
        move.w  #0x3e0,(0x324,%a5)
        move.w  #0x335,(0x326,%a5)
        bra.w   .Ldn570_erase
.Ldn570_draw:
        move.l  %d0,(0x324,%a5)
        move.l  %d0,(0x33c,%a5)
        move.w  #0x3e0,(0x328,%a5)
        move.w  #0x335,(0x32a,%a5)
        move.w  #0x3e0,(0x338,%a5)
        move.w  #0x20,%d0
        movea.l (0x24,%sp),%a0
        mulu.w  (%a0),%d0
        .short  0xd07c, 0x0325          /* add.w #0x325,%d0 */
        move.w  %d0,(0x33a,%a5)
        move.w  (0x32c,%a5),(0x340,%a5)
        move.w  (0x32e,%a5),(0x342,%a5)
        bra.w   .Ldn570_draw_queue1
.Ldn570_draw_queue1:
        move.w  (0x7030,%a3),%d0
        .short  0xc07c, 0x000f          /* and.w #0xf,%d0 */
        .short  0xb07c, 0x0008          /* cmp.w #0x8,%d0 */
        blt.b   .Ldn570_draw_queue1
        move.w  #0xf600,(0x3000,%a3)
        move.w  #0x6,(0x3000,%a3)
        move.w  (0x324,%a5),(0x3000,%a3)
        move.w  (0x326,%a5),(0x3000,%a3)
        move.w  (0x328,%a5),(0x3000,%a3)
        move.w  (0x32a,%a5),(0x3000,%a3)
        move.w  (0x32c,%a5),(0x3000,%a3)
        move.w  (0x32e,%a5),(0x3000,%a3)
.Ldn570_draw_queue2:
        move.w  (0x7030,%a3),%d0
        .short  0xc07c, 0x000f          /* and.w #0xf,%d0 */
        .short  0xb07c, 0x000a          /* cmp.w #0xa,%d0 */
        blt.b   .Ldn570_draw_queue2
        move.w  #0xf500,(0x3000,%a3)
        move.w  #0x8,(0x3000,%a3)
        move.w  (0x338,%a5),(0x3000,%a3)
        move.w  (0x33a,%a5),(0x3000,%a3)
        move.w  (0x33c,%a5),(0x3000,%a3)
        move.w  (0x33e,%a5),(0x3000,%a3)
        move.w  (0x340,%a5),(0x3000,%a3)
        move.w  (0x342,%a5),(0x3000,%a3)
        clr.w   (0x3000,%a3)
        clr.w   (0x3000,%a3)
        bra.w   .Ldn570_flush
.Ldn570_erase:
        move.w  (0x7030,%a3),%d0
        .short  0xc07c, 0x000f          /* and.w #0xf,%d0 */
        .short  0xb07c, 0x0008          /* cmp.w #0x8,%d0 */
        blt.b   .Ldn570_erase
        move.w  #0xf600,(0x3000,%a3)
        move.w  #0x6,(0x3000,%a3)
        move.w  (0x324,%a5),(0x3000,%a3)
        move.w  (0x326,%a5),(0x3000,%a3)
        move.w  (0x328,%a5),(0x3000,%a3)
        move.w  (0x32a,%a5),(0x3000,%a3)
        move.w  (0x32c,%a5),(0x3000,%a3)
        move.w  (0x32e,%a5),(0x3000,%a3)
.Ldn570_flush:
        move.w  (0x7030,%a3),%d0
        .short  0xc07c, 0x000f          /* and.w #0xf,%d0 */
        .short  0xb07c, 0x0004          /* cmp.w #0x4,%d0 */
        blt.b   .Ldn570_flush
        move.w  #0x4f20,(0x3000,%a3)
        move.w  #0x2,(0x3000,%a3)
        clr.w   (0x3000,%a3)
        clr.w   (0x3000,%a3)
.Ldn570_empty:
        move.w  (0x7030,%a3),%d0
        .short  0xc07c, 0x000f          /* and.w #0xf,%d0 */
        .short  0xb07c, 0x000f          /* cmp.w #0xf,%d0 */
        blt.b   .Ldn570_empty
.Ldn570_frame:
        move.w  (0x2d2,%a5),%d2
        move.w  (0x7030,%a3),%d0
        andi.w  #0x1000,%d0
        eor.w   %d0,%d2
        bne.b   .Ldn570_frame
        bra.w   .Lunlock

/*
 * The monochrome display: the pattern's rows into display memory, the
 * same as the SAU2's.  The frame-buffer address is
 *   display base + ((y << 16 | (x << 6)) >> 9 & ~1)
 * (0x80 bytes a scan line plus x / 8, forced even); the rows go from the
 * bottom up, each shifted right by x & 0xF in a longword and combined
 * with the frame buffer, EOR or OR by D3.
 */
.Lmono:
        swap    %d0                     /* D0 = {y:high, x:low} */
        move.w  #0x80,%d4               /* bytes per scan line */
        move.w  %d0,%d1
        .short  0xc27c, 0x000f          /* and.w #0xf,%d1 */
        lsl.w   #6,%d0
        lsr.l   #7,%d0
        lsr.l   #2,%d0
        bclr    #0x0,%d0
        movea.l (0x38,%sp),%a0          /* the display memory base */
        adda.l  %d0,%a0

        /* A1 = &pattern->rows[height - 1]; D0 = height - 1 (dbf count) */
        move.w  (0x2,%a1),%d0
        subq.w  #1,%d0
        lea     (0x8,%a1),%a1
        adda.w  %d0,%a1
        adda.w  %d0,%a1

        tst.b   %d3
        bne.b   .Lor_loop
.Lxor_loop:
        move.l  (%a1),%d2
        clr.w   %d2
        lsr.l   %d1,%d2
        eor.l   %d2,(%a0)
        suba.w  %d4,%a0
        subq.w  #2,%a1
        dbf     %d0,.Lxor_loop
        bra.b   .Lunlock
.Lor_loop:
        move.l  (%a1),%d2
        clr.w   %d2
        lsr.l   %d1,%d2
        or.l    %d2,(%a0)
        suba.w  %d4,%a0
        subq.w  #2,%a1
        dbf     %d0,.Lor_loop

.Lunlock:
        st      %d2                     /* the low byte true, the rest kept */
        move.w  #0x8,-(%sp)
        movea.l (0x2cc,%a5),%a0         /* PROC1_$CLR_LOCK */
        jsr     (%a0)
        addq.l  #2,%sp
        move.l  %d2,%d0
        movem.l (%sp)+,%d2-%d4/%d7/%a2-%a5
        rts

/*
 * The body of SMD_$START_SCROLL: start a scroll.  Arguments (0x8,SP) the
 * display record and (0xC,SP) the BLT registers (0x4 over the usual
 * because of the push of A5).  State 2 (scrolling), bit 5 of the video
 * flags set, the step flag cleared and the operation eventcount's value
 * kept at +0x1C; the first step set up by smd_$setup_scroll_blt, then
 * started with the video flags and bits 15 and 4.  The setup's D0 is
 * not used.
 */
smd_$start_scroll_body:
        move.l  %a5,-(%sp)
        movea.l %a0,%a5                 /* A5 = the data segment's base */
        movea.l (0x8,%sp),%a1           /* A1 = the display record */
        movea.l (0xc,%sp),%a0           /* A0 = the BLT registers */
        move.w  #0x2,(0x2,%a1)
        ori.w   #0x20,(0x22,%a1)
        clr.w   (0x20,%a1)
        move.l  (0x10,%a1),(0x1c,%a1)
        jsr     (0x15c,%a5)             /* smd_$setup_scroll_blt */
        move.w  (0x22,%a1),%d0
        .short  0x807c, 0x8010          /* or.w #0x8010,%d0 */
        move.w  %d0,(%a0)               /* start the BLT */
.Lstart_scroll_done:
        movea.l (%sp)+,%a5
        rts

/*
 * The body of SMD_$CONTINUE_SCROLL: the next step of a scroll, the same
 * arguments.  With no steps left (+0x24 zero) the state becomes 3 (scroll
 * done); else the next step is set up and started and the state stays 2.
 */
smd_$continue_scroll_body:
        move.l  %a5,-(%sp)
        movea.l %a0,%a5
        movea.l (0x8,%sp),%a1
        movea.l (0xc,%sp),%a0
        tst.w   (0x24,%a1)
        bne.b   .Lcontinue_step
        move.w  #0x3,(0x2,%a1)
.Lcontinue_done:
        movea.l (%sp)+,%a5
        rts
.Lcontinue_step:
        jsr     (0x15c,%a5)             /* smd_$setup_scroll_blt */
        move.w  (0x22,%a1),%d0
        .short  0x807c, 0x8010          /* or.w #0x8010,%d0 */
        move.w  %d0,(%a0)
        move.w  #0x2,(0x2,%a1)
        bra.b   .Lcontinue_done

/*
 * 0x00E16320..0x00E1636F: SMD_$LOCK_DISPLAY (smd/m68k/lock_display.s) and
 * SMD_$BIT_SET (smd/m68k/bit_set.s), the SAU2's code.
 */

        .section ".text.smd_$start_blt_body","ax",@progbits
        .globl  smd_$start_blt_body

/*
 * The body of SMD_$START_BLT: load a BLT's parameters and start it.
 * Arguments (0x4 over the usual because of the movem): (0x8,SP) the
 * parameter block, (0xC,SP) the display record, (0x10,SP) the BLT
 * registers.  The SAU5's BLT takes six longwords of the block at register
 * offsets 0x80..0xB4, in the order below.  The control word is the
 * block's first word less bits 0 and 5, with the video flags; with bit 4
 * (asynchronous) the display goes to state 1, the step flag cleared and
 * the operation eventcount's value kept at +0x1C, and the routine
 * returns once started; without it, it waits while the BLT is busy
 * (bit 15).
 */
smd_$start_blt_body:
        movem.l %a2,-(%sp)
        movea.l (0x8,%sp),%a0           /* A0 = the parameter block */
        movea.l (0xc,%sp),%a2           /* A2 = the display record */
        movea.l (0x10,%sp),%a1          /* A1 = the BLT registers */
        move.l  (0x2,%a0),(0x84,%a1)
        move.l  (0x6,%a0),(0x80,%a1)
        move.l  (0xa,%a0),(0xac,%a1)
        move.l  (0xe,%a0),(0xa8,%a1)
        move.l  (0x12,%a0),(0xb4,%a1)
        move.l  (0x16,%a0),(0xb0,%a1)
        move.w  (%a0),%d0
        .short  0xc07c, 0xffde          /* and.w #0xffde,%d0 */
        or.w    (0x22,%a2),%d0
        btst    #0x4,%d0
        beq.b   .Lblt_start
        move.w  #0x1,(0x2,%a2)
        clr.w   (0x20,%a2)
        move.l  (0x10,%a2),(0x1c,%a2)
.Lblt_start:
        move.w  %d0,(%a1)
        btst    #0x4,%d0
        bne.b   .Lblt_done
.Lblt_spin:
        tst.w   (%a1)
        bmi.b   .Lblt_spin
.Lblt_done:
        movem.l (%sp)+,%a2
        rts

        .word   0                       /* to the segment's end */
