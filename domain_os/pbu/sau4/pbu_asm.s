|
| pbu/sau4/pbu_asm.s - PBU_ASM: the PBU page's hand-written data and
| routines (the storage module command block, the PBU's flags, the
| interrupt and trap 6 entries, the DCTE table, the device-enable bits)
|
| SAU4 map: "D36 F897400 PBU_PAGE loaded at 298C00, size = 744" and in it
| "D F897400 PBU_ASM size = 744": the whole of the PBU page's data
| section before the PBU_MAP code segment (PBU_WIRED_PROC), 0x744 bytes.
| The SAU3's (pbu/sau3/pbu_asm.s) for the DNx60's MMU and PBU control
| register: no MMU_$PID_PRIV saved or restored, the user handler run at
| IPL 5 (trap 6's return test reads that status register byte), the end
| of user space 0x0F7C0000, the faulting DCTE at the diagnostic frame's
| +0x3C, the device-enable bits PBU_CTL+0x81 (interrupting) and
| PBU_CTL+0x83 (enable, a bit clear enables the unit), and no
| PBU_$GET_STATUS.  Its symbols, each defined here at its offset:
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
|   +0x400  PBU_$DCTES        8 longwords, zero: the DCTE of each PBU
|                             unit (0..7), nil when none is set up
|   +0x420  PBU_$DCTE_TABLE   8 longwords, the addresses of the 8 DCTEs
|                             that follow (0x54 bytes each, zero)
|   +0x6E0  PBU_$DEVICE_INTERRUPTING  one of trap 6's calls
|   +0x720  PBU_$DISABLE_DEVICE
|   +0x732  PBU_$ENABLE_DEVICE
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
|   bit 0, then enters the user handler (+0x20) in user mode at IPL 5
|   through a format-0 frame.
| - PBU_$TRAP6 (vector 38): D1 = 0 with the user handler's frame on top
|   (its status register's high byte 5, the frame PBU_$USER_SPACE_DRIVER
|   built) returns from the handler: the saved state is restored, D0 is
|   the handler's answer, and PBU_$INT_COM goes on.  D1 = 1..8 calls one
|   of the table's routines with the argument count the byte table
|   gives, the arguments copied from the user stack (each one below
|   0x0F7C0000, the end of user space); D1 = 99 enters PBU_$INT_COM for
|   the unit at +4 of the user stack on the interrupt stack.  A bad USP,
|   a bad argument or another code is a fault (FIM_$GENERATE with the
|   status: "invalid usp at trap 6", "protection violation", "invalid
|   trap 6 code").
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
|   0..7, else 0; then the unit's bit of PBU_CTL+0x81 is tested, or of
|   PBU_CTL+0x83 set (disable) or cleared (enable).
|
| The SAU4's: the Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU4
| build takes this file.  Every byte was checked against the image by
| assembling the file alone with m68k-elf-as -m68010 and linking it at
| the segment's address with the map's addresses for the other symbols.
| Where the Apollo assembler encoded `cmp.w #imm,Dn' as CMP <ea>=#imm
| (0xB27C), gas would emit CMPI: those are .word.
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

PBU_$PAGE_START:                        | 0xF897400
SM_$CB:                                 | 0xF897400
        .word   0x0100, 0x0006, 0x0F40, 0x0100  | +0x000
        .word   0x001A, 0x0F40, 0x0000, 0x0100  | +0x008
        .word   0x0014, 0x0F40, 0x0004, 0x0000  | +0x010
        .word   0x0000, 0x0000, 0x0000, 0x0026  | +0x018
        .word   0x0F40                          | +0x020
        .space  0x18                            | +0x022
        .word   0x0F40                          | +0x03A
        .space  0x14                            | +0x03C
        .word   0x0000, 0x0000                  | +0x050: drive 0
        sm_drive SM_$CB+0x68                    | +0x054
        .set    SM_$CNT, SM_$CB+0x74            | 0xF897474
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

PBU_$MCB:                               | 0xF897570
        .word   0                       | the flags
        .word   0                       | the count of set up units

PBU_$INT_COM:                           | 0xF897574
        movea.l 4(%sp),%a1              | f897574  226f 0004
        move.l  %a1,-(%sp)              | f897578  2f09
        movea.l 4(%a1),%a0              | f89757a  2069 0004
        jsr     (%a0)                   | f89757e  4e90
        movea.l (%sp)+,%a1              | f897580  225f
        moveq   #0,%d1                  | f897582  7200
        lsr.w   #1,%d0                  | f897584  e248
        bcc.s   1f                      | f897586  6406
        move.l  #255,%d1                | f897588  223c 0000 00ff
1:      lsr.w   #1,%d0                  | f89758e  e248
        bcs.s   2f                      | f897590  6504
        move.l  %d1,%d0                 | f897592  2001
        rts                             | f897594  4e75
2:      movea.l 36(%a1),%a0             | f897596  2069 0024
        bset    #7,18(%a1)              | f89759a  08e9 0007 0012
        move.l  %d1,-(%sp)              | f8975a0  2f01
        move.l  %a0,-(%sp)              | f8975a2  2f08
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH | f8975a4  4eb9 0f82 1d28
        addq.l  #4,%sp                  | f8975aa  588f
        move.l  (%sp)+,%d0              | f8975ac  201f
        rts                             | f8975ae  4e75

PBU_$ADVANCE_ONLY:                      | 0xF8975B0
        moveq   #2,%d0                  | f8975b0  7002
        rts                             | f8975b2  4e75

PBU_$IGNORE_INT:                        | 0xF8975B4
        clr.w   %d0                     | f8975b4  4240
        rts                             | f8975b6  4e75

PBU_$USER_SPACE_DRIVER:                 | 0xF8975B8
        move.l  %usp,%a0                | f8975b8  4e68
        movem.l %d2-%d7/%a0-%a6,-(%sp)  | f8975ba  48e7 3ffe
        movea.l 40(%a1),%a0             | f8975be  2069 0028
        move.l  %a0,%usp                | f8975c2  4e60
        move.w  PROC1_$AS_ID,-(%sp)     | f8975c4  3f39 0f82 1c1a
        clr.w   %d0                     | f8975ca  4240
        move.b  11(%a1),%d0             | f8975cc  1029 000b
        move.w  %d0,-(%sp)              | f8975d0  3f00
        movea.l %a1,%a2                 | f8975d2  2449
        jsr     MMU_$INSTALL_ASID       | f8975d4  4eb9 0f82 645c
        addq.w  #2,%sp                  | f8975da  544f
        movea.l %a2,%a1                 | f8975dc  224a
        move.w  CPU_B_PBU_SWITCH,-(%sp) | f8975de  3f39 0f82 2e9a
        bset    #0,CPU_B_PBU_SWITCH     | f8975e4  08f9 0000 0f82 2e9a
        movea.l 32(%a1),%a0             | f8975ec  2069 0020
        clr.w   -(%sp)                  | f8975f0  4267
        move.l  %a0,-(%sp)              | f8975f2  2f08
        move.w  #0x500,-(%sp)           | f8975f4  3f3c 0500
        rte                             | f8975f8  4e73
        .word   0                       | a zero word: PBU_$TRAP6 is on a longword

PBU_$TRAP6:                             | 0xF8975FC
        cmpi.b  #5,(%sp)                | f8975fc  0c17 0005
        bne.s   .Lt6_not_return         | f897600  6676
        tst.w   %d1                     | f897602  4a41
        bne.s   .Lt6_call               | f897604  6620
        ori.w   #0x700,%sr              | f897606  007c 0700
        addq.w  #8,%sp                  | f89760a  504f
        move.w  (%sp)+,CPU_B_PBU_SWITCH | f89760c  33df 0f82 2e9a
        move.l  %d0,%d2                 | f897612  2400
        jsr     MMU_$INSTALL_ASID       | f897614  4eb9 0f82 645c
        addq.w  #2,%sp                  | f89761a  544f
        move.l  %d2,%d0                 | f89761c  2002
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | f89761e  4cdf 7ffc
        move.l  %a0,%usp                | f897622  4e60
        rts                             | f897624  4e75
.Lt6_call:
        .word   0xb27c,0x0008           | f897626  cmp.w #8,%d1
        bhi.w   .Lt6_other              | f89762a  6200 0090
        move.l  %fp,-(%sp)              | f89762e  2f0e
        move.l  %d2,-(%sp)              | f897630  2f02
        movea.l %sp,%fp                 | f897632  2c4f
        move.w  %d1,%d2                 | f897634  3401
        lsl.w   #2,%d1                  | f897636  e549
        movea.l (.Lt6_routines-4,%pc,%d1.w),%a0 | f897638  207b 1046
        move.b  (.Lt6_counts,%pc,%d2.w),%d2 | f89763c  143b 2066
        move.l  %usp,%a1                | f897640  4e69
        move.w  %d2,%d1                 | f897642  3202
        lsl.w   #2,%d1                  | f897644  e549
        lea     8(%a1,%d1.w),%a1        | f897646  43f1 1008
        move.l  #0x0F7C0000,%d1         | f89764a  223c 0f7c 0000
        cmpa.l  %d1,%a1                 | f897650  b3c1
        bhi.s   .Lt6_bad_usp            | f897652  625a
1:      move.l  -(%a1),%d0              | f897654  2021
        move.l  %d0,-(%sp)              | f897656  2f00
        cmp.l   %d0,%d1                 | f897658  b280
        dbls    %d2,1b                  | f89765a  53ca fff8
        bls.s   .Lt6_bad_arg            | f89765e  630a
        jsr     (%a0)                   | f897660  4e90
        movea.l %fp,%sp                 | f897662  2e4e
        move.l  (%sp)+,%d2              | f897664  241f
        movea.l (%sp)+,%fp              | f897666  2c5f
        rte                             | f897668  4e73
.Lt6_bad_arg:
        movea.l %fp,%sp                 | f89766a  2e4e
        move.l  (%sp)+,%d2              | f89766c  241f
        movea.l (%sp)+,%fp              | f89766e  2c5f
        move.l  #0x001E0020,-(%sp)      | f897670  2f3c 001e 0020
        bra.s   .Lt6_fault              | f897676  6050
.Lt6_not_return:
        tst.w   %d1                     | f897678  4a41
        bne.s   .Lt6_call               | f89767a  66aa
        move.l  #0x001E001E,-(%sp)      | f89767c  2f3c 001e 001e
        bra.s   .Lt6_fault              | f897682  6044
| The routines of trap 6's codes 1..8, and their argument counts (from
| code 0, which has none).
.Lt6_routines:
        .long   PBU2_$MAP               | f897684  1
        .long   PBU2_$UNMAP             | f897688  2
        .long   PBU_$DEVICE_INTERRUPTING | f89768c  3
        .long   PBU_$DMA_START          | f897690  4
        .long   PBU_$DMA_STOP           | f897694  5
        .long   PBU_$ADVANCE_EC_INT     | f897698  6
        .long   PBU2_$DMA_START         | f89769c  7
        .long   PBU2_$DMA_STOP          | f8976a0  8
.Lt6_counts:
        .byte   0, 4, 4, 1, 6, 2, 2, 7, 2, 0    | f8976a4
.Lt6_bad_usp:
        movea.l %fp,%sp                 | f8976ae  2e4e
        move.l  (%sp)+,%d2              | f8976b0  241f
        movea.l (%sp)+,%fp              | f8976b2  2c5f
        move.l  #0x001E001F,-(%sp)      | f8976b4  2f3c 001e 001f
        bra.s   .Lt6_fault              | f8976ba  600c
.Lt6_other:
        .word   0xb27c,0x0063           | f8976bc  cmp.w #99,%d1
        beq.s   .Lt6_int                | f8976c0  670c
        move.l  #0x001E001E,-(%sp)      | f8976c2  2f3c 001e 001e
.Lt6_fault:
        jsr     FIM_$GENERATE           | f8976c8  4eb9 0f82 2aaa
.Lt6_int:
        ori.w   #0x600,%sr              | f8976ce  007c 0600
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | f8976d2  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | f8976d6  4eb9 0f83 1c26
        move.l  %usp,%a0                | f8976dc  4e68
        move.w  4(%a0),%d0              | f8976de  3028 0004
        lsl.w   #2,%d0                  | f8976e2  e548
        lea     (PBU_$DCTES,%pc),%a0    | f8976e4  41fa 011a
        move.l  (0,%a0,%d0.w),-(%sp)    | f8976e8  2f30 0000
        jsr     (PBU_$INT_COM,%pc)      | f8976ec  4eba fe86
        addq.w  #4,%sp                  | f8976f0  584f
        jmp     PROC1_$INT_EXIT         | f8976f2  4ef9 0f82 1f0e

PBU_$GET_DIAG_PTR:                      | 0xF8976F8
        movea.l 4(%sp),%a0              | f8976f8  206f 0004
        movea.l 60(%a0),%a1             | f8976fc  2268 003c
        bset    #6,19(%a1)              | f897700  08e9 0006 0013
        clr.l   %d0                     | f897706  4280
        move.w  52(%a1),%d0             | f897708  3029 0034
        addq.l  #1,%d0                  | f89770c  5280
        lsl.w   #8,%d0                  | f89770e  e148
        lsl.w   #2,%d0                  | f897710  e548
        movea.l 44(%a1),%a0             | f897712  2069 002c
        adda.l  %d0,%a0                 | f897716  d1c0
        rts                             | f897718  4e75

PBU_$INT_FAULT_COM:                     | 0xF89771A
        addq.w  #4,%sp                  | f89771a  584f
        movea.l (%sp),%sp               | f89771c  2e57
        move.w  (%sp)+,CPU_B_PBU_SWITCH | f89771e  33df 0f82 2e9a
        ori.w   #0x700,%sr              | f897724  007c 0700
        jsr     MMU_$INSTALL_ASID       | f897728  4eb9 0f82 645c
        addq.w  #2,%sp                  | f89772e  544f
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | f897730  4cdf 7ffc
        move.l  %a0,%usp                | f897734  4e60
        clr.w   %d0                     | f897736  4240
        move.b  17(%a1),%d0             | f897738  1029 0011
        pea     (.Lfault_status,%pc)    | f89773c  487a 0022
        move.b  (.Lfault_flag,%pc),-(%sp) | f897740  1f3a 002a
        move.l  (.Lfault_long,%pc),-(%sp) | f897744  2f3a 001e
        move.w  (.Lfault_signal,%pc),-(%sp) | f897748  3f3a 001e
        move.w  %d0,-(%sp)              | f89774c  3f00
        move.w  (.Lfault_word,%pc),-(%sp) | f89774e  3f3a 001a
        jsr     DXM_$ADD_SIGNAL         | f897752  4eb9 0f81 7c28
        adda.w  #16,%sp                 | f897758  defc 0010
        bra.w   PBU_$ADVANCE_ONLY       | f89775c  6000 fe52
| DXM_$ADD_SIGNAL's constant arguments and its status.
.Lfault_status:
        .long   0                       | f897760
.Lfault_long:
        .long   0x00120017              | f897764
.Lfault_signal:
        .word   0x0013                  | f897768
.Lfault_word:
        .word   0                       | f89776a
.Lfault_flag:
        .byte   0xFF                    | f89776c
        .space  0x73

SM_BLK_HDR:                             | 0xF8977E0
        .space  0x20

PBU_$DCTES:                             | 0xF897800
        .space  0x20

PBU_$DCTE_TABLE:                        | 0xF897820
        .long   .Ldcte+0x00*0x54, .Ldcte+0x01*0x54
        .long   .Ldcte+0x02*0x54, .Ldcte+0x03*0x54
        .long   .Ldcte+0x04*0x54, .Ldcte+0x05*0x54
        .long   .Ldcte+0x06*0x54, .Ldcte+0x07*0x54
| The 8 DCTEs PBU_$SETUP hands out (pbu/pbu.ins.pas pbu_$dcte_t).
.Ldcte:                                 | 0xF897840
        .space  8*0x54

PBU_$DEVICE_INTERRUPTING:               | 0xF897AE0
        movem.l 4(%sp),%a0-%a1          | f897ae0  4cef 0300 0004
        bsr.s   .Lcheck_unit            | f897ae6  6110
        beq.s   1f                      | f897ae8  6704
        sf      %d0                     | f897aea  51c0
        rts                             | f897aec  4e75
1:      btst    %d1,PBU_CTL+0x81        | f897aee  0339 0ffe fc81
        sne     %d0                     | f897af4  56c0
        rts                             | f897af6  4e75
| The unit at (A0) and the status at (A1): D0 and the status "pbu not
| present", "invalid unit number" or 0, the condition codes from D0, the
| unit in D1.
.Lcheck_unit:
        moveq   #0,%d0                  | f897af8  7000
        btst    #7,(PBU_$MCB,%pc)       | f897afa  083a 0007 fa72
        bne.s   1f                      | f897b00  6608
        move.l  #0x001E000A,%d0         | f897b02  203c 001e 000a
        bra.s   3f                      | f897b08  6010
1:      move.w  (%a0),%d1               | f897b0a  3210
        bmi.s   2f                      | f897b0c  6b06
        .word   0xb27c,0x0007           | f897b0e  cmp.w #7,%d1
        ble.s   3f                      | f897b12  6f06
2:      move.l  #0x001E000C,%d0         | f897b14  203c 001e 000c
3:      move.l  %d0,(%a1)               | f897b1a  2280
        move.l  %d0,%d0                 | f897b1c  2000
        rts                             | f897b1e  4e75

PBU_$DISABLE_DEVICE:                    | 0xF897B20
        movem.l 4(%sp),%a0-%a1          | f897b20  4cef 0300 0004
        bsr.s   .Lcheck_unit            | f897b26  61d0
        bne.s   1f                      | f897b28  6606
        bset    %d1,PBU_CTL+0x83        | f897b2a  03f9 0ffe fc83
1:      rts                             | f897b30  4e75

PBU_$ENABLE_DEVICE:                     | 0xF897B32
        movem.l 4(%sp),%a0-%a1          | f897b32  4cef 0300 0004
        bsr.s   .Lcheck_unit            | f897b38  61be
        bne.s   1f                      | f897b3a  6606
        bclr    %d1,PBU_CTL+0x83        | f897b3c  03b9 0ffe fc83
1:      rts                             | f897b42  4e75
