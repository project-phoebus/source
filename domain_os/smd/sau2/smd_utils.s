/*
 * smd/sau2/smd_utils.s - the SMD_UTILS module: the display drawing
 * primitives and their .DATA entry stubs (hand-written assembly)
 *
 * Byte gate (tools/asm_compare.py, `make check-asm'): encodings
 * identical to the image; the cells and jumps are relocations resolved
 * against the image's longwords.
 *
 * SAU2 map, two segments (smd/README.md, "SMD_UTILS is hand
 * assembly"):
 *
 *   I E702F4 SMD_UTILS size = 508   (.TEXT) the bodies; one map symbol,
 *                                   SMD_$INVERT_DISP 0xE70376
 *   D E84934 SMD_UTILS size = 54C   (.DATA) the entries:
 *       0xE84934  SMD_$COPY_FONT_TO_HDM  stub, then
 *       0xE8493E  SMD_$WRITE_STR_CLIP    stub, then four cells and two
 *                                        words the bodies reach through
 *                                        A5 = 0xE84934
 *       0xE8495C  SMD_$CLEAR_WINDOW      stub, then a cell
 *       0xE8496A  SMD_$HORIZ_LINE        stub
 *       0xE84974  SMD_$VERT_LINE         stub
 *       0xE8497E  SMD_$GERMAN_KTT ..     the national keyboard
 *                                        translation tables and the zero
 *                                        word to the segment's end, a
 *                                        section of their own
 *                                        (smd/m68k/national_ktt.s, which
 *                                        the SAU5 and SAU9 share)
 *
 * Each stub is `lea (d,PC),A0' to the data segment's first byte
 * (0xE84934, whatever the stub) and `jmp <body>.l'; the bodies that use
 * the cells copy A0 into A5 and call through (d,A5):
 *   (0x14,A5) 0xE84948  SMD_$WS_INIT      (0x18,A5) 0xE8494C  SMD_$ACQ_DISPLAY
 *   (0x1C,A5) 0xE84950  SMD_$REL_DISPLAY  (0x20,A5) 0xE84954  SMD_$START_BLT
 *   (0x24,A5) 0xE84958  the word 1        (0x26,A5) 0xE8495A  the word 0
 *   (0x32,A5) 0xE84966  SMD_$UTIL_INIT
 * so the data segment is one section in the image's order and those
 * displacements hold in our link as in the image.
 *
 * Not compiler output: the A0-passed base, the register-saving `movem'
 * before the `link' (WRITE_STR_CLIP, CLEAR_WINDOW), arguments read off
 * SP past a `movem' (COPY_FONT_TO_HDM, HORIZ_LINE, VERT_LINE),
 * busy-waits on the BLT's status word (`tst.w (A3); bmi'), and
 * VERT_LINE branching into HORIZ_LINE's tail.  The headings Pascal
 * callers use are smd/smd.ins.pas's and smd/smd_internal.ins.pas's.
 *
 * The bodies have no map symbols; their labels here are module-local
 * names (smd_$..._body) that tools/asm_compare.py's LOCAL_SYMBOLS gives
 * the image addresses of.  The code section is keyed by SMD_$INVERT_DISP,
 * the segment's one map symbol (nothing of the map lies between the
 * segment's start, 0xE702F4, and it).
 *
 * The Apollo assembler's <ea>=#imm forms (cmp/and/or/add/sub #imm,Dn),
 * which gas spells as cmpi/andi/ori/addi/subi, are written as `.short'.
 */

/* ======================================================================
 * The code segment, "I E702F4 SMD_UTILS size = 508" (.TEXT),
 * 0x00E702F4..0x00E707FB.
 * ==================================================================== */
        .section ".text.SMD_$INVERT_DISP","ax",@progbits
        .even

        .globl  SMD_$INVERT_DISP

/*
 * 0x00E702F4 - SMD_$COPY_FONT_TO_HDM's body (entered from its .DATA stub
 * with A0 = 0x00E84934; A5 := A0 is not read).  After the eight-register
 * movem: (0x24,SP) the display memory's base and (0x28,SP) the font, by
 * value, (0x2C,SP) the hidden-display-memory position's address.  Copies
 * the font's glyph raster (version 1: word size at +0x8, word offset at
 * +0x2; otherwise longword size at +0x2C and offset at +0x28) to that
 * position, seven longwords a scan line, each XORed with the longword at
 * display base + 0x1FFF0, wrapping from line 0x3FF back 0x6FE4 bytes for
 * 0xE0 more lines.
 */
smd_$copy_font_to_hdm_body:
        movem.l %d2-%d4/%d6/%a2-%a5,-(%sp)      /* e702f4  48e7 3a3c */
        movea.l %a0,%a5                         /* e702f8  2a48 */
        movea.l (0x28,%sp),%a2                  /* e702fa  246f 0028 */
        cmpi.w  #1,(%a2)                        /* e702fe  0c52 0001 */
        beq.b   .Le7030e                        /* e70302  670a */
        move.l  (0x2c,%a2),%d0                  /* e70304  202a 002c */
        adda.l  (0x28,%a2),%a2                  /* e70308  d5ea 0028 */
        bra.b   .Le70316                        /* e7030c  6008 */
.Le7030e:
        move.w  (0x8,%a2),%d0                   /* e7030e  302a 0008 */
        adda.w  (0x2,%a2),%a2                   /* e70312  d4ea 0002 */
.Le70316:
        addq.l  #3,%d0                          /* e70316  5680 */
        lsr.w   #2,%d0                          /* e70318  e448 */
        subq.l  #1,%d0                          /* e7031a  5380 */
        movea.l (0x24,%sp),%a3                  /* e7031c  266f 0024 */
        movea.l %a3,%a1                         /* e70320  224b */
        movea.l (0x2c,%sp),%a4                  /* e70322  286f 002c */
        clr.l   %d1                             /* e70326  4281 */
        move.w  (%a4),%d1                       /* e70328  3214 */
        move.w  #1023,%d3                       /* e7032a  363c 03ff */
        sub.w   %d1,%d3                         /* e7032e  9641 */
        lsl.l   #7,%d1                          /* e70330  ef89 */
        adda.l  #131056,%a1                     /* e70332  d3fc 0001 fff0 */
        move.w  #100,%d6                        /* e70338  3c3c 0064 */
        move.l  (%a1),%d4                       /* e7033c  2811 */
        adda.l  %d1,%a3                         /* e7033e  d7c1 */
        move.w  (0x2,%a4),%d1                   /* e70340  322c 0002 */
        lsr.w   #3,%d1                          /* e70344  e649 */
        adda.w  %d1,%a3                         /* e70346  d6c1 */
.Le70348:
        move.w  %d0,%d2                         /* e70348  3400 */
        .short  0xb47c, 0x0006                  /* e7034a  cmp.w #6,%d2 (<ea>=#imm form; gas: cmpi) */
        ble.b   .Le70354                        /* e7034e  6f04 */
        move.w  #6,%d2                          /* e70350  343c 0006 */
.Le70354:
        move.l  (%a2)+,(%a3)                    /* e70354  269a */
        eor.l   %d4,(%a3)+                      /* e70356  b99b */
        dbf     %d2,.Le70354                    /* e70358  51ca fffa */
        adda.w  %d6,%a3                         /* e7035c  d6c6 */
        dbf     %d3,.Le7036c                    /* e7035e  51cb 000c */
        suba.l  #28644,%a3                      /* e70362  97fc 0000 6fe4 */
        move.w  #223,%d3                        /* e70368  363c 00df */
.Le7036c:
        subq.w  #7,%d0                          /* e7036c  5f40 */
        bge.b   .Le70348                        /* e7036e  6cd8 */
        movem.l (%sp)+,%d2-%d4/%d6/%a2-%a5      /* e70370  4cdf 3c5c */
        rts                                     /* e70374  4e75 */

/*
 * 0x00E70376 - SMD_$INVERT_DISP (map symbol): (0x4,SP) the display
 * memory's base, by value; (0x8,SP) loaded into A1 and not used.  Inverts
 * the 0x1C00 longwords from base + 0x19000.
 */
SMD_$INVERT_DISP:
        movea.l (0x4,%sp),%a0                   /* e70376  206f 0004 */
        movea.l (0x8,%sp),%a1                   /* e7037a  226f 0008 */
        adda.l  #102400,%a0                     /* e7037e  d1fc 0001 9000 */
        move.w  #7167,%d0                       /* e70384  303c 1bff */
.Le70388:
        not.l   (%a0)+                          /* e70388  4698 */
        dbf     %d0,.Le70388                    /* e7038a  51c8 fffc */
        rts                                     /* e7038e  4e75 */

/*
 * 0x00E70390 - SMD_$WRITE_STR_CLIP's body (from its stub, A5 = 0x00E84934,
 * the cells reached as (d,A5): (0x14,A5) SMD_$WS_INIT, (0x18,A5)
 * SMD_$ACQ_DISPLAY, (0x1C,A5) SMD_$REL_DISPLAY, (0x24,A5)/(0x26,A5) the
 * words 1 and 0 passed by address to SMD_$ACQ_DISPLAY).  A frame of 0x2A
 * bytes below the ten saved registers; the arguments from (0x30,A6): the
 * position's address (a longword, y in its high word and x in its low), a
 * word's address, the string's address, its length's address, a
 * boolean's address and the status's address.
 * Draws the string's glyphs with the BLT one by one, clipped to the
 * context's window (+0x56..+0x5C), advancing x by each glyph's width;
 * the clipped-away remainder only advances x.
 */
smd_$write_str_clip_body:
        movem.l %d2-%d7/%a2-%a5,-(%sp)          /* e70390  48e7 3f3c */
        movea.l %a0,%a5                         /* e70394  2a48 */
        link.w  %a6,#-42                        /* e70396  4e56 ffd6 */
        movea.l (0x34,%a6),%a0                  /* e7039a  206e 0034 */
        move.w  (%a0),(-0x4,%a6)                /* e7039e  3d50 fffc */
        pea     (-0x1c,%a6)                     /* e703a2  486e ffe4 */
        movea.l (0x14,%a5),%a0                  /* e703a6  206d 0014 */
        jsr     (%a0)                           /* e703aa  4e90 */
        addq.w  #4,%sp                          /* e703ac  584f */
        movea.l (0x44,%a6),%a0                  /* e703ae  206e 0044 */
        move.l  (-0xc,%a6),(%a0)                /* e703b2  20ae fff4 */
        bne.w   .Le7069a                        /* e703b6  6600 02e2 */
        movea.l (-0x14,%a6),%a3                 /* e703ba  266e ffec */
        movea.l (-0x1c,%a6),%a2                 /* e703be  246e ffe4 */
        movea.l (0x38,%a6),%a4                  /* e703c2  286e 0038 */
        movea.l (0x3c,%a6),%a0                  /* e703c6  206e 003c */
        move.w  (%a0),%d7                       /* e703ca  3e10 */
        ble.w   .Le7069a                        /* e703cc  6f00 02cc */
        subq.w  #1,%d7                          /* e703d0  5347 */
        movea.l (0x40,%a6),%a0                  /* e703d2  206e 0040 */
        tst.b   (%a0)                           /* e703d6  4a10 */
        bmi.b   .Le703e0                        /* e703d8  6b06 */
        pea     (0x24,%a5)                      /* e703da  486d 0024 */
        bra.b   .Le703e4                        /* e703de  6004 */
.Le703e0:
        pea     (0x26,%a5)                      /* e703e0  486d 0026 */
.Le703e4:
        movea.l (0x18,%a5),%a0                  /* e703e4  206d 0018 */
        jsr     (%a0)                           /* e703e8  4e90 */
        addq.w  #4,%sp                          /* e703ea  584f */
        move.w  %d0,%d3                         /* e703ec  3600 */
        .short  0x867c, 0x800c                  /* e703ee  or.w #-32756,%d3 (<ea>=#imm form; gas: ori) */
        movea.l (0x30,%a6),%a0                  /* e703f2  206e 0030 */
        move.l  (%a0),%d5                       /* e703f6  2a10 */
        move.w  %d5,%d4                         /* e703f8  3805 */
        swap    %d5                             /* e703fa  4845 */
        addq.w  #1,%d5                          /* e703fc  5245 */
        movea.l (-0x10,%a6),%a0                 /* e703fe  206e fff0 */
        move.w  (0x56,%a0),%d0                  /* e70402  3028 0056 */
        cmp.w   (0x58,%a0),%d0                  /* e70406  b068 0058 */
        bgt.w   .Le70628                        /* e7040a  6e00 021c */
        move.w  (0x5a,%a0),%d0                  /* e7040e  3028 005a */
        cmp.w   (0x5c,%a0),%d0                  /* e70412  b068 005c */
        bgt.w   .Le70628                        /* e70416  6e00 0210 */
.Le7041a:
        clr.w   %d1                             /* e7041a  4241 */
        cmpi.w  #1,(%a2)                        /* e7041c  0c52 0001 */
        beq.b   .Le7043e                        /* e70420  671c */
        clr.l   %d0                             /* e70422  4280 */
        move.b  (%a4)+,%d0                      /* e70424  101c */
        add.l   (0x34,%a2),%d0                  /* e70426  d0aa 0034 */
        move.b  (0x0,%a2,%d0.l),%d1             /* e7042a  1232 0800 */
        beq.w   .Le706a2                        /* e7042e  6700 0272 */
        asl.w   #3,%d1                          /* e70432  e741 */
        lea     (-0x8,%a2),%a1                  /* e70434  43ea fff8 */
        adda.l  (0x38,%a2),%a1                  /* e70438  d3ea 0038 */
        bra.b   .Le70452                        /* e7043c  6014 */
.Le7043e:
        move.w  #127,%d0                        /* e7043e  303c 007f */
        and.b   (%a4)+,%d0                      /* e70442  c01c */
        move.b  (0x1a,%a2,%d0.w),%d1            /* e70444  1232 001a */
        beq.w   .Le706a2                        /* e70448  6700 0258 */
        asl.w   #3,%d1                          /* e7044c  e741 */
        lea     (0x92,%a2),%a1                  /* e7044e  43ea 0092 */
.Le70452:
        adda.w  %d1,%a1                         /* e70452  d2c1 */
        move.b  (%a1),%d1                       /* e70454  1211 */
        ext.w   %d1                             /* e70456  4881 */
        move.w  %d1,%d2                         /* e70458  3401 */
        move.w  %d4,%d0                         /* e7045a  3004 */
        sub.w   %d1,%d0                         /* e7045c  9041 */
        move.w  (0x56,%a0),%d1                  /* e7045e  3228 0056 */
        sub.w   %d0,%d1                         /* e70462  9240 */
        bgt.b   .Le70482                        /* e70464  6e1c */
        cmp.w   (0x58,%a0),%d0                  /* e70466  b068 0058 */
        ble.b   .Le7047e                        /* e7046a  6f12 */
        move.w  %d4,%d0                         /* e7046c  3004 */
        .short  0x907c, 0x007f                  /* e7046e  sub.w #127,%d0 (<ea>=#imm form; gas: subi) */
        cmp.w   (0x58,%a0),%d0                  /* e70472  b068 0058 */
        bgt.w   .Le70620                        /* e70476  6e00 01a8 */
        bra.w   .Le70602                        /* e7047a  6000 0186 */
.Le7047e:
        move.w  #0,%d1                          /* e7047e  323c 0000 */
.Le70482:
        move.w  %d1,(-0x2a,%a6)                 /* e70482  3d41 ffd6 */
        add.w   %d1,%d0                         /* e70486  d041 */
.Le70488:
        tst.w   (%a3)                           /* e70488  4a53 */
        bmi.b   .Le70488                        /* e7048a  6bfc */
        move.w  %d0,(0xe,%a3)                   /* e7048c  3740 000e */
        move.w  %d0,(-0x28,%a6)                 /* e70490  3d40 ffd8 */
        move.b  (0x1,%a1),%d1                   /* e70494  1229 0001 */
        ext.w   %d1                             /* e70498  4881 */
        subq.w  #1,%d1                          /* e7049a  5341 */
        add.w   %d1,%d2                         /* e7049c  d441 */
        add.w   %d2,%d0                         /* e7049e  d042 */
        sub.w   (-0x2a,%a6),%d0                 /* e704a0  906e ffd6 */
        cmp.w   (0x56,%a0),%d0                  /* e704a4  b068 0056 */
        blt.w   .Le70602                        /* e704a8  6d00 0158 */
        cmp.w   (0x58,%a0),%d0                  /* e704ac  b068 0058 */
        ble.b   .Le704b6                        /* e704b0  6f04 */
        move.w  (0x58,%a0),%d0                  /* e704b2  3028 0058 */
.Le704b6:
        move.w  %d0,%d2                         /* e704b6  3400 */
        .short  0xc47c, 0x000f                  /* e704b8  and.w #15,%d2 (<ea>=#imm form; gas: andi) */
        move.w  %d2,(0x2,%a3)                   /* e704bc  3742 0002 */
        move.w  %d2,(-0x22,%a6)                 /* e704c0  3d42 ffde */
        lsr.w   #4,%d0                          /* e704c4  e848 */
        move.w  (-0x28,%a6),%d2                 /* e704c6  342e ffd8 */
        lsr.w   #4,%d2                          /* e704ca  e84a */
        sub.w   %d2,%d0                         /* e704cc  9042 */
        blt.b   .Le704d2                        /* e704ce  6d02 */
        neg.w   %d0                             /* e704d0  4440 */
.Le704d2:
        subq.w  #1,%d0                          /* e704d2  5340 */
        move.w  %d0,(0xa,%a3)                   /* e704d4  3740 000a */
        move.w  %d0,(-0x26,%a6)                 /* e704d8  3d40 ffda */
        move.b  (0x2,%a1),%d1                   /* e704dc  1229 0002 */
        ext.w   %d1                             /* e704e0  4881 */
        move.w  %d5,%d0                         /* e704e2  3005 */
        sub.w   %d1,%d0                         /* e704e4  9041 */
        move.w  (0x5a,%a0),%d1                  /* e704e6  3228 005a */
        sub.w   %d0,%d1                         /* e704ea  9240 */
        bgt.b   .Le70516                        /* e704ec  6e28 */
        cmp.w   (0x5c,%a0),%d0                  /* e704ee  b068 005c */
        ble.b   .Le70512                        /* e704f2  6f1e */
        move.w  %d5,%d0                         /* e704f4  3005 */
        cmpi.w  #1,(%a2)                        /* e704f6  0c52 0001 */
        beq.b   .Le70502                        /* e704fa  6706 */
        sub.w   (0x48,%a2),%d0                  /* e704fc  906a 0048 */
        bra.b   .Le70506                        /* e70500  6004 */
.Le70502:
        sub.w   (0x16,%a2),%d0                  /* e70502  906a 0016 */
.Le70506:
        cmp.w   (0x5c,%a0),%d0                  /* e70506  b068 005c */
        bgt.w   .Le70620                        /* e7050a  6e00 0114 */
        bra.w   .Le70602                        /* e7050e  6000 00f2 */
.Le70512:
        move.w  #0,%d1                          /* e70512  323c 0000 */
.Le70516:
        add.w   %d1,%d0                         /* e70516  d041 */
        move.w  %d0,(0xc,%a3)                   /* e70518  3740 000c */
        move.w  %d0,(-0x20,%a6)                 /* e7051c  3d40 ffe0 */
        clr.w   %d2                             /* e70520  4242 */
        move.b  (0x5,%a1),%d2                   /* e70522  1429 0005 */
        add.w   (-0x6,%a6),%d2                  /* e70526  d46e fffa */
        move.w  (-0x8,%a6),%d0                  /* e7052a  302e fff8 */
        add.w   (0x6,%a1),%d0                   /* e7052e  d069 0006 */
        add.w   %d1,%d0                         /* e70532  d041 */
.Le70534:
        move.w  #1023,%d6                       /* e70534  3c3c 03ff */
        sub.w   %d0,%d6                         /* e70538  9c40 */
        bge.b   .Le70546                        /* e7053a  6c0a */
        .short  0x907c, 0x00e0                  /* e7053c  sub.w #224,%d0 (<ea>=#imm form; gas: subi) */
        .short  0xd47c, 0x00e0                  /* e70540  add.w #224,%d2 (<ea>=#imm form; gas: addi) */
        bra.b   .Le70534                        /* e70544  60ee */
.Le70546:
        add.w   (-0x2a,%a6),%d2                 /* e70546  d46e ffd6 */
        move.w  %d2,(0x6,%a3)                   /* e7054a  3742 0006 */
        move.w  %d2,(-0x1e,%a6)                 /* e7054e  3d42 ffe2 */
        move.w  %d0,(0x4,%a3)                   /* e70552  3740 0004 */
        move.b  (0x3,%a1),%d2                   /* e70556  1429 0003 */
        ext.w   %d2                             /* e7055a  4882 */
        add.w   %d5,%d2                         /* e7055c  d445 */
        subq.w  #1,%d2                          /* e7055e  5342 */
        cmp.w   (0x5a,%a0),%d2                  /* e70560  b468 005a */
        bge.b   .Le70584                        /* e70564  6c1e */
        cmpi.w  #1,(%a2)                        /* e70566  0c52 0001 */
        beq.b   .Le70572                        /* e7056a  6706 */
        move.w  (0x4a,%a2),%d2                  /* e7056c  342a 004a */
        bra.b   .Le70576                        /* e70570  6004 */
.Le70572:
        move.w  (0x18,%a2),%d2                  /* e70572  342a 0018 */
.Le70576:
        add.w   %d5,%d2                         /* e70576  d445 */
        cmp.w   (0x5a,%a0),%d2                  /* e70578  b468 005a */
        blt.w   .Le70620                        /* e7057c  6d00 00a2 */
        bra.w   .Le70602                        /* e70580  6000 0080 */
.Le70584:
        cmp.w   (0x5c,%a0),%d2                  /* e70584  b468 005c */
        ble.b   .Le7058e                        /* e70588  6f04 */
        move.w  (0x5c,%a0),%d2                  /* e7058a  3428 005c */
.Le7058e:
        move.w  (-0x20,%a6),%d0                 /* e7058e  302e ffe0 */
        sub.w   %d0,%d2                         /* e70592  9440 */
        cmp.w   %d2,%d6                         /* e70594  bc42 */
        bge.b   .Le705f0                        /* e70596  6c58 */
        add.w   %d6,%d0                         /* e70598  d046 */
        sub.w   (-0x20,%a6),%d0                 /* e7059a  906e ffe0 */
        blt.b   .Le705a2                        /* e7059e  6d02 */
        neg.w   %d0                             /* e705a0  4440 */
.Le705a2:
        subq.w  #1,%d0                          /* e705a2  5340 */
        move.w  %d0,(0x8,%a3)                   /* e705a4  3740 0008 */
        move.w  (-0x20,%a6),%d0                 /* e705a8  302e ffe0 */
        add.w   %d6,%d0                         /* e705ac  d046 */
        move.w  %d3,(%a3)                       /* e705ae  3683 */
        add.w   %d0,%d2                         /* e705b0  d440 */
        sub.w   %d6,%d2                         /* e705b2  9446 */
        addq.w  #1,%d0                          /* e705b4  5240 */
.Le705b6:
        tst.w   (%a3)                           /* e705b6  4a53 */
        bmi.b   .Le705b6                        /* e705b8  6bfc */
        move.w  %d0,(0xc,%a3)                   /* e705ba  3740 000c */
        sub.w   %d0,%d2                         /* e705be  9440 */
        blt.b   .Le705c4                        /* e705c0  6d02 */
        neg.w   %d2                             /* e705c2  4442 */
.Le705c4:
        subq.w  #1,%d2                          /* e705c4  5342 */
        move.w  %d2,(0x8,%a3)                   /* e705c6  3742 0008 */
        move.w  #800,(0x4,%a3)                  /* e705ca  377c 0320 0004 */
        move.w  (-0x1e,%a6),%d0                 /* e705d0  302e ffe2 */
        .short  0xd07c, 0x00e0                  /* e705d4  add.w #224,%d0 (<ea>=#imm form; gas: addi) */
        move.w  %d0,(0x6,%a3)                   /* e705d8  3740 0006 */
        move.w  (-0x22,%a6),(0x2,%a3)           /* e705dc  376e ffde 0002 */
        move.w  (-0x28,%a6),(0xe,%a3)           /* e705e2  376e ffd8 000e */
        move.w  (-0x26,%a6),(0xa,%a3)           /* e705e8  376e ffda 000a */
        bra.b   .Le70600                        /* e705ee  6010 */
.Le705f0:
        add.w   %d2,%d0                         /* e705f0  d042 */
        sub.w   (-0x20,%a6),%d0                 /* e705f2  906e ffe0 */
        blt.b   .Le705fa                        /* e705f6  6d02 */
        neg.w   %d0                             /* e705f8  4440 */
.Le705fa:
        subq.w  #1,%d0                          /* e705fa  5340 */
        move.w  %d0,(0x8,%a3)                   /* e705fc  3740 0008 */
.Le70600:
        move.w  %d3,(%a3)                       /* e70600  3683 */
.Le70602:
        move.b  (0x4,%a1),%d0                   /* e70602  1029 0004 */
        ext.w   %d0                             /* e70606  4880 */
        cmpi.w  #1,(%a2)                        /* e70608  0c52 0001 */
        beq.b   .Le70614                        /* e7060c  6706 */
        add.w   (0x5a,%a2),%d0                  /* e7060e  d06a 005a */
        bra.b   .Le70618                        /* e70612  6004 */
.Le70614:
        add.w   (0x10,%a2),%d0                  /* e70614  d06a 0010 */
.Le70618:
        add.w   %d0,%d4                         /* e70618  d840 */
.Le7061a:
        dbf     %d7,.Le7041a                    /* e7061a  51cf fdfe */
        bra.b   .Le7068c                        /* e7061e  606c */
.Le70620:
        cmpi.w  #1,(%a2)                        /* e70620  0c52 0001 */
        beq.b   .Le7067c                        /* e70624  6756 */
        bra.b   .Le7064c                        /* e70626  6024 */
.Le70628:
        cmpi.w  #1,(%a2)                        /* e70628  0c52 0001 */
        beq.b   .Le70660                        /* e7062c  6732 */
.Le7062e:
        clr.l   %d0                             /* e7062e  4280 */
        clr.w   %d1                             /* e70630  4241 */
        move.b  (%a4)+,%d0                      /* e70632  101c */
        move.b  (0x34,%a2,%d0.w),%d1            /* e70634  1232 0034 */
        bne.b   .Le70640                        /* e70638  6606 */
        move.w  (0x6e,%a2),%d0                  /* e7063a  302a 006e */
        bra.b   .Le70652                        /* e7063e  6012 */
.Le70640:
        asl.w   #3,%d1                          /* e70640  e741 */
        lea     (-0x8,%a2),%a1                  /* e70642  43ea fff8 */
        adda.l  (0x38,%a2),%a1                  /* e70646  d3ea 0038 */
        adda.w  %d1,%a1                         /* e7064a  d2c1 */
.Le7064c:
        move.b  (0x4,%a1),%d0                   /* e7064c  1029 0004 */
        ext.w   %d0                             /* e70650  4880 */
.Le70652:
        add.w   (0x5a,%a2),%d0                  /* e70652  d06a 005a */
        add.w   %d0,%d4                         /* e70656  d840 */
        dbf     %d7,.Le7062e                    /* e70658  51cf ffd4 */
        bra.w   .Le7068c                        /* e7065c  6000 002e */
.Le70660:
        move.w  #127,%d0                        /* e70660  303c 007f */
        and.b   (%a4)+,%d0                      /* e70664  c01c */
        clr.w   %d1                             /* e70666  4241 */
        move.b  (0x1a,%a2,%d0.w),%d1            /* e70668  1232 001a */
        bne.b   .Le70674                        /* e7066c  6606 */
        move.w  (0x12,%a2),%d0                  /* e7066e  302a 0012 */
        bra.b   .Le70682                        /* e70672  600e */
.Le70674:
        asl.w   #3,%d1                          /* e70674  e741 */
        lea     (0x92,%a2),%a1                  /* e70676  43ea 0092 */
        adda.w  %d1,%a1                         /* e7067a  d2c1 */
.Le7067c:
        move.b  (0x4,%a1),%d0                   /* e7067c  1029 0004 */
        ext.w   %d0                             /* e70680  4880 */
.Le70682:
        add.w   (0x10,%a2),%d0                  /* e70682  d06a 0010 */
        add.w   %d0,%d4                         /* e70686  d840 */
        dbf     %d7,.Le70660                    /* e70688  51cf ffd6 */
.Le7068c:
        tst.w   (%a3)                           /* e7068c  4a53 */
        bmi.b   .Le7068c                        /* e7068e  6bfc */
        move.w  %d4,-(%sp)                      /* e70690  3f04 */
        movea.l (0x1c,%a5),%a0                  /* e70692  206d 001c */
        jsr     (%a0)                           /* e70696  4e90 */
        move.w  (%sp)+,%d0                      /* e70698  301f */
.Le7069a:
        unlk    %a6                             /* e7069a  4e5e */
        movem.l (%sp)+,%d2-%d7/%a2-%a5          /* e7069c  4cdf 3cfc */
        rts                                     /* e706a0  4e75 */
.Le706a2:
        cmpi.w  #1,(%a2)                        /* e706a2  0c52 0001 */
        beq.b   .Le706b4                        /* e706a6  670c */
        add.w   (0x6e,%a2),%d4                  /* e706a8  d86a 006e */
        add.w   (0x5a,%a2),%d4                  /* e706ac  d86a 005a */
        bra.w   .Le7061a                        /* e706b0  6000 ff68 */
.Le706b4:
        add.w   (0x12,%a2),%d4                  /* e706b4  d86a 0012 */
        add.w   (0x10,%a2),%d4                  /* e706b8  d86a 0010 */
        bra.w   .Le7061a                        /* e706bc  6000 ff5c */

/*
 * 0x00E706C0 - SMD_$CLEAR_WINDOW's body (from its stub, A5 = 0x00E84934:
 * (0x32,A5) SMD_$UTIL_INIT, (0x18,A5) SMD_$ACQ_DISPLAY with (0x24,A5),
 * (0x1C,A5) SMD_$REL_DISPLAY).  A frame of 0x1C bytes below the six saved
 * registers; (0x20,A6) the window's address (two longwords), (0x24,A6)
 * the status.  Clears the window with one BLT operation.
 */
smd_$clear_window_body:
        movem.l %d5-%d7/%a2-%a3/%a5,-(%sp)      /* e706c0  48e7 0734 */
        movea.l %a0,%a5                         /* e706c4  2a48 */
        link.w  %a6,#-28                        /* e706c6  4e56 ffe4 */
        pea     (-0x1c,%a6)                     /* e706ca  486e ffe4 */
        movea.l (0x32,%a5),%a0                  /* e706ce  206d 0032 */
        jsr     (%a0)                           /* e706d2  4e90 */
        addq.w  #4,%sp                          /* e706d4  584f */
        movea.l (0x24,%a6),%a0                  /* e706d6  206e 0024 */
        move.l  (-0xc,%a6),(%a0)                /* e706da  20ae fff4 */
        bne.w   .Le70758                        /* e706de  6600 0078 */
        movea.l (0x20,%a6),%a0                  /* e706e2  206e 0020 */
        move.l  (%a0)+,%d6                      /* e706e6  2c18 */
        move.l  (%a0),%d7                       /* e706e8  2e10 */
        movea.l (-0x18,%a6),%a2                 /* e706ea  246e ffe8 */
        movea.l (-0x14,%a6),%a3                 /* e706ee  266e ffec */
        pea     (0x24,%a5)                      /* e706f2  486d 0024 */
        movea.l (0x18,%a5),%a0                  /* e706f6  206d 0018 */
        jsr     (%a0)                           /* e706fa  4e90 */
        addq.w  #4,%sp                          /* e706fc  584f */
        move.w  %d0,%d5                         /* e706fe  3a00 */
        move.w  #896,(0x6,%a3)                  /* e70700  377c 0380 0006 */
        move.w  #1023,(0x4,%a3)                 /* e70706  377c 03ff 0004 */
        move.w  %d6,%d0                         /* e7070c  3006 */
        .short  0xc07c, 0x000f                  /* e7070e  and.w #15,%d0 (<ea>=#imm form; gas: andi) */
        move.w  %d0,(0x2,%a3)                   /* e70712  3740 0002 */
        swap    %d6                             /* e70716  4846 */
        move.w  %d6,(0xe,%a3)                   /* e70718  3746 000e */
        move.w  %d6,%d0                         /* e7071c  3006 */
        lsr.w   #4,%d0                          /* e7071e  e848 */
        swap    %d6                             /* e70720  4846 */
        lsr.w   #4,%d6                          /* e70722  e84e */
        sub.w   %d0,%d6                         /* e70724  9c40 */
        blt.b   .Le7072a                        /* e70726  6d02 */
        neg.w   %d6                             /* e70728  4446 */
.Le7072a:
        subq.w  #1,%d6                          /* e7072a  5346 */
        move.w  %d6,(0xa,%a3)                   /* e7072c  3746 000a */
        move.w  %d7,%d0                         /* e70730  3007 */
        swap    %d7                             /* e70732  4847 */
        move.w  %d7,(0xc,%a3)                   /* e70734  3747 000c */
        sub.w   %d7,%d0                         /* e70738  9047 */
        blt.b   .Le7073e                        /* e7073a  6d02 */
        neg.w   %d0                             /* e7073c  4440 */
.Le7073e:
        subq.w  #1,%d0                          /* e7073e  5340 */
        move.w  %d0,(0x8,%a3)                   /* e70740  3740 0008 */
        .short  0x8a7c, 0x800e                  /* e70744  or.w #-32754,%d5 (<ea>=#imm form; gas: ori) */
        movea.l (-0x10,%a6),%a0                 /* e70748  206e fff0 */
        move.w  %d5,(%a3)                       /* e7074c  3685 */
.Le7074e:
        tst.w   (%a3)                           /* e7074e  4a53 */
        bmi.b   .Le7074e                        /* e70750  6bfc */
        movea.l (0x1c,%a5),%a0                  /* e70752  206d 001c */
        jsr     (%a0)                           /* e70756  4e90 */
.Le70758:
        unlk    %a6                             /* e70758  4e5e */
        movem.l (%sp)+,%d5-%d7/%a2-%a3/%a5      /* e7075a  4cdf 2ce0 */
        rts                                     /* e7075e  4e75 */

/*
 * 0x00E70760 - SMD_$HORIZ_LINE's body (from its stub; A0 not used).  After
 * the eight-register movem: (0x24..0x2C,SP) the addresses of y, x1 and
 * x2, (0x30,SP) the display base (loaded, not used), (0x34,SP) the BLT
 * register block, (0x38,SP) the control word's address, (0x3C,SP) loaded
 * and not used.  Sets up and starts a one-line BLT and waits for it.
 */
smd_$horiz_line_body:
        movem.l %d2-%d6/%a2-%a4,-(%sp)          /* e70760  48e7 3e38 */
        movem.l (0x24,%sp),%a2-%a4              /* e70764  4cef 1c00 0024 */
        movea.l (0x34,%sp),%a1                  /* e7076a  226f 0034 */
        move.w  (%a2),(0xc,%a1)                 /* e7076e  3352 000c */
        move.w  #-1,(0x8,%a1)                   /* e70772  337c ffff 0008 */
        move.w  (%a3),%d0                       /* e70778  3013 */
        move.w  %d0,(0xe,%a1)                   /* e7077a  3340 000e */
        move.w  (%a4),%d1                       /* e7077e  3214 */
        .short  0xc27c, 0x000f                  /* e70780  and.w #15,%d1 (<ea>=#imm form; gas: andi) */
        move.w  %d1,(0x2,%a1)                   /* e70784  3341 0002 */
        move.w  (%a4),%d1                       /* e70788  3214 */
        lsr.w   #4,%d1                          /* e7078a  e849 */
        lsr.w   #4,%d0                          /* e7078c  e848 */
        sub.w   %d0,%d1                         /* e7078e  9240 */
        blt.b   .Le70794                        /* e70790  6d02 */
        neg.w   %d1                             /* e70792  4441 */
.Le70794:
        subq.w  #1,%d1                          /* e70794  5341 */
        move.w  %d1,(0xa,%a1)                   /* e70796  3341 000a */
.Le7079a:
        move.w  #960,(0x6,%a1)                  /* e7079a  337c 03c0 0006 */
        move.w  #1023,(0x4,%a1)                 /* e707a0  337c 03ff 0004 */
        movea.l (0x30,%sp),%a2                  /* e707a6  246f 0030 */
        movea.l (0x38,%sp),%a0                  /* e707aa  206f 0038 */
        move.w  (%a0),%d0                       /* e707ae  3010 */
        .short  0x807c, 0x800e                  /* e707b0  or.w #-32754,%d0 (<ea>=#imm form; gas: ori) */
        movea.l (0x3c,%sp),%a0                  /* e707b4  206f 003c */
        move.w  %d0,(%a1)                       /* e707b8  3280 */
.Le707ba:
        tst.w   (%a1)                           /* e707ba  4a51 */
        bmi.b   .Le707ba                        /* e707bc  6bfc */
        movem.l (%sp)+,%d2-%d6/%a2-%a4          /* e707be  4cdf 1c7c */
        rts                                     /* e707c2  4e75 */

/*
 * 0x00E707C4 - SMD_$VERT_LINE's body: the same arguments with x, y1 and y2;
 * it shares SMD_$HORIZ_LINE's tail at 0x00E7079A.
 */
smd_$vert_line_body:
        movem.l %d2-%d6/%a2-%a4,-(%sp)          /* e707c4  48e7 3e38 */
        movem.l (0x24,%sp),%a2-%a4              /* e707c8  4cef 1c00 0024 */
        movea.l (0x34,%sp),%a1                  /* e707ce  226f 0034 */
        move.w  (%a2),%d0                       /* e707d2  3012 */
        move.w  %d0,(0xe,%a1)                   /* e707d4  3340 000e */
        .short  0xc07c, 0x000f                  /* e707d8  and.w #15,%d0 (<ea>=#imm form; gas: andi) */
        move.w  %d0,(0x2,%a1)                   /* e707dc  3340 0002 */
        move.w  #-1,(0xa,%a1)                   /* e707e0  337c ffff 000a */
        move.w  (%a3),%d0                       /* e707e6  3013 */
        move.w  %d0,(0xc,%a1)                   /* e707e8  3340 000c */
        sub.w   (%a4),%d0                       /* e707ec  9054 */
        blt.b   .Le707f2                        /* e707ee  6d02 */
        neg.w   %d0                             /* e707f0  4440 */
.Le707f2:
        subq.w  #1,%d0                          /* e707f2  5340 */
        move.w  %d0,(0x8,%a1)                   /* e707f4  3340 0008 */
        bra.b   .Le7079a                        /* e707f8  60a0 */
        .word   0                               /* e707fa: to the segment's end */

/* ======================================================================
 * The data segment, "D E84934 SMD_UTILS size = 54C" (.DATA),
 * 0x00E84934..0x00E84E7F.
 * ==================================================================== */
        .section ".text.SMD_$COPY_FONT_TO_HDM","ax",@progbits
        .even

        .globl  SMD_$COPY_FONT_TO_HDM
        .globl  SMD_$WRITE_STR_CLIP
        .globl  SMD_$CLEAR_WINDOW
        .globl  SMD_$HORIZ_LINE
        .globl  SMD_$VERT_LINE

SMD_$COPY_FONT_TO_HDM:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0  /* e84934  41fa fffe  A0 = 0x00E84934 */
        jmp     (smd_$copy_font_to_hdm_body).l  /* e84938  4ef9 00e702f4 */
SMD_$WRITE_STR_CLIP:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0  /* e8493e  41fa fff4  A0 = 0x00E84934 */
        jmp     (smd_$write_str_clip_body).l  /* e84942  4ef9 00e70390 */
        .long   SMD_$WS_INIT  /* e84948  00e6de58  (0x14,A5) */
        .long   SMD_$ACQ_DISPLAY  /* e8494c  00e6eb42  (0x18,A5) */
        .long   SMD_$REL_DISPLAY  /* e84950  00e6ec10  (0x1c,A5) */
        .long   SMD_$START_BLT  /* e84954  00e272bc  (0x20,A5) */
        .word   1  /* e84958  0001  (0x24,A5): SMD_$ACQ_DISPLAY's argument, by address */
        .word   0  /* e8495a  0000  (0x26,A5): its argument when WRITE_STR_CLIP's boolean is true */
SMD_$CLEAR_WINDOW:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0  /* e8495c  41fa ffd6  A0 = 0x00E84934 */
        jmp     (smd_$clear_window_body).l  /* e84960  4ef9 00e706c0 */
        .long   SMD_$UTIL_INIT  /* e84966  00e6ded4  (0x32,A5) */
SMD_$HORIZ_LINE:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0  /* e8496a  41fa ffc8  A0 = 0x00E84934 */
        jmp     (smd_$horiz_line_body).l  /* e8496e  4ef9 00e70760 */
SMD_$VERT_LINE:
        lea     (SMD_$COPY_FONT_TO_HDM:w,%pc),%a0  /* e84974  41fa ffbe  A0 = 0x00E84934 */
        jmp     (smd_$vert_line_body).l  /* e84978  4ef9 00e707c4 */
