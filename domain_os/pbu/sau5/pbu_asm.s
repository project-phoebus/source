|
| pbu/sau5/pbu_asm.s - PBU_ASM: the PBU page's hand-written data and
| routines (the storage module command block, the PBU's flags, the
| interrupt and trap 6 entries, the DCTE table, the device-enable bits)
|
| SAU5 map: "D36 E91800 PBU_PAGE loaded at 193000, size = 770" and in it
| "D E91800 PBU_ASM size = 770": the whole of the PBU page's data
| section before the PBU_MAP code segment (PBU_WIRED_PROC), 0x770 bytes.
| Its symbols, each defined here at its offset:
|
|   +0x000  PBU_$PAGE_START   the page's first byte (a marker)
|   +0x000  SM_$CB            the storage module command block
|                             (sm/sm.ins.pas sm_$cb_t), with the four
|                             drive records' constant words and
|                             eventcounts (value 0, the waiter list
|                             empty: head = tail = the eventcount)
|   +0x074  SM_$CNT           within SM_$CB (its first drive record)
|   +0x170  PBU_$MCB          the PBU's flags word and its count of set
|                             up units (pbu/pbu.ins.pas pbu_$mcb_t), zero
|   +0x174  PBU_$INT_COM      the interrupt routine IO_$ACQUIRE is given
|                             for every PBU unit
|   +0x1B0  PBU_$ADVANCE_ONLY a unit's device routine with no user
|                             handler: "advance the eventcount"
|   +0x1B4  PBU_$IGNORE_INT   a device routine that advances nothing
|   +0x1B8  PBU_$USER_SPACE_DRIVER  a unit's device routine with a user
|                             handler: enters it in user mode
|   +0x200  PBU_$TRAP6        the trap 6 handler: the user handler's
|                             return, and the calls a handler may make
|   +0x302  PBU_$GET_DIAG_PTR FIM's question for a PBU fault
|   +0x324  PBU_$INT_FAULT_COM  a fault in a user handler: back to the
|                             interrupted kernel and a signal to the owner
|   +0x3E0  SM_BLK_HDR        the storage module's block header area,
|                             0x20 bytes, zero
|   +0x400  PBU_$DCTES        16 longwords, zero: the DCTE of each PBU
|                             unit (0..15), nil when none is set up
|   +0x440  PBU_$DCTE_TABLE   8 longwords, the addresses of the 8 DCTEs
|                             that follow (0x54 bytes each, zero)
|   +0x700  PBU_$DEVICE_INTERRUPTING  one of trap 6's calls
|   +0x744  PBU_$DISABLE_DEVICE
|   +0x75A  PBU_$ENABLE_DEVICE
|
| Hand-written (the `_ASM' segment, code in a data section: the routines
| have no frame, read their arguments off the stack, and two are entered
| by `rte' or left by it).  The register conventions:
|
| - PBU_$INT_COM is called by the bus's interrupt dispatch with the
|   unit's DCTE (its handler argument) on the stack.  It calls the DCTE's
|   device routine (+0x04) with the DCTE in A1; the routine's D0 bit 0
|   asks for the interrupt to be claimed (D0 = 0xFF), bit 1 for the
|   unit's eventcount (+0x24) to be advanced, with the DCTE's interrupt
|   flag (bit 15 of the word at +0x12) set.
| - PBU_$USER_SPACE_DRIVER saves the USP and D2-D7/A0-A6, switches to
|   the DCTE's user stack (+0x28), saves PROC1_$AS_ID and MMU_$PID_PRIV
|   and installs the owner's address space (+0x0B), saves
|   CPU_B_PBU_SWITCH and sets its bit 0, then enters the user handler
|   (+0x20) in user mode at IPL 4 through a format-0 frame.
| - PBU_$TRAP6 (vector 38): D1 = 0 with the user handler's frame on top
|   (format word 4 = the frame PBU_$USER_SPACE_DRIVER built) returns from
|   the handler: the saved state is restored, D0 is the handler's
|   answer, and PBU_$INT_COM goes on.  D1 = 1..8 calls one of the
|   table's routines with the argument count the byte table gives, the
|   arguments copied from the user stack (each one below 0x00CC0000, the
|   end of user space); D1 = 99 enters PBU_$INT_COM for the unit at
|   +4 of the user stack on the interrupt stack.  A bad USP, a bad
|   argument or another code is a fault (FIM_$GENERATE with the status:
|   "invalid usp at trap 6", "protection violation", "invalid trap 6
|   code").
| - PBU_$GET_DIAG_PTR (FIM_$BUILD_DF, fim/fim.ins.pas): the argument's
|   +0x3E is the faulting unit's DCTE; it marks the unit faulted (bit 6
|   of +0x13, PBU_$FAULTED_UNITS's test) and returns the address after
|   its CSR pages, where the fault's diagnostic frame goes.
| - PBU_$INT_FAULT_COM: entered on the interrupt stack with the saved
|   SP: restores the state PBU_$USER_SPACE_DRIVER saved and signals the
|   unit's process (DXM_$ADD_SIGNAL with the unit's address space,
|   +0x11, and the constants after the routine), then answers as
|   PBU_$ADVANCE_ONLY.
| - PBU_$DEVICE_INTERRUPTING, PBU_$DISABLE_DEVICE, PBU_$ENABLE_DEVICE:
|   two addresses, the unit and the status; the status "pbu not present"
|   when PBU_$MCB's present bit is clear, "invalid unit number" outside
|   0..15, else 0; then the unit's bit (mod 8) of PBU_CTL+2 is tested, or
|   of PBU_CTL+3 cleared or set.
|
| The SAU5's: the SAU3, SAU4, SAU6 and SAU7 maps have their own PBU_ASM
| (0x7A4, 0x744, 0x770 and 0xA64 bytes), the SAU2 and SAU9 none.  The
| Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU5 build takes
| this file.  Every byte was checked against the image by assembling and
| linking the file at the segment's address with the map's addresses
| for the other symbols (the SAU5 build is not linked yet).  Where the
| Apollo assembler encoded `cmp.w #imm,Dn' as CMP <ea>=#imm (0xB27C),
| gas would emit CMPI: those are .word.
|
        .section ".text.PBU_$PAGE_START","ax",@progbits
        .even

        .globl  PBU_$PAGE_START
        .globl  SM_$CB
        .globl  SM_$CNT
        .globl  PBU_$MCB
        .globl  PBU_$INT_COM
        .globl  PBU_$ADVANCE_ONLY
        .globl  PBU_$IGNORE_INT
        .globl  PBU_$USER_SPACE_DRIVER
        .globl  PBU_$TRAP6
        .globl  PBU_$GET_DIAG_PTR
        .globl  PBU_$INT_FAULT_COM
        .globl  SM_BLK_HDR
        .globl  PBU_$DCTES
        .globl  PBU_$DCTE_TABLE
        .globl  PBU_$DEVICE_INTERRUPTING
        .globl  PBU_$DISABLE_DEVICE
        .globl  PBU_$ENABLE_DEVICE

| One drive record's constant words and its eventcount (at +0x14 from
| the words; the record is 0x3C bytes).
        .macro  sm_drive ec
        .word   0x0337, 0x1300, 0x2012, 0x0004
        .space  0x0C
        .long   0, \ec, \ec
        .space  0x18
        .endm

PBU_$PAGE_START:                        | 0xE91800
SM_$CB:                                 | 0xE91800
        .word   0x0100, 0x0006, 0x6F40, 0x0100  | +0x000
        .word   0x001A, 0x6F40, 0x0000, 0x0100  | +0x008
        .word   0x0014, 0x6F40, 0x0004, 0x0000  | +0x010
        .word   0x0000, 0x0000, 0x0000, 0x0026  | +0x018
        .word   0x6F40                          | +0x020
        .space  0x18                            | +0x022
        .word   0x6F40                          | +0x03A
        .space  0x14                            | +0x03C
        .word   0x0000, 0x0000                  | +0x050: drive 0
        sm_drive SM_$CB+0x68                    | +0x054
        .set    SM_$CNT, SM_$CB+0x74            | 0xE91874
        .word   0x0000, 0x0000                  | +0x08C: drive 1
        sm_drive SM_$CB+0xA4                    | +0x090
        .word   0x0000, 0x0000                  | +0x0C8: drive 2
        sm_drive SM_$CB+0xE0                    | +0x0CC
        .word   0x0000, 0x0000                  | +0x104: drive 3
        sm_drive SM_$CB+0x11C                   | +0x108
        .word   0x0000, 0x0000                  | +0x140
        .word   0x0100, 0x0000, 0x000C, 0x0000  | +0x144
        .word   0x0001, 0x0200                  | +0x14C
        .space  0x20                            | +0x150

PBU_$MCB:                               | 0xE91970
        .word   0                       | the flags
        .word   0                       | the count of set up units

PBU_$INT_COM:                           | 0xE91974
        movea.l 4(%sp),%a1              | e91974  226f 0004
        move.l  %a1,-(%sp)              | e91978  2f09
        movea.l 4(%a1),%a0              | e9197a  2069 0004
        jsr     (%a0)                   | e9197e  4e90
        movea.l (%sp)+,%a1              | e91980  225f
        moveq   #0,%d1                  | e91982  7200
        lsr.w   #1,%d0                  | e91984  e248
        bcc.s   1f                      | e91986  6406
        move.l  #255,%d1                | e91988  223c 0000 00ff
1:      lsr.w   #1,%d0                  | e9198e  e248
        bcs.s   2f                      | e91990  6504
        move.l  %d1,%d0                 | e91992  2001
        rts                             | e91994  4e75
2:      movea.l 36(%a1),%a0             | e91996  2069 0024
        bset    #7,18(%a1)              | e9199a  08e9 0007 0012
        move.l  %d1,-(%sp)              | e919a0  2f01
        move.l  %a0,-(%sp)              | e919a2  2f08
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH  | e919a4  4eb9 00e2 13e0
        addq.l  #4,%sp                  | e919aa  588f
        move.l  (%sp)+,%d0              | e919ac  201f
        rts                             | e919ae  4e75

PBU_$ADVANCE_ONLY:                      | 0xE919B0
        moveq   #2,%d0                  | e919b0  7002
        rts                             | e919b2  4e75

PBU_$IGNORE_INT:                        | 0xE919B4
        clr.w   %d0                     | e919b4  4240
        rts                             | e919b6  4e75

PBU_$USER_SPACE_DRIVER:                 | 0xE919B8
        move.l  %usp,%a0                | e919b8  4e68
        movem.l %d2-%d7/%a0-%a6,-(%sp)  | e919ba  48e7 3ffe
        movea.l 40(%a1),%a0             | e919be  2069 0028
        move.l  %a0,%usp                | e919c2  4e60
        move.w  PROC1_$AS_ID,-(%sp)     | e919c4  3f39 00e2 12d2
        move.w  MMU_$PID_PRIV,-(%sp)    | e919ca  3f39 00e2 4b84
        clr.w   %d0                     | e919d0  4240
        move.b  11(%a1),%d0             | e919d2  1029 000b
        move.w  %d0,-(%sp)              | e919d6  3f00
        movea.l %a1,%a2                 | e919d8  2449
        jsr     MMU_$INSTALL_ASID       | e919da  4eb9 00e2 505c
        addq.w  #2,%sp                  | e919e0  544f
        movea.l %a2,%a1                 | e919e2  224a
        move.w  CPU_B_PBU_SWITCH,-(%sp) | e919e4  3f39 00e2 2592
        bset    #0,CPU_B_PBU_SWITCH     | e919ea  08f9 0000 00e2 2592
        movea.l 32(%a1),%a0             | e919f2  2069 0020
        clr.w   -(%sp)                  | e919f6  4267
        move.l  %a0,-(%sp)              | e919f8  2f08
        move.w  #0x400,-(%sp)           | e919fa  3f3c 0400
        rte                             | e919fe  4e73

PBU_$TRAP6:                             | 0xE91A00
        cmpi.b  #4,(%sp)                | e91a00  0c17 0004
        bne.s   .Lt6_not_return         | e91a04  667c
        tst.w   %d1                     | e91a06  4a41
        bne.s   .Lt6_call               | e91a08  6626
        ori.w   #0x700,%sr              | e91a0a  007c 0700
        addq.w  #8,%sp                  | e91a0e  504f
        move.w  (%sp)+,CPU_B_PBU_SWITCH | e91a10  33df 00e2 2592
        move.w  (%sp)+,MMU_$PID_PRIV    | e91a16  33df 00e2 4b84
        move.l  %d0,%d2                 | e91a1c  2400
        jsr     MMU_$INSTALL_ASID       | e91a1e  4eb9 00e2 505c
        addq.w  #2,%sp                  | e91a24  544f
        move.l  %d2,%d0                 | e91a26  2002
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | e91a28  4cdf 7ffc
        move.l  %a0,%usp                | e91a2c  4e60
        rts                             | e91a2e  4e75
.Lt6_call:
        .word   0xb27c,0x0008           | e91a30  cmp.w #8,%d1
        bhi.w   .Lt6_other              | e91a34  6200 0090
        move.l  %fp,-(%sp)              | e91a38  2f0e
        move.l  %d2,-(%sp)              | e91a3a  2f02
        movea.l %sp,%fp                 | e91a3c  2c4f
        move.w  %d1,%d2                 | e91a3e  3401
        lsl.w   #2,%d1                  | e91a40  e549
        movea.l (.Lt6_routines-4,%pc,%d1.w),%a0  | e91a42  207b 1046
        move.b  (.Lt6_counts,%pc,%d2.w),%d2      | e91a46  143b 2066
        move.l  %usp,%a1                | e91a4a  4e69
        move.w  %d2,%d1                 | e91a4c  3202
        lsl.w   #2,%d1                  | e91a4e  e549
        lea     8(%a1,%d1.w),%a1        | e91a50  43f1 1008
        move.l  #0x00CC0000,%d1         | e91a54  223c 00cc 0000
        cmpa.l  %d1,%a1                 | e91a5a  b3c1
        bhi.s   .Lt6_bad_usp            | e91a5c  625a
1:      move.l  -(%a1),%d0              | e91a5e  2021
        move.l  %d0,-(%sp)              | e91a60  2f00
        cmp.l   %d0,%d1                 | e91a62  b280
        dbls    %d2,1b                  | e91a64  53ca fff8
        bls.s   .Lt6_bad_arg            | e91a68  630a
        jsr     (%a0)                   | e91a6a  4e90
        movea.l %fp,%sp                 | e91a6c  2e4e
        move.l  (%sp)+,%d2              | e91a6e  241f
        movea.l (%sp)+,%fp              | e91a70  2c5f
        rte                             | e91a72  4e73
.Lt6_bad_arg:
        movea.l %fp,%sp                 | e91a74  2e4e
        move.l  (%sp)+,%d2              | e91a76  241f
        movea.l (%sp)+,%fp              | e91a78  2c5f
        move.l  #0x001E0020,-(%sp)      | e91a7a  2f3c 001e 0020
        bra.s   .Lt6_fault              | e91a80  6050
.Lt6_not_return:
        tst.w   %d1                     | e91a82  4a41
        bne.s   .Lt6_call               | e91a84  66aa
        move.l  #0x001E001E,-(%sp)      | e91a86  2f3c 001e 001e
        bra.s   .Lt6_fault              | e91a8c  6044
| The routines of trap 6's codes 1..8, and their argument counts (from
| code 0, which has none).
.Lt6_routines:
        .long   PBU2_$MAP               | e91a8e  1
        .long   PBU2_$UNMAP             | e91a92  2
        .long   PBU_$DEVICE_INTERRUPTING  | e91a96  3
        .long   PBU_$DMA_START          | e91a9a  4
        .long   PBU_$DMA_STOP           | e91a9e  5
        .long   PBU_$ADVANCE_EC_INT     | e91aa2  6
        .long   PBU2_$DMA_START         | e91aa6  7
        .long   PBU2_$DMA_STOP          | e91aaa  8
.Lt6_counts:
        .byte   0, 4, 4, 1, 6, 2, 2, 7, 2, 0    | e91aae
.Lt6_bad_usp:
        movea.l %fp,%sp                 | e91ab8  2e4e
        move.l  (%sp)+,%d2              | e91aba  241f
        movea.l (%sp)+,%fp              | e91abc  2c5f
        move.l  #0x001E001F,-(%sp)      | e91abe  2f3c 001e 001f
        bra.s   .Lt6_fault              | e91ac4  600c
.Lt6_other:
        .word   0xb27c,0x0063           | e91ac6  cmp.w #99,%d1
        beq.s   .Lt6_int                | e91aca  670c
        move.l  #0x001E001E,-(%sp)      | e91acc  2f3c 001e 001e
.Lt6_fault:
        jsr     FIM_$GENERATE           | e91ad2  4eb9 00e2 2170
.Lt6_int:
        ori.w   #0x600,%sr              | e91ad8  007c 0600
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | e91adc  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | e91ae0  4eb9 00e2 fc26
        move.l  %usp,%a0                | e91ae6  4e68
        move.w  4(%a0),%d0              | e91ae8  3028 0004
        lsl.w   #2,%d0                  | e91aec  e548
        lea     (PBU_$DCTES,%pc),%a0    | e91aee  41fa 0110
        move.l  (0,%a0,%d0.w),-(%sp)    | e91af2  2f30 0000
        jsr     (PBU_$INT_COM,%pc)      | e91af6  4eba fe7c
        addq.w  #4,%sp                  | e91afa  584f
        jmp     PROC1_$INT_EXIT         | e91afc  4ef9 00e2 15c6

PBU_$GET_DIAG_PTR:                      | 0xE91B02
        movea.l 4(%sp),%a0              | e91b02  206f 0004
        movea.l 62(%a0),%a1             | e91b06  2268 003e
        bset    #6,19(%a1)              | e91b0a  08e9 0006 0013
        clr.l   %d0                     | e91b10  4280
        move.w  52(%a1),%d0             | e91b12  3029 0034
        addq.l  #1,%d0                  | e91b16  5280
        lsl.w   #8,%d0                  | e91b18  e148
        lsl.w   #2,%d0                  | e91b1a  e548
        movea.l 44(%a1),%a0             | e91b1c  2069 002c
        adda.l  %d0,%a0                 | e91b20  d1c0
        rts                             | e91b22  4e75

PBU_$INT_FAULT_COM:                     | 0xE91B24
        addq.w  #4,%sp                  | e91b24  584f
        movea.l (%sp),%sp               | e91b26  2e57
        move.w  (%sp)+,CPU_B_PBU_SWITCH | e91b28  33df 00e2 2592
        ori.w   #0x700,%sr              | e91b2e  007c 0700
        move.w  (%sp)+,MMU_$PID_PRIV    | e91b32  33df 00e2 4b84
        jsr     MMU_$INSTALL_ASID       | e91b38  4eb9 00e2 505c
        addq.w  #2,%sp                  | e91b3e  544f
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | e91b40  4cdf 7ffc
        move.l  %a0,%usp                | e91b44  4e60
        clr.w   %d0                     | e91b46  4240
        move.b  17(%a1),%d0             | e91b48  1029 0011
        pea     (.Lfault_status,%pc)    | e91b4c  487a 0022
        move.b  (.Lfault_flag,%pc),-(%sp)       | e91b50  1f3a 002a
        move.l  (.Lfault_long,%pc),-(%sp)       | e91b54  2f3a 001e
        move.w  (.Lfault_signal,%pc),-(%sp)     | e91b58  3f3a 001e
        move.w  %d0,-(%sp)              | e91b5c  3f00
        move.w  (.Lfault_word,%pc),-(%sp)       | e91b5e  3f3a 001a
        jsr     DXM_$ADD_SIGNAL         | e91b62  4eb9 00e1 78bc
        adda.w  #16,%sp                 | e91b68  defc 0010
        bra.w   PBU_$ADVANCE_ONLY       | e91b6c  6000 fe42
| DXM_$ADD_SIGNAL's constant arguments and its status.
.Lfault_status:
        .long   0                       | e91b70
.Lfault_long:
        .long   0x00120017              | e91b74
.Lfault_signal:
        .word   0x0013                  | e91b78
.Lfault_word:
        .word   0                       | e91b7a
.Lfault_flag:
        .byte   0xFF                    | e91b7c
        .space  0x63                    | e91b7d

SM_BLK_HDR:                             | 0xE91BE0
        .space  0x20

PBU_$DCTES:                             | 0xE91C00
        .space  0x40

PBU_$DCTE_TABLE:                        | 0xE91C40
        .long   .Ldcte+0x00*0x54, .Ldcte+0x01*0x54
        .long   .Ldcte+0x02*0x54, .Ldcte+0x03*0x54
        .long   .Ldcte+0x04*0x54, .Ldcte+0x05*0x54
        .long   .Ldcte+0x06*0x54, .Ldcte+0x07*0x54
| The 8 DCTEs PBU_$SETUP hands out (pbu/pbu.ins.pas pbu_$dcte_t).
.Ldcte:                                 | 0xE91C60
        .space  8*0x54

PBU_$DEVICE_INTERRUPTING:               | 0xE91F00
        movem.l 4(%sp),%a0-%a1          | e91f00  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e91f06  6114
        beq.s   1f                      | e91f08  6704
        sf      %d0                     | e91f0a  51c0
        rts                             | e91f0c  4e75
1:      lea     PBU_CTL,%a0             | e91f0e  41f9 00ff 7c00
        btst    %d1,2(%a0)              | e91f14  0328 0002
        sne     %d0                     | e91f18  56c0
        rts                             | e91f1a  4e75
| The unit at (A0) and the status at (A1): D0 and the status "pbu not
| present", "invalid unit number" or 0, the condition codes from D0, the
| unit in D1.
.Lcheck_unit:
        moveq   #0,%d0                  | e91f1c  7000
        btst    #7,(PBU_$MCB,%pc)       | e91f1e  083a 0007 fa4e
        bne.s   1f                      | e91f24  6608
        move.l  #0x001E000A,%d0         | e91f26  203c 001e 000a
        bra.s   3f                      | e91f2c  6010
1:      move.w  (%a0),%d1               | e91f2e  3210
        bmi.s   2f                      | e91f30  6b06
        .word   0xb27c,0x000f           | e91f32  cmp.w #15,%d1
        ble.s   3f                      | e91f36  6f06
2:      move.l  #0x001E000C,%d0         | e91f38  203c 001e 000c
3:      move.l  %d0,(%a1)               | e91f3e  2280
        move.l  %d0,%d0                 | e91f40  2000
        rts                             | e91f42  4e75

PBU_$DISABLE_DEVICE:                    | 0xE91F44
        movem.l 4(%sp),%a0-%a1          | e91f44  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e91f4a  61d0
        bne.s   1f                      | e91f4c  660a
        lea     PBU_CTL,%a0             | e91f4e  41f9 00ff 7c00
        bclr    %d1,3(%a0)              | e91f54  03a8 0003
1:      rts                             | e91f58  4e75

PBU_$ENABLE_DEVICE:                     | 0xE91F5A
        movem.l 4(%sp),%a0-%a1          | e91f5a  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e91f60  61ba
        bne.s   1f                      | e91f62  660a
        lea     PBU_CTL,%a0             | e91f64  41f9 00ff 7c00
        bset    %d1,3(%a0)              | e91f6a  03e8 0003
1:      rts                             | e91f6e  4e75
