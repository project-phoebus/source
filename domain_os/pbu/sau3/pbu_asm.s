|
| pbu/sau3/pbu_asm.s - PBU_ASM: the PBU page's hand-written data and
| routines (the storage module command block, the PBU's flags, the
| interrupt and trap 6 entries, the DCTE table, the device-enable bits,
| the PBU's status bits)
|
| SAU3 map: "D35 E89400 PBU_PAGE loaded at 18AC00, size = 7A4" and in it
| "D E89400 PBU_ASM size = 7A4": the whole of the PBU page's data
| section before the PBU_MAP code segment (PBU_WIRED_PROC), 0x7A4 bytes.
| The SAU5's (pbu/sau5/pbu_asm.s) with 8 units: PBU_$DCTES 8 longwords,
| the unit check's limit 7, and PBU_$GET_STATUS after
| PBU_$ENABLE_DEVICE.  Its symbols, each defined here at its offset:
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
|   +0x400  PBU_$DCTES        8 longwords, zero: the DCTE of each PBU
|                             unit (0..7), nil when none is set up
|   +0x420  PBU_$DCTE_TABLE   8 longwords, the addresses of the 8 DCTEs
|                             that follow (0x54 bytes each, zero)
|   +0x6E0  PBU_$DEVICE_INTERRUPTING  one of trap 6's calls
|   +0x724  PBU_$DISABLE_DEVICE
|   +0x73A  PBU_$ENABLE_DEVICE
|   +0x750  PBU_$GET_STATUS   the PBU's two control words and its
|                             48 status bits
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
|   0..7, else 0; then the unit's bit of PBU_CTL+2 is tested, or of
|   PBU_CTL+3 cleared or set.
| - PBU_$GET_STATUS (reached through the system call table): three
|   addresses off the stack: PBU_CTL's two words are stored at the first
|   two; then,
|   with bit 15 of PBU_CTL's first word cleared, 48 bits are shifted out
|   of bit 0 of PBU_CTL's high byte, each clocked by setting and clearing
|   bit 6 of its first word, into the six bytes at the third address,
|   from its +5 down to +0 and in each byte from bit 0 up; bit 15 is set
|   again at the end.
|
| The SAU3's: the SAU4, SAU5, SAU6 and SAU7 maps have their own PBU_ASM
| (0x744, 0x770, 0x770 and 0xA64 bytes), the SAU2 and SAU9 none.  The
| Makefile assembles */$(TARGET_SAU)/*.s, so only a SAU3 build takes
| this file.  Every byte was checked against the image by assembling and
| linking the file at the segment's address with the map's addresses
| for the other symbols (the SAU3 build is not linked yet).  Where the
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
        .globl  PBU_$GET_STATUS

| One drive record's constant words and its eventcount (at +0x14 from
| the words; the record is 0x3C bytes).
        .macro  sm_drive ec
        .word   0x0337, 0x1300, 0x2012, 0x0004
        .space  0x0C
        .long   0, \ec, \ec
        .space  0x18
        .endm

PBU_$PAGE_START:                        | 0xE89400
SM_$CB:                                 | 0xE89400
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
        .set    SM_$CNT, SM_$CB+0x74            | 0xE89474
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

PBU_$MCB:                               | 0xE89570
        .word   0                       | the flags
        .word   0                       | the count of set up units

PBU_$INT_COM:                           | 0xE89574
        movea.l 4(%sp),%a1              | e89574  226f 0004
        move.l  %a1,-(%sp)              | e89578  2f09
        movea.l 4(%a1),%a0              | e8957a  2069 0004
        jsr     (%a0)                   | e8957e  4e90
        movea.l (%sp)+,%a1              | e89580  225f
        moveq   #0,%d1                  | e89582  7200
        lsr.w   #1,%d0                  | e89584  e248
        bcc.s   1f                      | e89586  6406
        move.l  #255,%d1                | e89588  223c 0000 00ff
1:      lsr.w   #1,%d0                  | e8958e  e248
        bcs.s   2f                      | e89590  6504
        move.l  %d1,%d0                 | e89592  2001
        rts                             | e89594  4e75
2:      movea.l 36(%a1),%a0             | e89596  2069 0024
        bset    #7,18(%a1)              | e8959a  08e9 0007 0012
        move.l  %d1,-(%sp)              | e895a0  2f01
        move.l  %a0,-(%sp)              | e895a2  2f08
        jsr     EC_$ADVANCE_WITHOUT_DISPATCH  | e895a4  4eb9 00e1 f650
        addq.l  #4,%sp                  | e895aa  588f
        move.l  (%sp)+,%d0              | e895ac  201f
        rts                             | e895ae  4e75

PBU_$ADVANCE_ONLY:                      | 0xE895B0
        moveq   #2,%d0                  | e895b0  7002
        rts                             | e895b2  4e75

PBU_$IGNORE_INT:                        | 0xE895B4
        clr.w   %d0                     | e895b4  4240
        rts                             | e895b6  4e75

PBU_$USER_SPACE_DRIVER:                 | 0xE895B8
        move.l  %usp,%a0                | e895b8  4e68
        movem.l %d2-%d7/%a0-%a6,-(%sp)  | e895ba  48e7 3ffe
        movea.l 40(%a1),%a0             | e895be  2069 0028
        move.l  %a0,%usp                | e895c2  4e60
        move.w  PROC1_$AS_ID,-(%sp)     | e895c4  3f39 00e1 f542
        move.w  MMU_$PID_PRIV,-(%sp)    | e895ca  3f39 00e2 2d00
        clr.w   %d0                     | e895d0  4240
        move.b  11(%a1),%d0             | e895d2  1029 000b
        move.w  %d0,-(%sp)              | e895d6  3f00
        movea.l %a1,%a2                 | e895d8  2449
        jsr     MMU_$INSTALL_ASID       | e895da  4eb9 00e2 31d8
        addq.w  #2,%sp                  | e895e0  544f
        movea.l %a2,%a1                 | e895e2  224a
        move.w  CPU_B_PBU_SWITCH,-(%sp) | e895e4  3f39 00e2 0802
        bset    #0,CPU_B_PBU_SWITCH     | e895ea  08f9 0000 00e2 0802
        movea.l 32(%a1),%a0             | e895f2  2069 0020
        clr.w   -(%sp)                  | e895f6  4267
        move.l  %a0,-(%sp)              | e895f8  2f08
        move.w  #0x400,-(%sp)           | e895fa  3f3c 0400
        rte                             | e895fe  4e73

PBU_$TRAP6:                             | 0xE89600
        cmpi.b  #4,(%sp)                | e89600  0c17 0004
        bne.s   .Lt6_not_return         | e89604  667c
        tst.w   %d1                     | e89606  4a41
        bne.s   .Lt6_call               | e89608  6626
        ori.w   #0x700,%sr              | e8960a  007c 0700
        addq.w  #8,%sp                  | e8960e  504f
        move.w  (%sp)+,CPU_B_PBU_SWITCH | e89610  33df 00e2 0802
        move.w  (%sp)+,MMU_$PID_PRIV    | e89616  33df 00e2 2d00
        move.l  %d0,%d2                 | e8961c  2400
        jsr     MMU_$INSTALL_ASID       | e8961e  4eb9 00e2 31d8
        addq.w  #2,%sp                  | e89624  544f
        move.l  %d2,%d0                 | e89626  2002
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | e89628  4cdf 7ffc
        move.l  %a0,%usp                | e8962c  4e60
        rts                             | e8962e  4e75
.Lt6_call:
        .word   0xb27c,0x0008           | e89630  cmp.w #8,%d1
        bhi.w   .Lt6_other              | e89634  6200 0090
        move.l  %fp,-(%sp)              | e89638  2f0e
        move.l  %d2,-(%sp)              | e8963a  2f02
        movea.l %sp,%fp                 | e8963c  2c4f
        move.w  %d1,%d2                 | e8963e  3401
        lsl.w   #2,%d1                  | e89640  e549
        movea.l (.Lt6_routines-4,%pc,%d1.w),%a0  | e89642  207b 1046
        move.b  (.Lt6_counts,%pc,%d2.w),%d2      | e89646  143b 2066
        move.l  %usp,%a1                | e8964a  4e69
        move.w  %d2,%d1                 | e8964c  3202
        lsl.w   #2,%d1                  | e8964e  e549
        lea     8(%a1,%d1.w),%a1        | e89650  43f1 1008
        move.l  #0x00CC0000,%d1         | e89654  223c 00cc 0000
        cmpa.l  %d1,%a1                 | e8965a  b3c1
        bhi.s   .Lt6_bad_usp            | e8965c  625a
1:      move.l  -(%a1),%d0              | e8965e  2021
        move.l  %d0,-(%sp)              | e89660  2f00
        cmp.l   %d0,%d1                 | e89662  b280
        dbls    %d2,1b                  | e89664  53ca fff8
        bls.s   .Lt6_bad_arg            | e89668  630a
        jsr     (%a0)                   | e8966a  4e90
        movea.l %fp,%sp                 | e8966c  2e4e
        move.l  (%sp)+,%d2              | e8966e  241f
        movea.l (%sp)+,%fp              | e89670  2c5f
        rte                             | e89672  4e73
.Lt6_bad_arg:
        movea.l %fp,%sp                 | e89674  2e4e
        move.l  (%sp)+,%d2              | e89676  241f
        movea.l (%sp)+,%fp              | e89678  2c5f
        move.l  #0x001E0020,-(%sp)      | e8967a  2f3c 001e 0020
        bra.s   .Lt6_fault              | e89680  6050
.Lt6_not_return:
        tst.w   %d1                     | e89682  4a41
        bne.s   .Lt6_call               | e89684  66aa
        move.l  #0x001E001E,-(%sp)      | e89686  2f3c 001e 001e
        bra.s   .Lt6_fault              | e8968c  6044
| The routines of trap 6's codes 1..8, and their argument counts (from
| code 0, which has none).
.Lt6_routines:
        .long   PBU2_$MAP               | e8968e  1
        .long   PBU2_$UNMAP             | e89692  2
        .long   PBU_$DEVICE_INTERRUPTING  | e89696  3
        .long   PBU_$DMA_START          | e8969a  4
        .long   PBU_$DMA_STOP           | e8969e  5
        .long   PBU_$ADVANCE_EC_INT     | e896a2  6
        .long   PBU2_$DMA_START         | e896a6  7
        .long   PBU2_$DMA_STOP          | e896aa  8
.Lt6_counts:
        .byte   0, 4, 4, 1, 6, 2, 2, 7, 2, 0    | e896ae
.Lt6_bad_usp:
        movea.l %fp,%sp                 | e896b8  2e4e
        move.l  (%sp)+,%d2              | e896ba  241f
        movea.l (%sp)+,%fp              | e896bc  2c5f
        move.l  #0x001E001F,-(%sp)      | e896be  2f3c 001e 001f
        bra.s   .Lt6_fault              | e896c4  600c
.Lt6_other:
        .word   0xb27c,0x0063           | e896c6  cmp.w #99,%d1
        beq.s   .Lt6_int                | e896ca  670c
        move.l  #0x001E001E,-(%sp)      | e896cc  2f3c 001e 001e
.Lt6_fault:
        jsr     FIM_$GENERATE           | e896d2  4eb9 00e2 03e0
.Lt6_int:
        ori.w   #0x600,%sr              | e896d8  007c 0600
        movem.l %d0-%d1/%a0-%a1,-(%sp)  | e896dc  48e7 c0c0
        jsr     IO_$USE_INT_STACK       | e896e0  4eb9 00e2 d426
        move.l  %usp,%a0                | e896e6  4e68
        move.w  4(%a0),%d0              | e896e8  3028 0004
        lsl.w   #2,%d0                  | e896ec  e548
        lea     (PBU_$DCTES,%pc),%a0    | e896ee  41fa 0110
        move.l  (0,%a0,%d0.w),-(%sp)    | e896f2  2f30 0000
        jsr     (PBU_$INT_COM,%pc)      | e896f6  4eba fe7c
        addq.w  #4,%sp                  | e896fa  584f
        jmp     PROC1_$INT_EXIT         | e896fc  4ef9 00e1 f836

PBU_$GET_DIAG_PTR:                      | 0xE89702
        movea.l 4(%sp),%a0              | e89702  206f 0004
        movea.l 62(%a0),%a1             | e89706  2268 003e
        bset    #6,19(%a1)              | e8970a  08e9 0006 0013
        clr.l   %d0                     | e89710  4280
        move.w  52(%a1),%d0             | e89712  3029 0034
        addq.l  #1,%d0                  | e89716  5280
        lsl.w   #8,%d0                  | e89718  e148
        lsl.w   #2,%d0                  | e8971a  e548
        movea.l 44(%a1),%a0             | e8971c  2069 002c
        adda.l  %d0,%a0                 | e89720  d1c0
        rts                             | e89722  4e75

PBU_$INT_FAULT_COM:                     | 0xE89724
        addq.w  #4,%sp                  | e89724  584f
        movea.l (%sp),%sp               | e89726  2e57
        move.w  (%sp)+,CPU_B_PBU_SWITCH | e89728  33df 00e2 0802
        ori.w   #0x700,%sr              | e8972e  007c 0700
        move.w  (%sp)+,MMU_$PID_PRIV    | e89732  33df 00e2 2d00
        jsr     MMU_$INSTALL_ASID       | e89738  4eb9 00e2 31d8
        addq.w  #2,%sp                  | e8973e  544f
        movem.l (%sp)+,%d2-%d7/%a0-%a6  | e89740  4cdf 7ffc
        move.l  %a0,%usp                | e89744  4e60
        clr.w   %d0                     | e89746  4240
        move.b  17(%a1),%d0             | e89748  1029 0011
        pea     (.Lfault_status,%pc)    | e8974c  487a 0022
        move.b  (.Lfault_flag,%pc),-(%sp)       | e89750  1f3a 002a
        move.l  (.Lfault_long,%pc),-(%sp)       | e89754  2f3a 001e
        move.w  (.Lfault_signal,%pc),-(%sp)     | e89758  3f3a 001e
        move.w  %d0,-(%sp)              | e8975c  3f00
        move.w  (.Lfault_word,%pc),-(%sp)       | e8975e  3f3a 001a
        jsr     DXM_$ADD_SIGNAL         | e89762  4eb9 00e1 70b0
        adda.w  #16,%sp                 | e89768  defc 0010
        bra.w   PBU_$ADVANCE_ONLY       | e8976c  6000 fe42
| DXM_$ADD_SIGNAL's constant arguments and its status.
.Lfault_status:
        .long   0                       | e89770
.Lfault_long:
        .long   0x00120017              | e89774
.Lfault_signal:
        .word   0x0013                  | e89778
.Lfault_word:
        .word   0                       | e8977a
.Lfault_flag:
        .byte   0xFF                    | e8977c
        .space  0x63                    | e8977d

SM_BLK_HDR:                             | 0xE897E0
        .space  0x20

PBU_$DCTES:                             | 0xE89800
        .space  0x20

PBU_$DCTE_TABLE:                        | 0xE89820
        .long   .Ldcte+0x00*0x54, .Ldcte+0x01*0x54
        .long   .Ldcte+0x02*0x54, .Ldcte+0x03*0x54
        .long   .Ldcte+0x04*0x54, .Ldcte+0x05*0x54
        .long   .Ldcte+0x06*0x54, .Ldcte+0x07*0x54
| The 8 DCTEs PBU_$SETUP hands out (pbu/pbu.ins.pas pbu_$dcte_t).
.Ldcte:                                 | 0xE89840
        .space  8*0x54

PBU_$DEVICE_INTERRUPTING:               | 0xE89AE0
        movem.l 4(%sp),%a0-%a1          | e89ae0  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e89ae6  6114
        beq.s   1f                      | e89ae8  6704
        sf      %d0                     | e89aea  51c0
        rts                             | e89aec  4e75
1:      lea     PBU_CTL,%a0             | e89aee  41f9 00ff 7c00
        btst    %d1,2(%a0)              | e89af4  0328 0002
        sne     %d0                     | e89af8  56c0
        rts                             | e89afa  4e75
| The unit at (A0) and the status at (A1): D0 and the status "pbu not
| present", "invalid unit number" or 0, the condition codes from D0, the
| unit in D1.
.Lcheck_unit:
        moveq   #0,%d0                  | e89afc  7000
        btst    #7,(PBU_$MCB,%pc)       | e89afe  083a 0007 fa6e
        bne.s   1f                      | e89b04  6608
        move.l  #0x001E000A,%d0         | e89b06  203c 001e 000a
        bra.s   3f                      | e89b0c  6010
1:      move.w  (%a0),%d1               | e89b0e  3210
        bmi.s   2f                      | e89b10  6b06
        .word   0xb27c,0x0007           | e89b12  cmp.w #7,%d1
        ble.s   3f                      | e89b16  6f06
2:      move.l  #0x001E000C,%d0         | e89b18  203c 001e 000c
3:      move.l  %d0,(%a1)               | e89b1e  2280
        move.l  %d0,%d0                 | e89b20  2000
        rts                             | e89b22  4e75

PBU_$DISABLE_DEVICE:                    | 0xE89B24
        movem.l 4(%sp),%a0-%a1          | e89b24  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e89b2a  61d0
        bne.s   1f                      | e89b2c  660a
        lea     PBU_CTL,%a0             | e89b2e  41f9 00ff 7c00
        bclr    %d1,3(%a0)              | e89b34  03a8 0003
1:      rts                             | e89b38  4e75

PBU_$ENABLE_DEVICE:                     | 0xE89B3A
        movem.l 4(%sp),%a0-%a1          | e89b3a  4cef 0300 0004
        bsr.s   .Lcheck_unit            | e89b40  61ba
        bne.s   1f                      | e89b42  660a
        lea     PBU_CTL,%a0             | e89b44  41f9 00ff 7c00
        bset    %d1,3(%a0)              | e89b4a  03e8 0003
1:      rts                             | e89b4e  4e75

PBU_$GET_STATUS:                        | 0xE89B50
        movem.l %d2/%a2-%a3,-(%sp)      | e89b50  48e7 2030
        movem.l 16(%sp),%a0-%a2         | e89b54  4cef 0700 0010
        lea     PBU_CTL,%a3             | e89b5a  47f9 00ff 7c00
        move.w  (%a3),(%a0)             | e89b60  3093
        move.w  2(%a3),(%a1)            | e89b62  32ab 0002
        lea     5(%a2),%a2              | e89b66  45ea 0005
        bclr    #7,1(%a3)               | e89b6a  08ab 0007 0001
        moveq   #5,%d2                  | e89b70  7405
1:      clr.b   (%a2)                   | e89b72  4212
        moveq   #7,%d0                  | e89b74  7007
        clr.w   %d1                     | e89b76  4241
2:      btst    #0,(%a3)                | e89b78  0813 0000
        beq.s   3f                      | e89b7c  6702
        bset    %d1,(%a2)               | e89b7e  03d2
3:      bset    #6,1(%a3)               | e89b80  08eb 0006 0001
        bclr    #6,1(%a3)               | e89b86  08ab 0006 0001
        addq.w  #1,%d1                  | e89b8c  5241
        dbf     %d0,2b                  | e89b8e  51c8 ffe8
        subq.l  #1,%a2                  | e89b92  538a
        dbf     %d2,1b                  | e89b94  51ca ffdc
        bset    #7,1(%a3)               | e89b98  08eb 0007 0001
        movem.l (%sp)+,%d2/%a2-%a3      | e89b9e  4cdf 0c04
        rts                             | e89ba2  4e75
