|
| color4/m68k/color4_asm.s - the hand-written COLOR4_ASM code segment:
| COLOR4_$LOAD_LUT, a color lookup table load, and the marker
| COLOR4_$END_WIRED_PROC (m68k; the SAU7, SAU8, SAU9)
|
| The map's COLOR4_ASM (0xA8 bytes, in COLOR4_WIRED_PROC after
| COLOR4_$WORTHLESS) is in the maps of the SAUs with the device-based
| display driver only (`display_devices', base/config.ins.pas); the
| other SAUs' maps have no COLOR4_ASM, so the file assembles to nothing
| there.  The SAU7's and SAU8's segments are byte for byte the SAU9's.
| The address and byte columns are the SAU9 image's.
|
| COLOR4_$LOAD_LUT(regs, first, count, colors, status), arguments off
| the stack (8,A6) .. (20,A6):
|   regs    the device's register block: its status byte at +0 (bit 0
|           busy), the table's data port at +0x401, one byte every 2
|   first   word: the first table index (its low 4 bits are used)
|   count   word: the number of entries, clipped to the 16 from first
|   colors  the entries, 4 bytes each: red, green, blue, one unused
|   status  longword, cleared
| The entries' three components, each the top 4 bits of its byte plus
| the entry's index times 16, are gathered into three rows of a 48-byte
| frame buffer; the device is polled with interrupts enabled between
| polls until it is not busy, and the three rows are written to the
| data port at +0x401, +0x403 and +0x405 with interrupts off.  A count
| of 0 (or none left after clipping) writes nothing.
|
| The Apollo assembler's <ea>=#imm forms of SUB and ADD, which gas
| spells SUBI and ADDI, are `.short' opcode words followed by their
| immediates.
|
| SAU9 map: "I 3C47CE98 COLOR4_ASM size = A8": COLOR4_$LOAD_LUT
| 0x3C47CE98, COLOR4_$END_WIRED_PROC 0x3C47CF3E.
|
        .include "base/config.inc"

        .if display_devices

        .section ".text.COLOR4_$LOAD_LUT","ax",@progbits
        .even

        .globl  COLOR4_$LOAD_LUT
        .globl  COLOR4_$END_WIRED_PROC
COLOR4_$LOAD_LUT:
        link.w  %fp,#-48                        | 3c47ce98  4e56 ffd0
        movem.l %d2-%d7/%a2,-(%sp)              | 3c47ce9c  48e7 3f20
        movea.l (20,%fp),%a1                    | 3c47cea0  226e 0014  status
        clr.l   (%a1)                           | 3c47cea4  4291
        movea.l (16,%fp),%a1                    | 3c47cea6  226e 0010  colors
        lea     (-48,%fp),%a2                   | 3c47ceaa  45ee ffd0  the rows
        move.w  (14,%fp),%d6                    | 3c47ceae  3c2e 000e  count
        beq.w   .Ldone                          | 3c47ceb2  6700 0082
        move.w  (12,%fp),%d1                    | 3c47ceb6  322e 000c  first
        andi.w  #15,%d1                         | 3c47ceba  0241 000f
        move.w  %d1,%d0                         | 3c47cebe  3001
        add.w   %d6,%d0                         | 3c47cec0  d046
        .short  0x907c; .short 0x0010           | 3c47cec2  907c 0010  sub.w #0x10,%d0, the <ea>=#imm form
        ble.w   .Lclipped                       | 3c47cec6  6f00 0008
        sub.w   %d0,%d6                         | 3c47ceca  9c40        past index 15: clip
        beq.w   .Ldone                          | 3c47cecc  6700 0068
.Lclipped:
        move.w  %d6,%d5                         | 3c47ced0  3a06
        subq.w  #1,%d5                          | 3c47ced2  5345        count - 1
        move.w  %d6,%d7                         | 3c47ced4  3e06
        asl.w   #1,%d7                          | 3c47ced6  e347        2 * count: the third row
        move.w  %d5,%d2                         | 3c47ced8  3405
.Lgather:
        move.b  (%a1)+,%d0                      | 3c47ceda  1019        red
        lsr.b   #4,%d0                          | 3c47cedc  e808
        add.b   %d1,%d0                         | 3c47cede  d001
        move.b  %d0,(%a2)                       | 3c47cee0  1480
        move.b  (%a1)+,%d0                      | 3c47cee2  1019        green
        lsr.b   #4,%d0                          | 3c47cee4  e808
        add.b   %d1,%d0                         | 3c47cee6  d001
        move.b  %d0,(0,%a2,%d6.w)               | 3c47cee8  1580 6000
        move.b  (%a1)+,%d0                      | 3c47ceec  1019        blue
        lsr.b   #4,%d0                          | 3c47ceee  e808
        add.b   %d1,%d0                         | 3c47cef0  d001
        move.b  %d0,(0,%a2,%d7.w)               | 3c47cef2  1580 7000
        addq.l  #1,%a1                          | 3c47cef6  5289        the unused byte
        addq.l  #1,%a2                          | 3c47cef8  528a
        .short  0xd23c; .short 0x0010           | 3c47cefa  d23c 0010  add.b #0x10,%d1, the <ea>=#imm form
        dbf     %d2,.Lgather                    | 3c47cefe  51ca ffda
        lea     (-48,%fp),%a2                   | 3c47cf02  45ee ffd0
        movea.l (8,%fp),%a0                     | 3c47cf06  206e 0008  regs
        movea.l %a0,%a1                         | 3c47cf0a  2248        the status byte
        lea     (1025,%a0),%a0                  | 3c47cf0c  41e8 0401  the data port
        move.w  #2,%d4                          | 3c47cf10  383c 0002  three rows
        move.w  %sr,%d3                         | 3c47cf14  40c3
.Lwait:
        move.w  %d3,%sr                         | 3c47cf16  46c3        interrupts as they were
        nop                                     | 3c47cf18  4e71
        nop                                     | 3c47cf1a  4e71
        ori.w   #0x700,%sr                      | 3c47cf1c  007c 0700
        btst    #0,(%a1)                        | 3c47cf20  0811 0000  busy?
        bne.s   .Lwait                          | 3c47cf24  66f0
.Lrow:
        move.w  %d5,%d2                         | 3c47cf26  3405
.Lbyte:
        move.b  (%a2)+,(%a0)                    | 3c47cf28  109a
        dbf     %d2,.Lbyte                      | 3c47cf2a  51ca fffc
        addq.w  #2,%a0                          | 3c47cf2e  5448
        dbf     %d4,.Lrow                       | 3c47cf30  51cc fff4
        move.w  %d3,%sr                         | 3c47cf34  46c3
.Ldone:
        movem.l (%sp)+,%d2-%d7/%a2              | 3c47cf36  4cdf 04fc
        unlk    %fp                             | 3c47cf3a  4e5e
        rts                                     | 3c47cf3c  4e75

| The end of the COLOR4 wired code: a marker on the segment's last word.
COLOR4_$END_WIRED_PROC:
        .short  0                               | 3c47cf3e  0000

        .endif
