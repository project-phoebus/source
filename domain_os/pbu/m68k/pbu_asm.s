|
| pbu/m68k/pbu_asm.s - PBU_ASM: the PBU page's hand-written data and
| routines (the PBU's flags, the interrupt and trap 6 entries, the DCTE
| table, the device-enable bits) (m68k; the SAU7, SAU8)
|
| The PBU_ASM of the SAUs whose PBU units are the AT bus's
| (`pbu_atbus_units', base/config.ins.pas); the other SAUs have their own
| (pbu/sau3, sau4, sau5), so the file assembles to nothing there.  The
| SAU7's segment is the SAU8's but for the addresses its cells and
| operands resolve to (its own symbols; PIC1 and PROT are the I/O
| definitions' absolute symbols).
|
| SAU8 map: "D44 3CA4C00 PBU_PAGE loaded at 1A7000, size = A64" and in it
| "D 3CA4C00 PBU_ASM size = A64": the whole of the PBU page's data
| section before the PBU_MAP code segment (PBU_WIRED_PROC), 0xA64 bytes.
| Its symbols, each defined here at its offset:
|
|   +0x000  PBU_$PAGE_START   the page's first byte (a marker)
|   +0x000  PBU_$MCB          the PBU's flags word and its count of set
|                             up units (pbu/pbu.ins.pas pbu_$mcb_t), zero
|   +0x004  PBU_$INT_COM      the interrupt routine IO_$ACQUIRE is given
|                             for every PBU unit
|   +0x040  PBU_$ADVANCE_ONLY a unit's device routine with no user
|                             handler: "advance the eventcount"
|   +0x044  PBU_$IGNORE_INT   a device routine that advances nothing
|   +0x048  PBU_$USER_SPACE_DRIVER  a unit's device routine with a user
|                             handler: enters it in user mode
|   +0x08C  PBU_$TRAP6        the trap 6 handler: the user handler's
|                             return, and the calls a handler may make
|   +0x188  PBU_$GET_DIAG_PTR FIM's question for a PBU fault
|   +0x1AA  PBU_$INT_FAULT_COM  a fault in a user handler: back to the
|                             interrupted kernel and a signal to the owner
|   +0x400  PBU_$DCTES        16 longwords, zero: the DCTE of each PBU
|                             unit (0..15), nil when none is set up
|   +0x440  PBU_$DCTE_TABLE   16 longwords, the addresses of the 16 DCTEs
|                             that follow (0x54 bytes each, zero)
|   +0x9C0  PBU_$DEVICE_INTERRUPTING  one of trap 6's calls
|   +0xA1A  PBU_$DISABLE_DEVICE
|   +0xA42  PBU_$ENABLE_DEVICE
|   +0xA62  PBU_$PAGE_END     the page's hand-written part's end: its
|                             last word, zero (the SAU5's mark is the
|                             first byte after the segment)
|
| The SAU5's PBU_ASM (pbu/sau5/pbu_asm.s, whose description of the
| register conventions applies) for the DN3000's AT-bus units, without the
| storage module's command block, with these differences:
| - PBU_$USER_SPACE_DRIVER enters the user handler at IPL 5 (the frame's
|   SR 0x0500) and saves no MMU_$PID_PRIV; PBU_$TRAP6 takes the handler's
|   return by that frame (SR high byte 5) and PBU_$INT_FAULT_COM restores
|   only the address space and CPU_B_PBU_SWITCH;
| - trap 6's argument limit is PROT (a fixup-table cell, 0x3CA4CDC),
|   where the SAU5 has the literal 0x00CC0000;
| - 16 DCTEs, where the SAU5 has 8;
| - PBU_$DEVICE_INTERRUPTING, PBU_$DISABLE_DEVICE, PBU_$ENABLE_DEVICE
|   reach the unit's line on the AT bus's interrupt controllers: PIC1
|   for units 0..7, PIC2 (PIC1 + 0x100) for 8..15; DEVICE_INTERRUPTING
|   reads the request register (OCW3 0x0A, then the byte at the
|   controller), DISABLE_DEVICE sets the unit's bit (mod 8) of the mask
|   register (+1) at IPL 6, ENABLE_DEVICE clears it; the unit check
|   takes unit 3 as line 2.
|
| Hand-written (the `_ASM' segment, code in a data section: the routines
| have no frame, read their arguments off the stack, and two are entered
| by `rte' or left by it).  The Apollo assembler's <ea>=#imm forms
| (cmp.w/cmp.b #imm,Dn), which gas spells cmpi, are written as `.short'.
|
| Byte gate (tools/asm_compare.py, `make TARGET_SAU=sau8 check-asm'):
| encodings identical to the image; address operands resolve to our
| objects.  The address and byte columns are the SAU8 image's.
|
        .include "base/config.inc"

        .if pbu_atbus_units

        .section ".text.PBU_$PAGE_START","ax",@progbits
        .even

        .globl  PBU_$PAGE_START
        .globl  PBU_$MCB
        .globl  PBU_$INT_COM
        .globl  PBU_$ADVANCE_ONLY
        .globl  PBU_$IGNORE_INT
        .globl  PBU_$USER_SPACE_DRIVER
        .globl  PBU_$TRAP6
        .globl  PBU_$GET_DIAG_PTR
        .globl  PBU_$INT_FAULT_COM
        .globl  PBU_$DCTES
        .globl  PBU_$DCTE_TABLE
        .globl  PBU_$DEVICE_INTERRUPTING
        .globl  PBU_$DISABLE_DEVICE
        .globl  PBU_$ENABLE_DEVICE
        .globl  PBU_$PAGE_END

PBU_$PAGE_START:
PBU_$MCB:                                       | 3ca4c00
        .word   0                               | the flags
        .word   0                               | the count of set up units
PBU_$INT_COM:
        movea.l (4,%sp),%a1                     | 3ca4c04  226f 0004
        move.l  %a1,-(%sp)                      | 3ca4c08  2f09
        movea.l (4,%a1),%a0                     | 3ca4c0a  2069 0004
        jsr     (%a0)                           | 3ca4c0e  4e90
        movea.l (%sp)+,%a1                      | 3ca4c10  225f
        moveq   #0,%d1                          | 3ca4c12  7200
        lsr.w   #1,%d0                          | 3ca4c14  e248
        bcc.s   .Lic_advance_test                       | 3ca4c16  6406
        move.l  #0xff,%d1                       | 3ca4c18  223c 0000 00ff
.Lic_advance_test:
        lsr.w   #1,%d0                          | 3ca4c1e  e248
        bcs.s   .Lic_advance                       | 3ca4c20  6504
        move.l  %d1,%d0                         | 3ca4c22  2001
        rts                                     | 3ca4c24  4e75
.Lic_advance:
        movea.l (0x24,%a1),%a0                  | 3ca4c26  2069 0024
        bset    #7,(0x12,%a1)                   | 3ca4c2a  08e9 0007 0012
        move.l  %d1,-(%sp)                      | 3ca4c30  2f01
        move.l  %a0,-(%sp)                      | 3ca4c32  2f08
        jsr     (EC_$ADVANCE_WITHOUT_DISPATCH).l | 3ca4c34  4eb9 03c2 1f50
        addq.l  #4,%sp                          | 3ca4c3a  588f
        move.l  (%sp)+,%d0                      | 3ca4c3c  201f
        rts                                     | 3ca4c3e  4e75
PBU_$ADVANCE_ONLY:
        moveq   #2,%d0                          | 3ca4c40  7002
        rts                                     | 3ca4c42  4e75
PBU_$IGNORE_INT:
        clr.w   %d0                             | 3ca4c44  4240
        rts                                     | 3ca4c46  4e75
PBU_$USER_SPACE_DRIVER:
        move.l  %usp,%a0                        | 3ca4c48  4e68
        movem.l %d2-%fp,-(%sp)                  | 3ca4c4a  48e7 3ffe
        movea.l (0x28,%a1),%a0                  | 3ca4c4e  2069 0028
        move.l  %a0,%usp                        | 3ca4c52  4e60
        move.w  (PROC1_$AS_ID).l,-(%sp)         | 3ca4c54  3f39 03c2 1e42
        clr.w   %d0                             | 3ca4c5a  4240
        move.b  (0xb,%a1),%d0                   | 3ca4c5c  1029 000b
        move.w  %d0,-(%sp)                      | 3ca4c60  3f00
        movea.l %a1,%a2                         | 3ca4c62  2449
        jsr     (MMU_$INSTALL_ASID).l           | 3ca4c64  4eb9 03c2 5ce6
        addq.w  #2,%sp                          | 3ca4c6a  544f
        movea.l %a2,%a1                         | 3ca4c6c  224a
        move.w  (CPU_B_PBU_SWITCH).l,-(%sp)     | 3ca4c6e  3f39 03c2 310a
        bset    #0,(CPU_B_PBU_SWITCH).l         | 3ca4c74  08f9 0000 03c2 310a
        movea.l (0x20,%a1),%a0                  | 3ca4c7c  2069 0020
        clr.w   -(%sp)                          | 3ca4c80  4267
        move.l  %a0,-(%sp)                      | 3ca4c82  2f08
        move.w  #0x500,-(%sp)                   | 3ca4c84  3f3c 0500
        rte                                     | 3ca4c88  4e73
        .short  0x0000                          | 3ca4c8a  0000
PBU_$TRAP6:
        cmpi.b  #5,(%sp)                        | 3ca4c8c  0c17 0005
        bne.s   .Lt6_not_return                 | 3ca4c90  6676
        tst.w   %d1                             | 3ca4c92  4a41
        bne.s   .Lt6_call                       | 3ca4c94  6620
        ori.w   #0x700,%sr                      | 3ca4c96  007c 0700
        addq.w  #8,%sp                          | 3ca4c9a  504f
        move.w  (%sp)+,(CPU_B_PBU_SWITCH).l     | 3ca4c9c  33df 03c2 310a
        move.l  %d0,%d2                         | 3ca4ca2  2400
        jsr     (MMU_$INSTALL_ASID).l           | 3ca4ca4  4eb9 03c2 5ce6
        addq.w  #2,%sp                          | 3ca4caa  544f
        move.l  %d2,%d0                         | 3ca4cac  2002
        movem.l (%sp)+,%d2-%fp                  | 3ca4cae  4cdf 7ffc
        move.l  %a0,%usp                        | 3ca4cb2  4e60
        rts                                     | 3ca4cb4  4e75
.Lt6_call:
        .short  0xb27c, 0x0008                  | 3ca4cb6  b27c 0008  cmp.w #8,%d1 (<ea>=#imm form)
        bhi.w   .Lt6_other                      | 3ca4cba  6200 0090
        move.l  %fp,-(%sp)                      | 3ca4cbe  2f0e
        move.l  %d2,-(%sp)                      | 3ca4cc0  2f02
        movea.l %sp,%fp                         | 3ca4cc2  2c4f
        move.w  %d1,%d2                         | 3ca4cc4  3401
        lsl.w   #2,%d1                          | 3ca4cc6  e549
        movea.l (.Lt6_routines-4,%pc,%d1.w),%a0 | 3ca4cc8  207b 1046
        move.b  (.Lt6_counts,%pc,%d2.w),%d2     | 3ca4ccc  143b 2066
        move.l  %usp,%a1                        | 3ca4cd0  4e69
        move.w  %d2,%d1                         | 3ca4cd2  3202
        lsl.w   #2,%d1                          | 3ca4cd4  e549
        lea     (8,%a1,%d1.w),%a1               | 3ca4cd6  43f1 1008
        move.l  #PROT,%d1                       | 3ca4cda  223c 039c 0000
        cmpa.l  %d1,%a1                         | 3ca4ce0  b3c1
        bhi.s   .Lt6_bad_usp                       | 3ca4ce2  625a
.Lt6_copy:
        move.l  -(%a1),%d0                      | 3ca4ce4  2021
        move.l  %d0,-(%sp)                      | 3ca4ce6  2f00
        cmp.l   %d0,%d1                         | 3ca4ce8  b280
        dbls    %d2,.Lt6_copy                   | 3ca4cea  53ca fff8
        bls.s   .Lt6_bad_arg                       | 3ca4cee  630a
        jsr     (%a0)                           | 3ca4cf0  4e90
        movea.l %fp,%sp                         | 3ca4cf2  2e4e
        move.l  (%sp)+,%d2                      | 3ca4cf4  241f
        movea.l (%sp)+,%fp                      | 3ca4cf6  2c5f
        rte                                     | 3ca4cf8  4e73
.Lt6_bad_arg:
        movea.l %fp,%sp                         | 3ca4cfa  2e4e
        move.l  (%sp)+,%d2                      | 3ca4cfc  241f
        movea.l (%sp)+,%fp                      | 3ca4cfe  2c5f
        move.l  #0x1e0020,-(%sp)                | 3ca4d00  2f3c 001e 0020
        bra.s   .Lt6_fault                       | 3ca4d06  6050
.Lt6_not_return:
        tst.w   %d1                             | 3ca4d08  4a41
        bne.s   .Lt6_call                       | 3ca4d0a  66aa
        move.l  #0x1e001e,-(%sp)                | 3ca4d0c  2f3c 001e 001e
        bra.s   .Lt6_fault                       | 3ca4d12  6044
.Lt6_routines:
        .long   PBU2_$MAP                       | 3ca4d14  03ca 5b46
        .long   PBU2_$UNMAP                     | 3ca4d18  03ca 5b56
        .long   PBU_$DEVICE_INTERRUPTING        | 3ca4d1c  03ca 55c0
        .long   PBU_$DMA_START                  | 3ca4d20  03ca 574c
        .long   PBU_$DMA_STOP                   | 3ca4d24  03ca 5a2c
        .long   PBU_$ADVANCE_EC_INT             | 3ca4d28  03ca 5c58
        .long   PBU2_$DMA_START                 | 3ca4d2c  03ca 5b02
        .long   PBU2_$DMA_STOP                  | 3ca4d30  03ca 5b2e
.Lt6_counts:
        .byte   0, 4, 4, 1, 6, 2, 2, 7, 2, 0    | 3ca4d34
.Lt6_bad_usp:
        movea.l %fp,%sp                         | 3ca4d3e  2e4e
        move.l  (%sp)+,%d2                      | 3ca4d40  241f
        movea.l (%sp)+,%fp                      | 3ca4d42  2c5f
        move.l  #0x1e001f,-(%sp)                | 3ca4d44  2f3c 001e 001f
        bra.s   .Lt6_fault                       | 3ca4d4a  600c
.Lt6_other:
        .short  0xb27c, 0x0063                  | 3ca4d4c  b27c 0063  cmp.w #0x63,%d1 (<ea>=#imm form)
        beq.s   .Lt6_int                       | 3ca4d50  670c
        move.l  #0x1e001e,-(%sp)                | 3ca4d52  2f3c 001e 001e
.Lt6_fault:
        jsr     (FIM_$GENERATE).l               | 3ca4d58  4eb9 03c2 2ce8
.Lt6_int:
        ori.w   #0x600,%sr                      | 3ca4d5e  007c 0600
        movem.l %d0-%d1/%a0-%a1,-(%sp)          | 3ca4d62  48e7 c0c0
        jsr     (IO_$USE_INT_STACK).l           | 3ca4d66  4eb9 03c3 1426
        move.l  %usp,%a0                        | 3ca4d6c  4e68
        move.w  (4,%a0),%d0                     | 3ca4d6e  3028 0004
        lsl.w   #2,%d0                          | 3ca4d72  e548
        lea     (PBU_$DCTES,%pc),%a0            | 3ca4d74  41fa 028a
        move.l  (0,%a0,%d0.w),-(%sp)            | 3ca4d78  2f30 0000
        jsr     (PBU_$INT_COM,%pc)              | 3ca4d7c  4eba fe86
        addq.w  #4,%sp                          | 3ca4d80  584f
        jmp     (PROC1_$INT_EXIT).l             | 3ca4d82  4ef9 03c2 2136
PBU_$GET_DIAG_PTR:
        movea.l (4,%sp),%a0                     | 3ca4d88  206f 0004
        movea.l (0x3c,%a0),%a1                  | 3ca4d8c  2268 003c
        bset    #6,(0x13,%a1)                   | 3ca4d90  08e9 0006 0013
        clr.l   %d0                             | 3ca4d96  4280
        move.w  (0x34,%a1),%d0                  | 3ca4d98  3029 0034
        addq.l  #1,%d0                          | 3ca4d9c  5280
        lsl.w   #8,%d0                          | 3ca4d9e  e148
        lsl.w   #2,%d0                          | 3ca4da0  e548
        movea.l (0x2c,%a1),%a0                  | 3ca4da2  2069 002c
        adda.l  %d0,%a0                         | 3ca4da6  d1c0
        rts                                     | 3ca4da8  4e75
PBU_$INT_FAULT_COM:
        addq.w  #4,%sp                          | 3ca4daa  584f
        movea.l (%sp),%sp                       | 3ca4dac  2e57
        move.w  (%sp)+,(CPU_B_PBU_SWITCH).l     | 3ca4dae  33df 03c2 310a
        ori.w   #0x700,%sr                      | 3ca4db4  007c 0700
        jsr     (MMU_$INSTALL_ASID).l           | 3ca4db8  4eb9 03c2 5ce6
        addq.w  #2,%sp                          | 3ca4dbe  544f
        movem.l (%sp)+,%d2-%fp                  | 3ca4dc0  4cdf 7ffc
        move.l  %a0,%usp                        | 3ca4dc4  4e60
        clr.w   %d0                             | 3ca4dc6  4240
        move.b  (0x11,%a1),%d0                  | 3ca4dc8  1029 0011
        pea     (.Lfault_status,%pc)                 | 3ca4dcc  487a 0022
        move.b  (.Lfault_flag,%pc),-(%sp)          | 3ca4dd0  1f3a 002a
        move.l  (.Lfault_long,%pc),-(%sp)          | 3ca4dd4  2f3a 001e
        move.w  (.Lfault_signal,%pc),-(%sp)          | 3ca4dd8  3f3a 001e
        move.w  %d0,-(%sp)                      | 3ca4ddc  3f00
        move.w  (.Lfault_word,%pc),-(%sp)          | 3ca4dde  3f3a 001a
        jsr     (DXM_$ADD_SIGNAL).l             | 3ca4de2  4eb9 03c1 815c
        adda.w  #0x10,%sp                       | 3ca4de8  defc 0010
        bra.w   PBU_$ADVANCE_ONLY               | 3ca4dec  6000 fe52
| DXM_$ADD_SIGNAL's constant arguments and its status.
.Lfault_status:
        .long   0                               | 3ca4df0
.Lfault_long:
        .long   0x00120017                      | 3ca4df4
.Lfault_signal:
        .word   0x0013                          | 3ca4df8
.Lfault_word:
        .word   0                               | 3ca4dfa
.Lfault_flag:
        .byte   0xFF                            | 3ca4dfc
        .space  0x203                           | 3ca4dfd  zero, to PBU_$DCTES

PBU_$DCTES:                                     | 3ca5000
        .space  0x40
PBU_$DCTE_TABLE:                                | 3ca5040
        .long   .Ldcte+0x00*0x54, .Ldcte+0x01*0x54
        .long   .Ldcte+0x02*0x54, .Ldcte+0x03*0x54
        .long   .Ldcte+0x04*0x54, .Ldcte+0x05*0x54
        .long   .Ldcte+0x06*0x54, .Ldcte+0x07*0x54
        .long   .Ldcte+0x08*0x54, .Ldcte+0x09*0x54
        .long   .Ldcte+0x0A*0x54, .Ldcte+0x0B*0x54
        .long   .Ldcte+0x0C*0x54, .Ldcte+0x0D*0x54
        .long   .Ldcte+0x0E*0x54, .Ldcte+0x0F*0x54
| The 16 DCTEs PBU_$SETUP hands out (pbu/pbu.ins.pas pbu_$dcte_t).
.Ldcte:                                         | 3ca5080
        .space  16*0x54

PBU_$DEVICE_INTERRUPTING:
        movem.l (4,%sp),%a0-%a1                 | 3ca55c0  4cef 0300 0004
        bsr.s   .Lcheck_unit                       | 3ca55c6  6120
        beq.s   .Ldi_unit                       | 3ca55c8  6704
        sf      %d0                             | 3ca55ca  51c0
        rts                                     | 3ca55cc  4e75
.Ldi_unit:
        lea     (PIC1).l,%a0                 | 3ca55ce  41f9 03ff 9000
        .short  0xb23c, 0x0007                  | 3ca55d4  b23c 0007  cmp.b #7,%d1 (<ea>=#imm form)
        ble.s   .Ldi_pic                       | 3ca55d8  6f04
        adda.w  #0x100,%a0                      | 3ca55da  d0fc 0100
.Ldi_pic:
        move.b  #0xa,(%a0)                      | 3ca55de  10bc 000a
        btst    %d1,(%a0)                       | 3ca55e2  0310
        sne     %d0                             | 3ca55e4  56c0
        rts                                     | 3ca55e6  4e75
.Lcheck_unit:
        moveq   #0,%d0                          | 3ca55e8  7000
        btst    #7,(PBU_$MCB,%pc)               | 3ca55ea  083a 0007 f612
        bne.s   .Lcu_unit                       | 3ca55f0  6608
        move.l  #0x1e000a,%d0                   | 3ca55f2  203c 001e 000a
        bra.s   .Lcu_store                       | 3ca55f8  6010
.Lcu_unit:
        move.w  (%a0),%d1                       | 3ca55fa  3210
        bmi.s   .Lcu_invalid                       | 3ca55fc  6b06
        .short  0xb27c, 0x000f                  | 3ca55fe  b27c 000f  cmp.w #0xf,%d1 (<ea>=#imm form)
        ble.s   .Lcu_store                       | 3ca5602  6f06
.Lcu_invalid:
        move.l  #0x1e000c,%d0                   | 3ca5604  203c 001e 000c
.Lcu_store:
        move.l  %d0,(%a1)                       | 3ca560a  2280
        .short  0xb27c, 0x0003                  | 3ca560c  b27c 0003  cmp.w #3,%d1 (<ea>=#imm form)
        bne.s   .Lcu_done                       | 3ca5610  6604
        move.w  #2,%d1                          | 3ca5612  323c 0002
.Lcu_done:
        move.l  %d0,%d0                         | 3ca5616  2000
        rts                                     | 3ca5618  4e75
PBU_$DISABLE_DEVICE:
        movem.l (4,%sp),%a0-%a1                 | 3ca561a  4cef 0300 0004
        bsr.s   .Lcheck_unit                       | 3ca5620  61c6
        bne.s   .Ldd_done                       | 3ca5622  661c
        lea     (PIC1).l,%a0                 | 3ca5624  41f9 03ff 9000
        .short  0xb23c, 0x0007                  | 3ca562a  b23c 0007  cmp.b #7,%d1 (<ea>=#imm form)
        ble.s   .Ldd_pic                       | 3ca562e  6f04
        adda.w  #0x100,%a0                      | 3ca5630  d0fc 0100
.Ldd_pic:
        move.w  %sr,-(%sp)                      | 3ca5634  40e7
        ori.w   #0x600,%sr                      | 3ca5636  007c 0600
        bset    %d1,(1,%a0)                     | 3ca563a  03e8 0001
        move.w  (%sp)+,%sr                      | 3ca563e  46df
.Ldd_done:
        rts                                     | 3ca5640  4e75
PBU_$ENABLE_DEVICE:
        movem.l (4,%sp),%a0-%a1                 | 3ca5642  4cef 0300 0004
        bsr.s   .Lcheck_unit                       | 3ca5648  619e
        bne.s   .Led_done                       | 3ca564a  6614
        lea     (PIC1).l,%a0                 | 3ca564c  41f9 03ff 9000
        .short  0xb23c, 0x0007                  | 3ca5652  b23c 0007  cmp.b #7,%d1 (<ea>=#imm form)
        ble.s   .Led_pic                       | 3ca5656  6f04
        adda.w  #0x100,%a0                      | 3ca5658  d0fc 0100
.Led_pic:
        bclr    %d1,(1,%a0)                     | 3ca565c  03a8 0001
.Led_done:
        rts                                     | 3ca5660  4e75
PBU_$PAGE_END:                                  | 3ca5662
        .word   0                               | to the segment's end (size A64)

        .endif
