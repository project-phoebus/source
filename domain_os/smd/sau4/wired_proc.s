/*
 * smd/sau4/wired_proc.s - the code segment of the hand-written SMD_WIRED
 * module: the cursor XOR/OR body, the scroll bodies, the main-memory
 * unwire body and the BLT body (its SMD_$LOCK_DISPLAY and SMD_$BIT_SET
 * are the shared smd/m68k/lock_display.s and smd/m68k/bit_set.s).
 *
 * Image addresses:
 *   sau4  0x0F816404  SMD_WIRED code segment (WIRED_PROC, 0x368 bytes)
 *   sau4  0x0F816404  smd_$xor_cursor_body
 *   sau4  0x0F81640E  smd_$or_cursor_body
 *   sau4  0x0F81660A  smd_$start_scroll_body
 *   sau4  0x0F81663E  smd_$continue_scroll_body
 *   sau4  0x0F816670  smd_$unwire_mm_body
 *   sau4  0x0F8166A8  SMD_$LOCK_DISPLAY (smd/m68k/lock_display.s)
 *   sau4  0x0F8166EC  SMD_$BIT_SET (smd/m68k/bit_set.s)
 *   sau4  0x0F8166F8  smd_$start_blt_body
 *
 * The SAU4's SMD_WIRED is its own code: the cursor body draws on the
 * monochrome displays through their memory and on the color board
 * (display types 3 and 4) through the board's command port, the scroll
 * and BLT bodies address the DNx60's BLT registers (offsets 0x80..0xB6,
 * longword pairs, the SAU5's layout), and the module unwires the BLT's
 * main-memory pages (`blt_main_memory', base/config.ins.pas).  The map
 * gives the segment two symbols, SMD_$LOCK_DISPLAY and SMD_$BIT_SET;
 * the bodies before and after them are reached only from the
 * trampolines in the data segment (smd/sau4/cursor_thunks.s, scroll.s,
 * unwire_mm.s, start_blt.s), which jump to them by absolute address, so
 * they are globals of ours.  The segment is four sections in the map's
 * order: .text.SMD_WIRED (the segment's start to SMD_$LOCK_DISPLAY), the
 * shared files' .text.SMD_$LOCK_DISPLAY and .text.SMD_$BIT_SET, and
 * .text.smd_$start_blt_body (to the segment's end), as the SAU5's.
 *
 * The bodies but the BLT's take the SMD_WIRED data segment's base
 * (SMD_$DISP2_INT) in A0 from their trampoline, copy it to A5 and reach
 * the segment's cells at fixed displacements from it (written as
 * numbers):
 *   +0x172  smd_$setup_scroll_blt, the base-level BLT setup entry
 *   +0x2DA  the cell holding PROC1_$SET_LOCK
 *   +0x2DE  the cell holding PROC1_$CLR_LOCK
 *   +0x2E8  the color board's cursor command blocks
 *           (smd/m68k/wired_data.s, after MATROX_$BOARD_INSTALLED)
 *   +0x41A  the cell holding WP_$UNWIRE
 *   +0x428  SMD_$CURSOR_TABLE
 *   +0x5B8  SMD_$DISPLAY_COM + 0xE0, unit 2's display record
 * Those distances hold because the data segment's sections are laid out
 * contiguously in the map's order.
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

        .globl  smd_$xor_cursor_body
        .globl  smd_$or_cursor_body
        .globl  smd_$start_scroll_body
        .globl  smd_$continue_scroll_body
        .globl  smd_$unwire_mm_body
        .globl  smd_$start_blt_body

        .section ".text.SMD_WIRED","ax",@progbits

/* SMD_$XOR_CURSOR's and SMD_$OR_CURSOR's body (D3 0 or 1): the
   arguments past the saved registers are the cursor number, the
   position, the bounds, the display record, the erase flag, the display
   memory and the controller; under lock 8 (PROC1_$SET_LOCK). */
smd_$xor_cursor_body:
        moveml %d2-%d4/%d7/%a2-%a5,%sp@-         | f816404  48e7 393c
        moveal %a0,%a5                           | f816408  2a48
        clrb %d3                                 | f81640a  4203
        bras .Lf816416                           | f81640c  6008
smd_$or_cursor_body:
        moveml %d2-%d4/%d7/%a2-%a5,%sp@-         | f81640e  48e7 393c
        moveal %a0,%a5                           | f816412  2a48
        moveq #1,%d3                             | f816414  7601
.Lf816416:
        movew #8,%sp@-                           | f816416  3f3c 0008
        moveal %a5@(0x2da),%a0                   | f81641a  206d 02da
        jsr %a0@                                 | f81641e  4e90
        addql #2,%sp                             | f816420  548f
        movew #0x28,%d0                          | f816422  303c 0028
        moveal %sp@(0x24),%a0                    | f816426  206f 0024
        muluw %a0@,%d0                           | f81642a  c0d0
        lea %a5@(0x428),%a1                      | f81642c  43ed 0428
        addaw %d0,%a1                            | f816430  d2c0
        moveal %sp@(0x28),%a0                    | f816432  206f 0028
        movel %a0@,%d0                           | f816436  2010
        moveal %sp@(0x2c),%a2                    | f816438  246f 002c
        subw %a1@(4),%d0                         | f81643c  9069 0004
        bpls .Lf816444                           | f816440  6a02
        clrw %d0                                 | f816442  4240
.Lf816444:
        movew %a2@(2),%d1                        | f816444  322a 0002
        subw %a1@,%d1                            | f816448  9251
        addqw #1,%d1                             | f81644a  5241
        cmpw %d1,%d0                             | f81644c  b041
        bles .Lf816452                           | f81644e  6f02
        movew %d1,%d0                            | f816450  3001
.Lf816452:
        swap %d0                                 | f816452  4840
        addw %a1@(6),%d0                         | f816454  d069 0006
        cmpw %a1@(2),%d0                         | f816458  b069 0002
        bges .Lf816464                           | f81645c  6c06
        movew %a1@(2),%d0                        | f81645e  3029 0002
        subqw #1,%d0                             | f816462  5340
.Lf816464:
        cmpw %a2@(6),%d0                         | f816464  b06a 0006
        bles .Lf81646e                           | f816468  6f04
        movew %a2@(6),%d0                        | f81646a  302a 0006

/* The color board (display types 3 and 4): its commands go through
   the board's port (+0x9E), each after the status word's bit 15 clears. */
.Lf81646e:
        moveal %sp@(0x30),%a0                    | f81646e  206f 0030
        cmpiw #3,%a0@                            | f816472  0c50 0003
        beqw .Lf816486                           | f816476  6700 000e
        cmpiw #4,%a0@                            | f81647a  0c50 0004
        beqw .Lf816486                           | f81647e  6700 0006
        braw .Lf8165a4                           | f816482  6000 0120
.Lf816486:
        moveal %sp@(0x3c),%a0                    | f816486  206f 003c
.Lf81648a:
        btst #5,%a0@(2)                          | f81648a  0828 0005 0002
        bnes .Lf81648a                           | f816490  66f8
        movew %a0@(0x80),%d1                     | f816492  3228 0080
        .short  0xc27c, 0x00f0 | f816496  andw #240,%d1
        .short  0xb27c, 0x00f0 | f81649a  cmpw #240,%d1
        beqs .Lf8164ac                           | f81649e  670c
        movew %a0@(0xc2),%d1                     | f8164a0  3228 00c2
        btst #2,%d1                              | f8164a4  0801 0002
        bnew .Lf816510                           | f8164a8  6600 0066
.Lf8164ac:
        movew %a1@,%a5@(0x2f6)                   | f8164ac  3b51 02f6
        movew %a1@(2),%a5@(0x2f8)                | f8164b0  3b69 0002 02f8
        subw %a1@(2),%d0                         | f8164b6  9069 0002
        lea %a5@(0x2e8),%a1                      | f8164ba  43ed 02e8
        moveal %sp@(0x34),%a0                    | f8164be  206f 0034
        tstb %a0@                                | f8164c2  4a10
        bpls .Lf8164da                           | f8164c4  6a14
        movel %d0,%a5@(0x2f2)                    | f8164c6  2b40 02f2
        movel #0x400,%a5@(0x2ee)                 | f8164ca  2b7c 0000 0400 02ee
        movew #8,%d0                             | f8164d2  303c 0008
        braw .Lf816580                           | f8164d6  6000 00a8
.Lf8164da:
        movel %d0,%a5@(0x2ee)                    | f8164da  2b40 02ee
        movel #0x400,%a5@(0x2f2)                 | f8164de  2b7c 0000 0400 02f2
        movel %d0,%a5@(0x306)                    | f8164e6  2b40 0306
        moveal %sp@(0x24),%a0                    | f8164ea  206f 0024
        movew %a0@,%d0                           | f8164ee  3010
        lslw #5,%d0                              | f8164f0  eb48
        .short  0xd07c, 0x0020 | f8164f2  addw #32,%d0
        movew %d0,%a5@(0x302)                    | f8164f6  3b40 0302
        movew %a5@(0x2f6),%a5@(0x30a)            | f8164fa  3b6d 02f6 030a
        movew %a5@(0x2f8),%a5@(0x30c)            | f816500  3b6d 02f8 030c
        .short  0x203c, 0x0000, 0x0012 | f816506  movel #18,%d0
        braw .Lf816580                           | f81650c  6000 0072
.Lf816510:
        subw %a1@(2),%d0                         | f816510  9069 0002
        addqw #1,%d0                             | f816514  5240
        moveal %sp@(0x24),%a0                    | f816516  206f 0024
        lea %a5@(0x5b8),%a2                      | f81651a  45ed 05b8
        movew %a2@(0x3a),%d1                     | f81651e  322a 003a
        cmpw %a0@,%d1                            | f816522  b250
        beqs .Lf81655e                           | f816524  6738
        moveal %sp@(0x3c),%a0                    | f816526  206f 003c
        clrl %d1                                 | f81652a  4281
        movew %a0@(0xa6),%d1                     | f81652c  3228 00a6
        .short  0xd2bc, 0x0000, 0x0040 | f816530  addl #64,%d1
        roll #1,%d1                              | f816536  e399
        addal %d1,%a0                            | f816538  d1c1
        movew %a1@,%a0@+                         | f81653a  30d1
        movew %a1@(2),%a0@+                      | f81653c  30e9 0002
        clrl %a0@+                               | f816540  4298
        movel #0x2e222222,%a0@+                  | f816542  20fc 2e22 2222
        movew #0xf,%d1                           | f816548  323c 000f
.Lf81654c:
        movew %a1@(8),%a0@+                      | f81654c  30e9 0008
        addql #2,%a1                             | f816550  5489
        dbf %d1,.Lf81654c                        | f816552  51c9 fff8
        moveal %sp@(0x24),%a0                    | f816556  206f 0024
        movew %a0@,%a2@(0x3a)                    | f81655a  3550 003a
.Lf81655e:
        lea %a5@(0x30e),%a1                      | f81655e  43ed 030e
        moveal %sp@(0x34),%a0                    | f816562  206f 0034
        tstb %a0@                                | f816566  4a10
        bpls .Lf816574                           | f816568  6a0a
        clrl %d0                                 | f81656a  4280
        movew #-0x6fff,%a5@(0x30e)               | f81656c  3b7c 9001 030e
        bras .Lf816580                           | f816572  600c
.Lf816574:
        movel %d0,%a5@(0x310)                    | f816574  2b40 0310
        movew #-0x7000,%a5@(0x30e)               | f816578  3b7c 9000 030e
        moveq #2,%d0                             | f81657e  7002
.Lf816580:
        moveal %sp@(0x3c),%a0                    | f816580  206f 003c
        moveb %a0@(0x9a),%a5@(0x2ea)             | f816584  1b68 009a 02ea
.Lf81658a:
        tstw %a0@(2)                             | f81658a  4a68 0002
        bmis .Lf81658a                           | f81658e  6bfa
        movew %a1@+,%a0@(0x9e)                   | f816590  3159 009e
        dbf %d0,.Lf81658a                        | f816594  51c8 fff4
.Lf816598:
        btst #5,%a0@(2)                          | f816598  0828 0005 0002
        bnes .Lf816598                           | f81659e  66f8
        braw .Lf8165f4                           | f8165a0  6000 0052

/* The monochrome displays: the pattern's rows XORed (D3 0) or ORed
   into the display memory, 128 bytes a row, from the bottom row up. */
.Lf8165a4:
        swap %d0                                 | f8165a4  4840
        movew #0x80,%d4                          | f8165a6  383c 0080
        movew %d0,%d1                            | f8165aa  3200
        .short  0xc27c, 0x000f | f8165ac  andw #15,%d1
        lslw #6,%d0                              | f8165b0  ed48
        lsrl #7,%d0                              | f8165b2  ee88
        lsrl #2,%d0                              | f8165b4  e488
        bclr #0,%d0                              | f8165b6  0880 0000
        moveal %sp@(0x38),%a0                    | f8165ba  206f 0038
        addal %d0,%a0                            | f8165be  d1c0
        movew %a1@(2),%d0                        | f8165c0  3029 0002
        subqw #1,%d0                             | f8165c4  5340
        lea %a1@(8),%a1                          | f8165c6  43e9 0008
        addaw %d0,%a1                            | f8165ca  d2c0
        addaw %d0,%a1                            | f8165cc  d2c0
        tstb %d3                                 | f8165ce  4a03
        bnes .Lf8165e4                           | f8165d0  6612
.Lf8165d2:
        movel %a1@,%d2                           | f8165d2  2411
        clrw %d2                                 | f8165d4  4242
        lsrl %d1,%d2                             | f8165d6  e2aa
        eorl %d2,%a0@                            | f8165d8  b590
        subaw %d4,%a0                            | f8165da  90c4
        subqw #2,%a1                             | f8165dc  5549
        dbf %d0,.Lf8165d2                        | f8165de  51c8 fff2
        bras .Lf8165f4                           | f8165e2  6010
.Lf8165e4:
        movel %a1@,%d2                           | f8165e4  2411
        clrw %d2                                 | f8165e6  4242
        lsrl %d1,%d2                             | f8165e8  e2aa
        orl %d2,%a0@                             | f8165ea  8590
        subaw %d4,%a0                            | f8165ec  90c4
        subqw #2,%a1                             | f8165ee  5549
        dbf %d0,.Lf8165e4                        | f8165f0  51c8 fff2

/* The lock released; D0 true. */
.Lf8165f4:
        st %d2                                   | f8165f4  50c2
        movew #8,%sp@-                           | f8165f6  3f3c 0008
        moveal %a5@(0x2de),%a0                   | f8165fa  206d 02de
        jsr %a0@                                 | f8165fe  4e90
        addql #2,%sp                             | f816600  548f
        movel %d2,%d0                            | f816602  2002
        moveml %sp@+,%d2-%d4/%d7/%a2-%a5         | f816604  4cdf 3c9c
        rts                                      | f816608  4e75

/* SMD_$START_SCROLL's body: the record (state 2, the run bit in the
   video flags) and the first step set up, then the BLT started. */
smd_$start_scroll_body:
        movel %a5,%sp@-                          | f81660a  2f0d
        moveal %a0,%a5                           | f81660c  2a48
        moveal %sp@(8),%a1                       | f81660e  226f 0008
        moveal %sp@(0xc),%a0                     | f816612  206f 000c
        movew #2,%a1@(2)                         | f816616  337c 0002 0002
        oriw #0x20,%a1@(0x22)                    | f81661c  0069 0020 0022
        clrw %a1@(0x20)                          | f816622  4269 0020
        movel %a1@(0x10),%a1@(0x1c)              | f816626  2369 0010 001c
        jsr %a5@(0x172)                          | f81662c  4ead 0172
        movew %a1@(0x22),%d0                     | f816630  3029 0022
        .short  0x807c, 0x8010 | f816634  orw #-32752,%d0
        movew %d0,%a0@                           | f816638  3080
        moveal %sp@+,%a5                         | f81663a  2a5f
        rts                                      | f81663c  4e75

/* SMD_$CONTINUE_SCROLL's body: state 3 when no step is pending, else
   the next step started. */
smd_$continue_scroll_body:
        movel %a5,%sp@-                          | f81663e  2f0d
        moveal %a0,%a5                           | f816640  2a48
        moveal %sp@(8),%a1                       | f816642  226f 0008
        moveal %sp@(0xc),%a0                     | f816646  206f 000c
        tstw %a1@(0x24)                          | f81664a  4a69 0024
        bnes .Lf81665a                           | f81664e  660a
        movew #3,%a1@(2)                         | f816650  337c 0003 0002
.Lf816656:
        moveal %sp@+,%a5                         | f816656  2a5f
        rts                                      | f816658  4e75
.Lf81665a:
        jsr %a5@(0x172)                          | f81665a  4ead 0172
        movew %a1@(0x22),%d0                     | f81665e  3029 0022
        .short  0x807c, 0x8010 | f816662  orw #-32752,%d0
        movew %d0,%a0@                           | f816666  3080
        movew #2,%a1@(2)                         | f816668  337c 0002 0002
        bras .Lf816656                           | f81666e  60e6

/* SMD_$UNWIRE_MM's body: 1 to the controller's first word, then each
   of the record's mm_page_count pages (+0xDE, from +0x40) unwired
   (WP_$UNWIRE through the cell), the count cleared first. */
smd_$unwire_mm_body:
        moveml %d2/%a4-%a5,%sp@-                 | f816670  48e7 200c
        moveal %a0,%a5                           | f816674  2a48
        moveal %sp@(0x14),%a0                    | f816676  206f 0014
        movew #1,%a0@                            | f81667a  30bc 0001
        moveal %sp@(0x10),%a0                    | f81667e  206f 0010
        movew %a0@(0xde),%d2                     | f816682  3428 00de
        bles .Lf8166a2                           | f816686  6f1a
        subql #1,%d2                             | f816688  5382
        clrw %a0@(0xde)                          | f81668a  4268 00de
        lea %a0@(0x40),%a4                       | f81668e  49e8 0040
        subqw #4,%sp                             | f816692  594f
.Lf816694:
        movel %a4@+,%sp@                         | f816694  2e9c
        moveal %a5@(0x41a),%a0                   | f816696  206d 041a
        jsr %a0@                                 | f81669a  4e90
        dbf %d2,.Lf816694                        | f81669c  51ca fff6
        addqw #4,%sp                             | f8166a0  584f
.Lf8166a2:
        moveml %sp@+,%d2/%a4-%a5                 | f8166a2  4cdf 3004
        rts                                      | f8166a6  4e75
        .section ".text.smd_$start_blt_body","ax",@progbits

/* SMD_$START_BLT's body: the request's corners into the BLT registers,
   its mode with the record's video flags; an interrupt-driven BLT puts
   the record in state 1, a synchronous one is waited for. */
smd_$start_blt_body:
        moveml %a2,%sp@-                         | f8166f8  48e7 0020
        moveal %sp@(8),%a0                       | f8166fc  206f 0008
        moveal %sp@(0xc),%a2                     | f816700  246f 000c
        moveal %sp@(0x10),%a1                    | f816704  226f 0010
        movel %a0@(2),%a1@(0x84)                 | f816708  2368 0002 0084
        movel %a0@(6),%a1@(0x80)                 | f81670e  2368 0006 0080
        movel %a0@(0xa),%a1@(0xac)               | f816714  2368 000a 00ac
        movel %a0@(0xe),%a1@(0xa8)               | f81671a  2368 000e 00a8
        movel %a0@(0x12),%a1@(0xb4)              | f816720  2368 0012 00b4
        movel %a0@(0x16),%a1@(0xb0)              | f816726  2368 0016 00b0
        movew %a0@,%d0                           | f81672c  3010
        .short  0xc07c, 0xffde | f81672e  andw #-34,%d0
        orw %a2@(0x22),%d0                       | f816732  806a 0022
        btst #4,%d0                              | f816736  0800 0004
        beqs .Lf81674c                           | f81673a  6710
        movew #1,%a2@(2)                         | f81673c  357c 0001 0002
        clrw %a2@(0x20)                          | f816742  426a 0020
        movel %a2@(0x10),%a2@(0x1c)              | f816746  256a 0010 001c
.Lf81674c:
        btst #7,%d0                              | f81674c  0800 0007
        beqs .Lf81675a                           | f816750  6708
        movew %d0,%d1                            | f816752  3200
        .short  0xc27c, 0x0081 | f816754  andw #129,%d1
        movew %d1,%a1@                           | f816758  3281
.Lf81675a:
        movew %d0,%a1@                           | f81675a  3280
        btst #4,%d0                              | f81675c  0800 0004
        bnes .Lf816766                           | f816760  6604
.Lf816762:
        tstw %a1@                                | f816762  4a51
        bmis .Lf816762                           | f816764  6bfc
.Lf816766:
        moveml %sp@+,%a2                         | f816766  4cdf 0400
        rts                                      | f81676a  4e75
