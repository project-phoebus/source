|
| pbu/sau6/pbu_asm.s - PBU_ASM: the PBU page's hand-written data and
| routines (the storage module command block, the PBU's flags, the
| interrupt and trap 6 entries, the DCTE table, the device-enable bits)
|
| SAU6 map: "D38 780A6C00 PBU_PAGE loaded at 10C5800, size = 770" and in
| it "D 780A6C00 PBU_ASM size = 770": the whole of the PBU page's data
| section before the PBU_MAP code segment (PBU_WIRED_PROC), 0x770 bytes.
| The SAU5's (pbu/sau5/pbu_asm.s) for the region-register MMU, as the
| SAU4's (pbu/sau4/pbu_asm.s): no MMU_$PID_PRIV saved or restored, the
| faulting DCTE at the diagnostic frame's +0x3C, PBU_$TRAP6 on a
| longword, and the end of user space 0x77FC0000.  The 16 units, the
| user handler's IPL 4 and the device-enable bits at PBU_CTL+2 and
| PBU_CTL+3 are the SAU5's.  Its symbols, each defined here at its
| offset:
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
|   +0x1FC  PBU_$TRAP6        the trap 6 handler: the user handler's
|                             return, and the calls a handler may make
|   +0x2F8  PBU_$GET_DIAG_PTR FIM's question for a PBU fault
|   +0x31A  PBU_$INT_FAULT_COM  a fault in a user handler: back to the
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
|   the DCTE's user stack (+0x28), saves PROC1_$AS_ID and installs the
|   owner's address space (+0x0B), saves CPU_B_PBU_SWITCH and sets its
|   bit 0, then enters the user handler (+0x20) in user mode at IPL 4
|   through a format-0 frame.
| - PBU_$TRAP6 (vector 38): D1 = 0 with the user handler's frame on top
|   (format word 4 = the frame PBU_$USER_SPACE_DRIVER built) returns from
|   the handler: the saved state is restored, D0 is the handler's
|   answer, and PBU_$INT_COM goes on.  D1 = 1..8 calls one of the
|   table's routines with the argument count the byte table gives, the
|   arguments copied from the user stack (each one below 0x77FC0000, the
|   end of user space); D1 = 99 enters PBU_$INT_COM for the unit at
|   +4 of the user stack on the interrupt stack.  A bad USP, a bad
|   argument or another code is a fault (FIM_$GENERATE with the status:
|   "invalid usp at trap 6", "protection violation", "invalid trap 6
|   code").
| - PBU_$GET_DIAG_PTR (FIM_$BUILD_DF, fim/fim.ins.pas): the argument's
|   +0x3C is the faulting unit's DCTE; it marks the unit faulted (bit 6
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
| The SAU6's: the SAU3, SAU4, SAU5 and SAU7 maps have their own PBU_ASM
| (0x7A4, 0x744, 0x770 and 0xA64 bytes), the SAU2 and SAU9 none.  The
| Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU6 build takes
| this file.  Every byte was checked against the image by assembling
| the file (m68k-elf-as -m68020) and linking it alone at the segment's
| address with the map's addresses for the other symbols (the SAU6
| build is not linked yet).  Where the Apollo assembler encoded `cmp.w
| #imm,Dn' as CMP <ea>=#imm (0xB27C), gas would emit CMPI: those are
| .word.
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

PBU_$PAGE_START:                        | 0x780A6C00
SM_$CB:                                 | 0x780A6C00
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
        .set    SM_$CNT, SM_$CB+0x74            | 0x780A6C74
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

PBU_$MCB:                               | 0x780A6D70
        .word   0                       | the flags
        .word   0                       | the count of set up units

PBU_$INT_COM:                           | 0x780A6D74
        movea.l 4(%sp),%a1              | 780a6d74  226f 0004
        move.l  %a1,-(%sp)              | 780a6d78  2f09
        movea.l 4(%a1),%a0              | 780a6d7a  2069 0004
        jsr     (%a0)                   | 780a6d7e  4e90
        movea.l (%sp)+,%a1              | 780a6d80  225f
        moveq   #0,%d1                  | 780a6d82  7200
        lsr.w   #1,%d0                  | 780a6d84  e248
        bcc.s   1f                      | 780a6d86  6406
        move.l  #255,%d1                | 780a6d88  223c 0000 00ff
1:      lsr.w   #1,%d0                  | 780a6d8e  e248
        bcs.s   2f                      | 780a6d90  6504
        move.l  %d1,%d0                 | 780a6d92  2001
        rts                             | 780a6d94  4e75
2:      movea.l 36(%a1),%a0             | 780a6d96  2069 0024
        bset    #7,18(%a1)              | 780a6d9a  08e9 0007 0012
        move.l  %d1,-(%sp)              | 780a6da0  2f01
        move.l  %a0,-(%sp)              | 780a6da2  2f08
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH  | 780a6da4  4eb9 7802 2cb8
        addq.l  #4,%sp                  | 780a6daa  588f
        move.l  (%sp)+,%d0              | 780a6dac  201f
        rts                             | 780a6dae  4e75

PBU_$ADVANCE_ONLY:                      | 0x780A6DB0
        moveq   #2,%d0                  | 780a6db0  7002
        rts                             | 780a6db2  4e75

PBU_$IGNORE_INT:                        | 0x780A6DB4
        clr.w   %d0                     | 780a6db4  4240
        rts                             | 780a6db6  4e75

PBU_$USER_SPACE_DRIVER:                 | 0x780A6DB8
        move.l  %usp,%a0                | 780a6db8  4e68
        movem.l %d2-%d7/%a0-%a6,-(%sp)  | 780a6dba  48e7 3ffe
        movea.l 40(%a1),%a0             | 780a6dbe  2069 0028
        move.l  %a0,%usp                | 780a6dc2  4e60
        move.w  PROC1_$AS_ID,-(%sp)     | 780a6dc4  3f39 7802 2baa
        clr.w   %d0                     | 780a6dca  4240
        move.b  11(%a1),%d0             | 780a6dcc  1029 000b
        move.w  %d0,-(%sp)              | 780a6dd0  3f00
        movea.l %a1,%a2                 | 780a6dd2  2449
        jsr     MMU_$INSTALL_ASID       | 780a6dd4  4eb9 7802 6cea
        addq.w  #2,%sp                  | 780a6dda  544f
        movea.l %a2,%a1                 | 780a6ddc  224a
        move.w  CPU_B_PBU_SWITCH,-(%sp) | 780a6dde  3f39 7802 3ece
        bset    #0,CPU_B_PBU_SWITCH     | 780a6de4  08f9 0000 7802 3ece
        movea.l 32(%a1),%a0             | 780a6dec  2069 0020
        clr.w   -(%sp)                  | 780a6df0  4267
        move.l  %a0,-(%sp)              | 780a6df2  2f08
        move.w  #0x400,-(%sp)           | 780a6df4  3f3c 0400
        rte                             | 780a6df8  4e73
        .word   0                       | a zero word: PBU_$TRAP6 is on a longword

PBU_$TRAP6:                             | 0x780A6DFC
        cmpi.b  #4,(%sp)                | 780a6dfc  0c17 0004
        bne.s   .Lt6_not_return         | 780a6e00  6676
        tst.w   %d1                     | 780a6e02  4a41
        bne.s   .Lt6_call               | 780a6e04  6620
        ori.w   #0x700,%sr              | 780a6e06  007c 0700
        addq.w  #8,%sp                  | 780a6e0a  504f
        move.w  (%sp)+,CPU_B_PBU_SWITCH | 780a6e0c  33df 7802 3ece
        move.l  %d0,%d2                 | 780a6e12  2400
        jsr     MMU_$INSTALL_ASID       | 780a6e14  4eb9 7802 6cea
        addq.w  #2,%sp                  | 780a6e1a  544f
        move.l  %d2,%d0                 | 780a6e1c  2002
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | 780a6e1e  4cdf 7ffc
        move.l  %a0,%usp                | 780a6e22  4e60
        rts                             | 780a6e24  4e75
.Lt6_call:
        .word   0xb27c,0x0008           | 780a6e26  cmp.w #8,%d1
        bhi.w   .Lt6_other              | 780a6e2a  6200 0090
        move.l  %fp,-(%sp)              | 780a6e2e  2f0e
        move.l  %d2,-(%sp)              | 780a6e30  2f02
        movea.l %sp,%fp                 | 780a6e32  2c4f
        move.w  %d1,%d2                 | 780a6e34  3401
        lsl.w   #2,%d1                  | 780a6e36  e549
        movea.l (.Lt6_routines-4,%pc,%d1.w),%a0  | 780a6e38  207b 1046
        move.b  (.Lt6_counts,%pc,%d2.w),%d2      | 780a6e3c  143b 2066
        move.l  %usp,%a1                | 780a6e40  4e69
        move.w  %d2,%d1                 | 780a6e42  3202
        lsl.w   #2,%d1                  | 780a6e44  e549
        lea     8(%a1,%d1.w),%a1        | 780a6e46  43f1 1008
        move.l  #0x77FC0000,%d1         | 780a6e4a  223c 77fc 0000
        cmpa.l  %d1,%a1                 | 780a6e50  b3c1
        bhi.s   .Lt6_bad_usp            | 780a6e52  625a
1:      move.l  -(%a1),%d0              | 780a6e54  2021
        move.l  %d0,-(%sp)              | 780a6e56  2f00
        cmp.l   %d0,%d1                 | 780a6e58  b280
        dbls    %d2,1b                  | 780a6e5a  53ca fff8
        bls.s   .Lt6_bad_arg            | 780a6e5e  630a
        jsr     (%a0)                   | 780a6e60  4e90
        movea.l %fp,%sp                 | 780a6e62  2e4e
        move.l  (%sp)+,%d2              | 780a6e64  241f
        movea.l (%sp)+,%fp              | 780a6e66  2c5f
        rte                             | 780a6e68  4e73
.Lt6_bad_arg:
        movea.l %fp,%sp                 | 780a6e6a  2e4e
        move.l  (%sp)+,%d2              | 780a6e6c  241f
        movea.l (%sp)+,%fp              | 780a6e6e  2c5f
        move.l  #0x001E0020,-(%sp)      | 780a6e70  2f3c 001e 0020
        bra.s   .Lt6_fault              | 780a6e76  6050
.Lt6_not_return:
        tst.w   %d1                     | 780a6e78  4a41
        bne.s   .Lt6_call               | 780a6e7a  66aa
        move.l  #0x001E001E,-(%sp)      | 780a6e7c  2f3c 001e 001e
        bra.s   .Lt6_fault              | 780a6e82  6044
| The routines of trap 6's codes 1..8, and their argument counts (from
| code 0, which has none).
.Lt6_routines:
        .long   PBU2_$MAP               | 780a6e84  780a 7464
        .long   PBU2_$UNMAP             | 780a6e88  780a 75a6
        .long   PBU_$DEVICE_INTERRUPTING  | 780a6e8c  780a 7300
        .long   PBU_$DMA_START          | 780a6e90  780a 7404
        .long   PBU_$DMA_STOP           | 780a6e94  780a 7416
        .long   PBU_$ADVANCE_EC_INT     | 780a6e98  780a 779c
        .long   PBU2_$DMA_START         | 780a6e9c  780a 743c
        .long   PBU2_$DMA_STOP          | 780a6ea0  780a 744e
.Lt6_counts:
        .byte   0, 4, 4, 1, 6, 2, 2, 7, 2, 0    | 780a6ea4
.Lt6_bad_usp:
        movea.l %fp,%sp                 | 780a6eae  2e4e
        move.l  (%sp)+,%d2              | 780a6eb0  241f
        movea.l (%sp)+,%fp              | 780a6eb2  2c5f
        move.l  #0x001E001F,-(%sp)      | 780a6eb4  2f3c 001e 001f
        bra.s   .Lt6_fault              | 780a6eba  600c
.Lt6_other:
        .word   0xb27c,0x0063           | 780a6ebc  cmp.w #99,%d1
        beq.s   .Lt6_int                | 780a6ec0  670c
        move.l  #0x001E001E,-(%sp)      | 780a6ec2  2f3c 001e 001e
.Lt6_fault:
        jsr     FIM_$GENERATE           | 780a6ec8  4eb9 7802 3a48
.Lt6_int:
        ori.w   #0x600,%sr              | 780a6ece  007c 0600
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | 780a6ed2  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | 780a6ed6  4eb9 7803 7026
        move.l  %usp,%a0                | 780a6edc  4e68
        move.w  4(%a0),%d0              | 780a6ede  3028 0004
        lsl.w   #2,%d0                  | 780a6ee2  e548
        lea     (PBU_$DCTES,%pc),%a0    | 780a6ee4  41fa 011a
        move.l  (0,%a0,%d0.w),-(%sp)    | 780a6ee8  2f30 0000
        jsr     (PBU_$INT_COM,%pc)      | 780a6eec  4eba fe86
        addq.w  #4,%sp                  | 780a6ef0  584f
        jmp     PROC1_$INT_EXIT         | 780a6ef2  4ef9 7802 2e9e

PBU_$GET_DIAG_PTR:                      | 0x780A6EF8
        movea.l 4(%sp),%a0              | 780a6ef8  206f 0004
        movea.l 60(%a0),%a1             | 780a6efc  2268 003c
        bset    #6,19(%a1)              | 780a6f00  08e9 0006 0013
        clr.l   %d0                     | 780a6f06  4280
        move.w  52(%a1),%d0             | 780a6f08  3029 0034
        addq.l  #1,%d0                  | 780a6f0c  5280
        lsl.w   #8,%d0                  | 780a6f0e  e148
        lsl.w   #2,%d0                  | 780a6f10  e548
        movea.l 44(%a1),%a0             | 780a6f12  2069 002c
        adda.l  %d0,%a0                 | 780a6f16  d1c0
        rts                             | 780a6f18  4e75

PBU_$INT_FAULT_COM:                     | 0x780A6F1A
        addq.w  #4,%sp                  | 780a6f1a  584f
        movea.l (%sp),%sp               | 780a6f1c  2e57
        move.w  (%sp)+,CPU_B_PBU_SWITCH | 780a6f1e  33df 7802 3ece
        ori.w   #0x700,%sr              | 780a6f24  007c 0700
        jsr     MMU_$INSTALL_ASID       | 780a6f28  4eb9 7802 6cea
        addq.w  #2,%sp                  | 780a6f2e  544f
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | 780a6f30  4cdf 7ffc
        move.l  %a0,%usp                | 780a6f34  4e60
        clr.w   %d0                     | 780a6f36  4240
        move.b  17(%a1),%d0             | 780a6f38  1029 0011
        pea     (.Lfault_status,%pc)    | 780a6f3c  487a 0022
        move.b  (.Lfault_flag,%pc),-(%sp)       | 780a6f40  1f3a 002a
        move.l  (.Lfault_long,%pc),-(%sp)       | 780a6f44  2f3a 001e
        move.w  (.Lfault_signal,%pc),-(%sp)     | 780a6f48  3f3a 001e
        move.w  %d0,-(%sp)              | 780a6f4c  3f00
        move.w  (.Lfault_word,%pc),-(%sp)       | 780a6f4e  3f3a 001a
        jsr     DXM_$ADD_SIGNAL         | 780a6f52  4eb9 7801 7cc0
        adda.w  #16,%sp                 | 780a6f58  defc 0010
        bra.w   PBU_$ADVANCE_ONLY       | 780a6f5c  6000 fe52
| DXM_$ADD_SIGNAL's constant arguments and its status.
.Lfault_status:
        .long   0                       | 780a6f60
.Lfault_long:
        .long   0x00120017              | 780a6f64
.Lfault_signal:
        .word   0x0013                  | 780a6f68
.Lfault_word:
        .word   0                       | 780a6f6a
.Lfault_flag:
        .byte   0xFF                    | 780a6f6c
        .space  0x73

SM_BLK_HDR:                             | 0x780A6FE0
        .space  0x20

PBU_$DCTES:                             | 0x780A7000
        .space  0x40

PBU_$DCTE_TABLE:                        | 0x780A7040
        .long   .Ldcte+0x00*0x54, .Ldcte+0x01*0x54
        .long   .Ldcte+0x02*0x54, .Ldcte+0x03*0x54
        .long   .Ldcte+0x04*0x54, .Ldcte+0x05*0x54
        .long   .Ldcte+0x06*0x54, .Ldcte+0x07*0x54
| The 8 DCTEs PBU_$SETUP hands out (pbu/pbu.ins.pas pbu_$dcte_t).
.Ldcte:                                 | 0x780A7060
        .space  8*0x54

PBU_$DEVICE_INTERRUPTING:               | 0x780A7300
        movem.l 4(%sp),%a0-%a1          | 780a7300  4cef 0300 0004
        bsr.s   .Lcheck_unit            | 780a7306  6114
        beq.s   1f                      | 780a7308  6704
        sf      %d0                     | 780a730a  51c0
        rts                             | 780a730c  4e75
1:      lea     PBU_CTL,%a0             | 780a730e  41f9 7fff 7c00
        btst    %d1,2(%a0)              | 780a7314  0328 0002
        sne     %d0                     | 780a7318  56c0
        rts                             | 780a731a  4e75
| The unit at (A0) and the status at (A1): D0 and the status "pbu not
| present", "invalid unit number" or 0, the condition codes from D0, the
| unit in D1.
.Lcheck_unit:
        moveq   #0,%d0                  | 780a731c  7000
        btst    #7,(PBU_$MCB,%pc)       | 780a731e  083a 0007 fa4e
        bne.s   1f                      | 780a7324  6608
        move.l  #0x001E000A,%d0         | 780a7326  203c 001e 000a
        bra.s   3f                      | 780a732c  6010
1:      move.w  (%a0),%d1               | 780a732e  3210
        bmi.s   2f                      | 780a7330  6b06
        .word   0xb27c,0x000f           | 780a7332  cmp.w #15,%d1
        ble.s   3f                      | 780a7336  6f06
2:      move.l  #0x001E000C,%d0         | 780a7338  203c 001e 000c
3:      move.l  %d0,(%a1)               | 780a733e  2280
        move.l  %d0,%d0                 | 780a7340  2000
        rts                             | 780a7342  4e75

PBU_$DISABLE_DEVICE:                    | 0x780A7344
        movem.l 4(%sp),%a0-%a1          | 780a7344  4cef 0300 0004
        bsr.s   .Lcheck_unit            | 780a734a  61d0
        bne.s   1f                      | 780a734c  660a
        lea     PBU_CTL,%a0             | 780a734e  41f9 7fff 7c00
        bclr    %d1,3(%a0)              | 780a7354  03a8 0003
1:      rts                             | 780a7358  4e75

PBU_$ENABLE_DEVICE:                     | 0x780A735A
        movem.l 4(%sp),%a0-%a1          | 780a735a  4cef 0300 0004
        bsr.s   .Lcheck_unit            | 780a7360  61ba
        bne.s   1f                      | 780a7362  660a
        lea     PBU_CTL,%a0             | 780a7364  41f9 7fff 7c00
        bset    %d1,3(%a0)              | 780a736a  03e8 0003
1:      rts                             | 780a736e  4e75
