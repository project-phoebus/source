|
| misc/sau4/disp_lites.s - DISP_LITES, the lights on the display (SAU4)
|
| SAU4 map: "D F81FFF0 DISP_LITES size = E8" (WIRED_DATA), 0xF81FFF0..
| 0xF8200D7, after the CRASH_SYSTEM module.
|
|   void DISP_LITES(uint16_t lights, uint16_t y)   0x20(SP), 0x22(SP)
|                                                  after the save
|
| The SAU4's draws the 16 lights with the first display's BLT (DISP1's
| registers +0x80..+0xB6, the longword pairs of smd/sau4/wired_proc.s)
| where the SAU2's (misc/m68k/disp_lites.s, `display_lights') writes the
| display memory word by word: at IPL 7, unless the BLT is busy (bit 15
| of DISP1's status word) or SMD_$DISPLAY_COM's word +2 is set, it saves
| the six BLT registers it uses, draws each light as a 16 x 16 square (BLT
| function 0x3C0) at x 0x30 + 0x20 per light (four rows of four from y)
| and, for a light whose bit is clear, a 14 x 14 square inside it
| (function 0x380), puts the registers back and returns at IPL 0.  The local routine at
| 0xF820090 loads one rectangle and starts the BLT (0x8003 into DISP1's
| control word), waiting for it to finish.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau4 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU4 image's.
|

        .section ".text.DISP_LITES","ax",@progbits
        .even

        .globl  DISP_LITES

DISP_LITES:
        movem.l %d2-%d7/%a2,-(%sp)              | sau4 f81fff0  48e7 3f20
        lea     (DISP1).l,%a0                   | sau4 f81fff4  41f9 0fff 9800
        ori.w   #0x700,%sr                      | sau4 f81fffa  007c 0700
        tst.w   (%a0)                           | sau4 f81fffe  4a50
        bmi.w   .Lf820086                       | sau4 f820000  6b00 0084
        lea     (SMD_$DISPLAY_COM).l,%a2        | sau4 f820004  45f9 0f82 9894
        cmpi.w  #0,(0x2,%a2)                    | sau4 f82000a  0c6a 0000 0002
        bne.s   .Lf820086                       | sau4 f820010  6674
        moveq   #48,%d6                         | sau4 f820012  7c30
        move.w  (0x22,%sp),%d7                  | sau4 f820014  3e2f 0022
        movea.l #0x2020020,%a1                  | sau4 f820018  227c 0202 0020
        move.w  (0x20,%sp),%d0                  | sau4 f82001e  302f 0020
        move.l  (0x9c,%a0),-(%sp)               | sau4 f820022  2f28 009c
        move.l  (0x94,%a0),-(%sp)               | sau4 f820026  2f28 0094
        move.l  (0x98,%a0),-(%sp)               | sau4 f82002a  2f28 0098
        move.l  (0x90,%a0),-(%sp)               | sau4 f82002e  2f28 0090
        move.l  (0x8c,%a0),-(%sp)               | sau4 f820032  2f28 008c
        move.l  (0x88,%a0),-(%sp)               | sau4 f820036  2f28 0088
        moveq   #3,%d1                          | sau4 f82003a  7203
.Lf82003c:
        moveq   #3,%d2                          | sau4 f82003c  7403
.Lf82003e:
        moveq   #15,%d3                         | sau4 f82003e  760f
        moveq   #1,%d4                          | sau4 f820040  7801
        bsr.s   .Lf820090                       | sau4 f820042  614c
        btst    #0xf,%d0                        | sau4 f820044  0800 000f
        bne.s   .Lf820058                       | sau4 f820048  660e
        addq.l  #1,%d6                          | sau4 f82004a  5286
        addq.l  #1,%d7                          | sau4 f82004c  5287
        moveq   #13,%d3                         | sau4 f82004e  760d
        moveq   #0,%d4                          | sau4 f820050  7800
        bsr.s   .Lf820090                       | sau4 f820052  613c
        subq.l  #1,%d6                          | sau4 f820054  5386
        subq.l  #1,%d7                          | sau4 f820056  5387
.Lf820058:
        rol.w   #1,%d0                          | sau4 f820058  e358
        .short  0xdcbc, 0x0000, 0x0020          | sau4 f82005a  dcbc 0000 0020  add.l   #0x20,%d6
        dbf     %d2,.Lf82003e                   | sau4 f820060  51ca ffdc
        .short  0xdcbc, 0x0000, 0x0020          | sau4 f820064  dcbc 0000 0020  add.l   #0x20,%d6
        dbf     %d1,.Lf82003c                   | sau4 f82006a  51c9 ffd0
        move.l  (%sp)+,(0x80,%a0)               | sau4 f82006e  215f 0080
        move.l  (%sp)+,(0x84,%a0)               | sau4 f820072  215f 0084
        move.l  (%sp)+,(0xb0,%a0)               | sau4 f820076  215f 00b0
        move.l  (%sp)+,(0xa8,%a0)               | sau4 f82007a  215f 00a8
        move.l  (%sp)+,(0xb4,%a0)               | sau4 f82007e  215f 00b4
        move.l  (%sp)+,(0xac,%a0)               | sau4 f820082  215f 00ac
.Lf820086:
        andi.w  #0xf8ff,%sr                     | sau4 f820086  027c f8ff
        movem.l (%sp)+,%d2-%d7/%a2              | sau4 f82008a  4cdf 04fc
        rts                                     | sau4 f82008e  4e75
.Lf820090:
        move.l  %a1,(0x84,%a0)                  | sau4 f820090  2149 0084
        move.l  %a1,(0x80,%a0)                  | sau4 f820094  2149 0080
        tst.w   %d4                             | sau4 f820098  4a44
        beq.s   .Lf8200aa                       | sau4 f82009a  670e
        move.w  #0x3c0,(0xae,%a0)               | sau4 f82009c  317c 03c0 00ae
        move.w  #0x3ff,(0xac,%a0)               | sau4 f8200a2  317c 03ff 00ac
        bra.s   .Lf8200b6                       | sau4 f8200a8  600c
.Lf8200aa:
        move.w  #0x380,(0xae,%a0)               | sau4 f8200aa  317c 0380 00ae
        move.w  #0x3ff,(0xac,%a0)               | sau4 f8200b0  317c 03ff 00ac
.Lf8200b6:
        move.w  %d6,%d5                         | sau4 f8200b6  3a06
        move.w  %d5,(0xaa,%a0)                  | sau4 f8200b8  3145 00aa
        add.w   %d3,%d5                         | sau4 f8200bc  da43
        move.w  %d5,(0xb2,%a0)                  | sau4 f8200be  3145 00b2
        move.w  %d7,%d5                         | sau4 f8200c2  3a07
        move.w  %d5,(0xa8,%a0)                  | sau4 f8200c4  3145 00a8
        add.w   %d3,%d5                         | sau4 f8200c8  da43
        move.w  %d5,(0xb0,%a0)                  | sau4 f8200ca  3145 00b0
        move.w  #0x8003,(%a0)                   | sau4 f8200ce  30bc 8003
.Lf8200d2:
        tst.w   (%a0)                           | sau4 f8200d2  4a50
        bmi.s   .Lf8200d2                       | sau4 f8200d4  6bfc
        rts                                     | sau4 f8200d6  4e75
