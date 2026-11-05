/*
 * smd/sau6/smd_utils.s - the SMD_UTILS module: the display drawing
 * primitives, their entry stubs and SMD_$GET_DTYPE.
 *
 * Image addresses:
 *   sau6  0x78079B08  SMD_UTILS code segment (.TEXT, 0x4C0 bytes)
 *   sau6  0x78079B08  smd_$copy_font_to_hdm_body
 *   sau6  0x78079B8A  SMD_$INVERT_DISP
 *   sau6  0x78079BCC  smd_$write_str_clip_body
 *   sau6  0x78079EB2  smd_$clear_window_body
 *   sau6  0x78079F3E  smd_$horiz_line_body
 *   sau6  0x78079F96  smd_$vert_line_body
 *   sau6  0x7809F140  SMD_UTILS data segment (.DATA, 0x5C8 bytes)
 *   sau6  0x7809F140  SMD_$COPY_FONT_TO_HDM
 *   sau6  0x7809F14A  SMD_$WRITE_STR_CLIP
 *   sau6  0x7809F168  SMD_$CLEAR_WINDOW
 *   sau6  0x7809F176  SMD_$HORIZ_LINE
 *   sau6  0x7809F180  SMD_$VERT_LINE
 *   sau6  0x7809F18A  smd_$get_dtype_body
 *   sau6  0x7809F1FE  SMD_$GET_DTYPE
 *   sau6  0x7809F206  SMD_$GERMAN_KTT .. (smd/m68k/national_ktt.s)
 *
 * The SAU6's SMD_UTILS is the SAU5's code byte for byte
 * (smd/sau5/smd_utils.s), its absolute cells the SAU6's addresses.
 * Nothing in the SAU6 image calls SMD_$GET_DTYPE (SMD_$INIT probes no
 * controller there: base/config.ins.pas's gpu_displays_only).
 *
 * The SAU5's SMD_UTILS has the SAU2's shape (smd/sau2/smd_utils.s,
 * whose body names this file keeps): the map's entries are stubs in the
 * data segment that put the segment's first byte in A0 and jump to their
 * bodies in the code segment, whose one map symbol is SMD_$INVERT_DISP.
 * The code is the SAU5's: the drawing bodies program the SAU5's BLT
 * (its registers at 0x80..0xB2, as in smd/sau6/wired_proc.s), and
 * SMD_$INVERT_DISP has a second form.  The data segment adds
 * SMD_$GET_DTYPE, its body in the data segment ahead of its stub.  The
 * keyboard tables after SMD_$GET_DTYPE are the SAU2's
 * (smd/m68k/national_ktt.s).
 *
 * The bodies that use the data segment's cells copy A0 into A5 and reach
 * them at fixed displacements (the data segment is one section, so the
 * displacements hold):
 *   +0x14  SMD_$WS_INIT        +0x18  SMD_$ACQ_DISPLAY
 *   +0x1C  SMD_$REL_DISPLAY    +0x20  SMD_$START_BLT
 *   +0x24  the word 1          +0x26  the word 0
 *   +0x32  SMD_$UTIL_INIT
 *
 * Not compiler output: the A0-passed base, the register-saving `movem'
 * before the `link', arguments read off SP past a `movem', busy-waits
 * on the BLT's status word, SMD_$VERT_LINE branching into
 * SMD_$HORIZ_LINE's tail, and SMD_$GET_DTYPE's private bus-error
 * handler.  The Apollo assembler's <ea>=#imm forms (CMP, AND, OR, ADD,
 * SUB with an immediate into a data register), which gas spells CMPI,
 * ANDI, ORI, ADDI, SUBI, are `.short' words, the instruction in the
 * comment.
 */

/* ======================================================================
 * The code segment, keyed by SMD_$INVERT_DISP (nothing of the map lies
 * between the segment's start and it).
 * ==================================================================== */
        .section ".text.SMD_$INVERT_DISP","ax",@progbits
        .even

        .globl  SMD_$INVERT_DISP

/*
 * SMD_$COPY_FONT_TO_HDM's body, the SAU2's.  After the eight-register
 * movem: (0x24,SP) the display memory's base and (0x28,SP) the font, by
 * value, (0x2C,SP) the hidden-display-memory position's address.  Copies
 * the font's glyph raster (version 1: word size at +0x8, word offset at
 * +0x2; otherwise longword size at +0x2C and offset at +0x28) to that
 * position, seven longwords a scan line, each XORed with the longword at
 * display base + 0x1FFF0, wrapping from line 0x3FF back 0x6FE4 bytes for
 * 0xE0 more lines.  A5 := A0 is not read.
 */
smd_$copy_font_to_hdm_body:
        movem.l %d2-%d4/%d6/%a2-%a5,-(%sp)
        movea.l %a0,%a5
        movea.l (0x28,%sp),%a2          /* the font */
        cmpi.w  #1,(%a2)
        beq.b   .Lcf_version1
        move.l  (0x2c,%a2),%d0
        adda.l  (0x28,%a2),%a2
        bra.b   .Lcf_sized
.Lcf_version1:
        move.w  (0x8,%a2),%d0
        adda.w  (0x2,%a2),%a2
.Lcf_sized:
        addq.l  #3,%d0
        lsr.w   #2,%d0
        subq.l  #1,%d0
        movea.l (0x24,%sp),%a3          /* the display memory's base */
        movea.l %a3,%a1
        movea.l (0x2c,%sp),%a4          /* the position */
        clr.l   %d1
        move.w  (%a4),%d1
        move.w  #1023,%d3
        sub.w   %d1,%d3
        lsl.l   #7,%d1
        adda.l  #131056,%a1
        move.w  #100,%d6
        move.l  (%a1),%d4               /* the XOR mask */
        adda.l  %d1,%a3
        move.w  (0x2,%a4),%d1
        lsr.w   #3,%d1
        adda.w  %d1,%a3
.Lcf_line:
        move.w  %d0,%d2
        .short  0xb47c, 0x0006          /* cmp.w #6,%d2 */
        ble.b   .Lcf_count
        move.w  #6,%d2
.Lcf_count:
.Lcf_long:
        move.l  (%a2)+,(%a3)
        eor.l   %d4,(%a3)+
        dbf     %d2,.Lcf_long
        adda.w  %d6,%a3
        dbf     %d3,.Lcf_next
        suba.l  #28644,%a3              /* the wrap */
        move.w  #223,%d3
.Lcf_next:
        subq.w  #7,%d0
        bge.b   .Lcf_line
        movem.l (%sp)+,%d2-%d4/%d6/%a2-%a5
        rts

/*
 * SMD_$INVERT_DISP (map symbol): invert part of a display's memory.
 * (0x4,SP) the display memory's base, by value; (0x8,SP) a word, by
 * reference.  With the word 1, the 984 scan lines from base + 0x1400
 * each have their seven longwords from byte 100 to byte 127 inverted;
 * otherwise, as on the SAU2, the 0x1C00 longwords from base + 0x19000.
 */
SMD_$INVERT_DISP:
        movea.l (0x4,%sp),%a0
        movea.l (0x8,%sp),%a1
        cmpi.w  #1,(%a1)
        bne.b   .Linv_whole
        adda.l  #0x1400,%a0
        move.l  #983,%d1
.Linv_line:
        adda.l  #100,%a0
        move.w  #6,%d0
.Linv_long:
        not.l   (%a0)+
        dbf     %d0,.Linv_long
        dbf     %d1,.Linv_line
        bra.b   .Linv_done
.Linv_whole:
        adda.l  #102400,%a0
        move.w  #7167,%d0
.Linv_whole_long:
        not.l   (%a0)+
        dbf     %d0,.Linv_whole_long
.Linv_done:
        rts

/*
 * SMD_$WRITE_STR_CLIP's body: draw a string clipped to a window.  From
 * its stub (A5 the data segment's base).  A frame of 0x22 bytes below
 * the ten saved registers, filled by SMD_$WS_INIT; the arguments from
 * (0x30,A6): the position's address (a longword, y in its high word and
 * x in its low), a word's address, the string's address, its length's
 * address, a boolean's address and the status's address.  With the
 * display acquired (SMD_$ACQ_DISPLAY, passed the word 1, or 0 when the
 * boolean is true), each glyph of the font (version 1 or the other
 * layout, as in the copy above) is clipped to the window (+0x56..+0x5C
 * of the record SMD_$WS_INIT returns) and drawn with the BLT, in two
 * operations when it crosses the end of the hidden memory's line range;
 * x advances by each glyph's width, and the clipped-away remainder of
 * the string only advances x.  Then SMD_$REL_DISPLAY with the final x.
 */
smd_$write_str_clip_body:
        movem.l %d2-%d7/%a2-%a5,-(%sp)
        movea.l %a0,%a5
        link.w  %a6,#-34
        movea.l (0x34,%a6),%a0
        move.w  (%a0),(-0x4,%a6)
        pea     (-0x1c,%a6)
        movea.l (0x14,%a5),%a0          /* SMD_$WS_INIT */
        jsr     (%a0)
        addq.w  #4,%sp
        movea.l (0x44,%a6),%a0          /* the status */
        move.l  (-0xc,%a6),(%a0)
        bne.w   .Lws_return
        movea.l (-0x14,%a6),%a3         /* the BLT registers */
        movea.l (-0x1c,%a6),%a2         /* the font */
        movea.l (0x38,%a6),%a4          /* the string */
        movea.l (0x3c,%a6),%a0
        move.w  (%a0),%d7               /* its length */
        ble.w   .Lws_return
        subq.w  #1,%d7
        movea.l (0x40,%a6),%a0
        tst.b   (%a0)
        bmi.b   .Lws_acq0
        pea     (0x24,%a5)              /* the word 1 */
        bra.b   .Lws_acq
.Lws_acq0:
        pea     (0x26,%a5)              /* the word 0 */
.Lws_acq:
        movea.l (0x18,%a5),%a0          /* SMD_$ACQ_DISPLAY */
        jsr     (%a0)
        addq.w  #4,%sp
        move.w  %d0,%d3
        .short  0x867c, 0x8000          /* or.w #0x8000,%d3 */
        movea.l (0x30,%a6),%a0
        move.l  (%a0),%d5
        move.w  %d5,%d4                 /* x */
        swap    %d5
        addq.w  #1,%d5                  /* y + 1 */
        move.l  #0x02020020,(0x84,%a3)
        move.l  #0x02020020,(0x80,%a3)
        movea.l (-0x10,%a6),%a0         /* the record with the window */
        move.w  (0x56,%a0),%d0
        cmp.w   (0x58,%a0),%d0
        bgt.w   .Lws_skip
        move.w  (0x5a,%a0),%d0
        cmp.w   (0x5c,%a0),%d0
        bgt.w   .Lws_skip

/* One glyph */
.Lws_glyph:
        clr.w   %d1
        cmpi.w  #1,(%a2)
        beq.b   .Lws_glyph_v1
        clr.l   %d0
        move.b  (%a4)+,%d0
        add.l   (0x34,%a2),%d0
        move.b  (0,%a2,%d0.l),%d1
        beq.w   .Lws_no_glyph
        asl.w   #3,%d1
        lea     (-0x8,%a2),%a1
        adda.l  (0x38,%a2),%a1
        bra.b   .Lws_glyph_found
.Lws_glyph_v1:
        move.w  #127,%d0
        and.b   (%a4)+,%d0
        move.b  (0x1a,%a2,%d0.w),%d1
        beq.w   .Lws_no_glyph
        asl.w   #3,%d1
        lea     (0x92,%a2),%a1
.Lws_glyph_found:
        adda.w  %d1,%a1                 /* A1 = the glyph's descriptor */

        /* x: the left edge clipped to the window */
        move.b  (%a1),%d1
        ext.w   %d1
        move.w  %d1,%d2
        move.w  %d4,%d0
        sub.w   %d1,%d0
        move.w  (0x56,%a0),%d1
        sub.w   %d0,%d1
        bgt.b   .Lws_x_clipped
        cmp.w   (0x58,%a0),%d0
        ble.b   .Lws_x_inside
        move.w  %d4,%d0
        .short  0x907c, 0x007f          /* sub.w #0x7f,%d0 */
        cmp.w   (0x58,%a0),%d0
        bgt.w   .Lws_rest
        bra.w   .Lws_advance
.Lws_x_inside:
        move.w  #0,%d1
.Lws_x_clipped:
        move.w  %d1,(-0x22,%a6)
        add.w   %d1,%d0
.Lws_wait1:
        tst.w   (%a3)
        bmi.b   .Lws_wait1
        move.w  %d0,(0xaa,%a3)
        move.b  (0x1,%a1),%d1
        ext.w   %d1
        subq.w  #1,%d1
        add.w   %d1,%d2
        add.w   %d2,%d0
        sub.w   (-0x22,%a6),%d0
        cmp.w   (0x56,%a0),%d0
        blt.w   .Lws_advance
        cmp.w   (0x58,%a0),%d0
        ble.b   .Lws_x_right
        move.w  (0x58,%a0),%d0
.Lws_x_right:
        move.w  %d0,(0xb2,%a3)

        /* y: the top edge clipped to the window */
        move.b  (0x2,%a1),%d1
        ext.w   %d1
        move.w  %d5,%d0
        sub.w   %d1,%d0
        move.w  (0x5a,%a0),%d1
        sub.w   %d0,%d1
        bgt.b   .Lws_y_clipped
        cmp.w   (0x5c,%a0),%d0
        ble.b   .Lws_y_inside
        move.w  %d5,%d0
        cmpi.w  #1,(%a2)
        beq.b   .Lws_y_v1
        sub.w   (0x48,%a2),%d0
        bra.b   .Lws_y_test
.Lws_y_v1:
        sub.w   (0x16,%a2),%d0
.Lws_y_test:
        cmp.w   (0x5c,%a0),%d0
        bgt.w   .Lws_rest
        bra.w   .Lws_advance
.Lws_y_inside:
        move.w  #0,%d1
.Lws_y_clipped:
        add.w   %d1,%d0
        move.w  %d0,(0xa8,%a3)
        move.w  %d0,(-0x20,%a6)

        /* the glyph's source in the hidden memory */
        clr.w   %d2
        move.b  (0x5,%a1),%d2
        add.w   (-0x6,%a6),%d2
        move.w  (-0x8,%a6),%d0
        add.w   (0x6,%a1),%d0
        add.w   %d1,%d0
.Lws_src_line:
        move.w  #1023,%d6
        sub.w   %d0,%d6
        bge.b   .Lws_src_ok
        .short  0x907c, 0x00e0          /* sub.w #0xe0,%d0 */
        .short  0xd47c, 0x00e0          /* add.w #0xe0,%d2 */
        bra.b   .Lws_src_line
.Lws_src_ok:
        add.w   (-0x22,%a6),%d2
        move.w  %d2,(0xae,%a3)
        move.w  %d2,(-0x1e,%a6)
        move.w  %d0,(0xac,%a3)

        /* the bottom edge clipped to the window */
        move.b  (0x3,%a1),%d2
        ext.w   %d2
        add.w   %d5,%d2
        subq.w  #1,%d2
        cmp.w   (0x5a,%a0),%d2
        bge.b   .Lws_bottom
        cmpi.w  #1,(%a2)
        beq.b   .Lws_bottom_v1
        move.w  (0x4a,%a2),%d2
        bra.b   .Lws_bottom_test
.Lws_bottom_v1:
        move.w  (0x18,%a2),%d2
.Lws_bottom_test:
        add.w   %d5,%d2
        cmp.w   (0x5a,%a0),%d2
        blt.w   .Lws_rest
        bra.w   .Lws_advance
.Lws_bottom:
        cmp.w   (0x5c,%a0),%d2
        ble.b   .Lws_bottom_ok
        move.w  (0x5c,%a0),%d2
.Lws_bottom_ok:
        move.w  (-0x20,%a6),%d0
        sub.w   %d0,%d2
        cmp.w   %d2,%d6
        bge.b   .Lws_one_blt

        /* the source crosses line 1023: two operations */
        add.w   %d6,%d0
        move.w  %d0,(0xb0,%a3)
        move.w  %d3,(%a3)               /* start the first */
        add.w   %d0,%d2
        sub.w   %d6,%d2
        addq.w  #1,%d0
.Lws_wait2:
        tst.w   (%a3)
        bmi.b   .Lws_wait2
        move.w  %d0,(0xa8,%a3)
        move.w  %d2,(0xb0,%a3)
        move.w  #800,(0xac,%a3)
        move.w  (-0x1e,%a6),%d0
        .short  0xd07c, 0x00e0          /* add.w #0xe0,%d0 */
        move.w  %d0,(0xae,%a3)
        bra.b   .Lws_start
.Lws_one_blt:
        add.w   %d2,%d0
        move.w  %d0,(0xb0,%a3)
.Lws_start:
        move.w  %d3,(%a3)               /* start the BLT */

/* x advances by the glyph's width */
.Lws_advance:
        move.b  (0x4,%a1),%d0
        ext.w   %d0
        cmpi.w  #1,(%a2)
        beq.b   .Lws_advance_v1
        add.w   (0x5a,%a2),%d0
        bra.b   .Lws_advance_add
.Lws_advance_v1:
        add.w   (0x10,%a2),%d0
.Lws_advance_add:
        add.w   %d0,%d4
.Lws_next:
        dbf     %d7,.Lws_glyph
        bra.b   .Lws_release

/* Past the window: the rest of the string only advances x, entered at
   the current glyph's width */
.Lws_rest:
        cmpi.w  #1,(%a2)
        beq.b   .Lws_rest_v1_width
        bra.b   .Lws_rest_width

/* An empty window: the whole string only advances x */
.Lws_skip:
        cmpi.w  #1,(%a2)
        beq.b   .Lws_skip_v1
.Lws_skip_glyph:
        clr.l   %d0
        clr.w   %d1
        move.b  (%a4)+,%d0
        move.b  (0x34,%a2,%d0.w),%d1
        bne.b   .Lws_skip_found
        move.w  (0x6e,%a2),%d0
        bra.b   .Lws_skip_add
.Lws_skip_found:
        asl.w   #3,%d1
        lea     (-0x8,%a2),%a1
        adda.l  (0x38,%a2),%a1
        adda.w  %d1,%a1
.Lws_rest_width:
        move.b  (0x4,%a1),%d0
        ext.w   %d0
.Lws_skip_add:
        add.w   (0x5a,%a2),%d0
        add.w   %d0,%d4
        dbf     %d7,.Lws_skip_glyph
        bra.w   .Lws_release
.Lws_skip_v1:
        move.w  #127,%d0
        and.b   (%a4)+,%d0
        clr.w   %d1
        move.b  (0x1a,%a2,%d0.w),%d1
        bne.b   .Lws_skip_v1_found
        move.w  (0x12,%a2),%d0
        bra.b   .Lws_skip_v1_add
.Lws_skip_v1_found:
        asl.w   #3,%d1
        lea     (0x92,%a2),%a1
        adda.w  %d1,%a1
.Lws_rest_v1_width:
        move.b  (0x4,%a1),%d0
        ext.w   %d0
.Lws_skip_v1_add:
        add.w   (0x10,%a2),%d0
        add.w   %d0,%d4
        dbf     %d7,.Lws_skip_v1

.Lws_release:
        tst.w   (%a3)
        bmi.b   .Lws_release
        move.w  %d4,-(%sp)              /* the final x */
        movea.l (0x1c,%a5),%a0          /* SMD_$REL_DISPLAY */
        jsr     (%a0)
        move.w  (%sp)+,%d0
.Lws_return:
        unlk    %a6
        movem.l (%sp)+,%d2-%d7/%a2-%a5
        rts

/* A character with no glyph: x advances by the font's default width */
.Lws_no_glyph:
        cmpi.w  #1,(%a2)
        beq.b   .Lws_no_glyph_v1
        add.w   (0x6e,%a2),%d4
        add.w   (0x5a,%a2),%d4
        bra.w   .Lws_next
.Lws_no_glyph_v1:
        add.w   (0x12,%a2),%d4
        add.w   (0x10,%a2),%d4
        bra.w   .Lws_next

/*
 * SMD_$CLEAR_WINDOW's body: clear a window with one BLT operation.  From
 * its stub (A5 the data segment's base).  A frame of 0x1C bytes below
 * the six saved registers, filled by SMD_$UTIL_INIT; (0x20,A6) the
 * window's address (two longwords), (0x24,A6) the status.  The display
 * is acquired with the word 1 and released after the BLT is done
 * (SMD_$REL_DISPLAY with nothing pushed).
 */
smd_$clear_window_body:
        movem.l %d5-%d7/%a2-%a3/%a5,-(%sp)
        movea.l %a0,%a5
        link.w  %a6,#-28
        pea     (-0x1c,%a6)
        movea.l (0x32,%a5),%a0          /* SMD_$UTIL_INIT */
        jsr     (%a0)
        addq.w  #4,%sp
        movea.l (0x24,%a6),%a0          /* the status */
        move.l  (-0xc,%a6),(%a0)
        bne.w   .Lcw_return
        movea.l (0x20,%a6),%a0          /* the window */
        move.l  (%a0)+,%d6
        move.l  (%a0),%d7
        movea.l (-0x18,%a6),%a2
        movea.l (-0x14,%a6),%a3         /* the BLT registers */
        pea     (0x24,%a5)              /* the word 1 */
        movea.l (0x18,%a5),%a0          /* SMD_$ACQ_DISPLAY */
        jsr     (%a0)
        addq.w  #4,%sp
        move.w  %d0,%d5
        move.l  #0x02020020,(0x84,%a3)
        move.l  #0x02020020,(0x80,%a3)
        move.w  #896,(0xae,%a3)
        move.w  #1023,(0xac,%a3)
        move.w  %d6,(0xb2,%a3)
        swap    %d6
        move.w  %d6,(0xaa,%a3)
        move.w  %d7,(0xb0,%a3)
        swap    %d7
        move.w  %d7,(0xa8,%a3)
        .short  0x8a7c, 0x8002          /* or.w #0x8002,%d5 */
        movea.l (-0x10,%a6),%a0
        move.w  %d5,(%a3)               /* start the BLT */
.Lcw_wait:
        tst.w   (%a3)
        bmi.b   .Lcw_wait
        movea.l (0x1c,%a5),%a0          /* SMD_$REL_DISPLAY */
        jsr     (%a0)
.Lcw_return:
        unlk    %a6
        movem.l (%sp)+,%d5-%d7/%a2-%a3/%a5
        rts

/*
 * SMD_$HORIZ_LINE's body (from its stub; A0 not used).  After the
 * eight-register movem: (0x24..0x2C,SP) the addresses of y, x1 and x2,
 * (0x30,SP) the display base (loaded, not used), (0x34,SP) the BLT
 * registers, (0x38,SP) the control word's address, (0x3C,SP) loaded and
 * not used.  Sets up and starts a one-line BLT and waits for it.
 */
smd_$horiz_line_body:
        movem.l %d2-%d6/%a2-%a4,-(%sp)
        movem.l (0x24,%sp),%a2-%a4
        movea.l (0x34,%sp),%a1
        move.l  #0x02020020,(0x84,%a1)
        move.l  #0x02020020,(0x80,%a1)
        move.w  (%a2),(0xa8,%a1)
        move.w  (%a2),(0xb0,%a1)
        move.w  (%a3),(0xaa,%a1)
        move.w  (%a4),(0xb2,%a1)
.Lline_common:
        move.w  #960,(0xae,%a1)
        move.w  #1023,(0xac,%a1)
        movea.l (0x30,%sp),%a2
        movea.l (0x38,%sp),%a0
        move.w  (%a0),%d0
        .short  0x807c, 0x8002          /* or.w #0x8002,%d0 */
        movea.l (0x3c,%sp),%a0
        move.w  %d0,(%a1)               /* start the BLT */
.Lline_wait:
        tst.w   (%a1)
        bmi.b   .Lline_wait
        movem.l (%sp)+,%d2-%d6/%a2-%a4
        rts

/*
 * SMD_$VERT_LINE's body: the same arguments with x, y1 and y2; it
 * shares SMD_$HORIZ_LINE's tail.
 */
smd_$vert_line_body:
        movem.l %d2-%d6/%a2-%a4,-(%sp)
        movem.l (0x24,%sp),%a2-%a4
        movea.l (0x34,%sp),%a1
        move.l  #0x02020020,(0x84,%a1)
        move.l  #0x02020020,(0x80,%a1)
        move.w  (%a2),(0xaa,%a1)
        move.w  (%a2),(0xb2,%a1)
        move.w  (%a3),(0xa8,%a1)
        move.w  (%a4),(0xb0,%a1)
        bra.b   .Lline_common
        .word   0                       /* to the segment's end */

/* ======================================================================
 * The data segment, one section from its first byte.
 * ==================================================================== */
        .section ".text.SMD_$COPY_FONT_TO_HDM","ax",@progbits
        .even

        .globl  SMD_$COPY_FONT_TO_HDM
        .globl  SMD_$WRITE_STR_CLIP
        .globl  SMD_$CLEAR_WINDOW
        .globl  SMD_$HORIZ_LINE
        .globl  SMD_$VERT_LINE
        .globl  SMD_$GET_DTYPE

/* The stubs: the segment's first byte in A0, then the body. */
SMD_$COPY_FONT_TO_HDM:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$copy_font_to_hdm_body).l
SMD_$WRITE_STR_CLIP:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$write_str_clip_body).l
        .long   SMD_$WS_INIT            /* +0x14 */
        .long   SMD_$ACQ_DISPLAY        /* +0x18 */
        .long   SMD_$REL_DISPLAY        /* +0x1C */
        .long   SMD_$START_BLT          /* +0x20 */
        .word   1                       /* +0x24: SMD_$ACQ_DISPLAY's argument */
        .word   0                       /* +0x26: its argument when the
                                           string's boolean is true */
SMD_$CLEAR_WINDOW:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$clear_window_body).l
        .long   SMD_$UTIL_INIT          /* +0x32 */
SMD_$HORIZ_LINE:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$horiz_line_body).l
SMD_$VERT_LINE:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$vert_line_body).l

/*
 * SMD_$GET_DTYPE's body: probe a display controller's memory and tell
 * which display it drives.  SMD_$INIT pushes the unit's registers and
 * then its display memory's base, two longwords by value: after the
 * movem, (0xC,SP) the display memory's base and (0x10,SP) the BLT
 * registers.  The routine writes 0xDEAD0000 to the longword at base +
 * 0x1FFFC with its own handler in the bus-error vector (BUS_ERROR_VEC,
 * put back after the write); a bus error there returns 0 (the handler
 * puts the vector back and the stack pointer saved before the write).
 * Otherwise it loads three of the BLT's longword registers (+0xA8,
 * +0xAC, +0xB0: 0x03FF03F0, 0x03FF03E0, 0x03FF03FF), starts it with
 * 0x8001 at +0x40, waits for it, and compares the probed longword's two
 * words: equal returns 1, different 2.  The result is
 * D0's word.
 */
smd_$get_dtype_body:
        movem.l %a2-%a3,-(%sp)
        movea.l (0xc,%sp),%a1
        adda.l  #0x1fffc,%a1            /* the probed longword */
        movea.l (0x10,%sp),%a2          /* the BLT registers */
        move.l  (BUS_ERROR_VEC).l,%d0
        lea     (.Lgd_bus_error:w,%pc),%a3
        move.l  %a3,(BUS_ERROR_VEC).l
        move.l  %sp,%d1
        move.l  #0xdead0000,(%a1)
        move.l  %d0,(BUS_ERROR_VEC).l
        move.l  #0x03ff03f0,(0xa8,%a2)
        move.l  #0x03ff03e0,(0xac,%a2)
        move.l  #0x03ff03ff,(0xb0,%a2)
        move.w  #0x8001,(0x40,%a2)      /* start the BLT */
.Lgd_wait:
        tst.w   (%a2)
        bmi.b   .Lgd_wait
        cmpm.w  (%a1)+,(%a1)+
        bne.b   .Lgd_two
        move.w  #1,%d0
        bra.b   .Lgd_return
.Lgd_two:
        move.w  #2,%d0
        bra.b   .Lgd_return
.Lgd_bus_error:
        move.l  %d0,(BUS_ERROR_VEC).l
        movea.l %d1,%sp
        move.w  #0,%d0
.Lgd_return:
        movem.l (%sp)+,%a2-%a3
        rts

SMD_$GET_DTYPE:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0
        jmp     (smd_$get_dtype_body:w,%pc)
