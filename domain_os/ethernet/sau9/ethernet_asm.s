|
| ethernet/sau9/ethernet_asm.s - ETHERNET_ASM, ETHERNET_$$PIO_READ and
| ETHERNET_$$PIO_WRITE: move a packet's words between memory and the
| 3C505's data register by program
|
| SAU9 map: "I 3C484A88 ETHERNET_ASM size = 80" (ETHER_PROC, after the
| ETHERNET code segment), ETHERNET_$$PIO_READ at its start and
| ETHERNET_$$PIO_WRITE at +0x40.
|
| Hand-written (an `_ASM' segment, no frame, the arguments read off SP).
| The ETHERNET routines call them with four arguments by value but the
| last (ethernet/ethernet_3c505.ins.pas):
|
|   (4,SP)   the adapter's registers
|   (8,SP)   the buffer
|   (12,SP)  the byte count, a word (halved: words are moved)
|   (14,SP)  the address of the status
|
| For each word the data register's ready bit (HRDY, bit 7 of the
| status register at 2) is polled 10001 times at most; then the word is
| moved through the data register at 4.  The result in D0 is true (-1)
| with the status 0, or false (0) with status_$eth_adapter_hardware_error
| (16#002F0006) when a word's wait timed out.
|
| Byte check: assembled with `m68k-elf-as -m68030' and compared with the
| image's 0x80 bytes; the build has no SAU9 target yet.  The address and
| byte columns are the SAU9 image's.
|
        .section ".text.ETHERNET_ASM.ETHER_PROC","ax",@progbits
        .even

        .globl  ETHERNET_$$PIO_READ
        .globl  ETHERNET_$$PIO_WRITE

ETHERNET_$$PIO_READ:                    | 0x3C484A88
        movea.l (4,%sp),%a1             | 3c484a88  226f 0004
        movea.l (8,%sp),%a0             | 3c484a8c  206f 0008
        move.w  (12,%sp),%d0            | 3c484a90  302f 000c
        asr.w   #1,%d0                  | 3c484a94  e240
        bra.s   3f                      | 3c484a96  6022
1:      move.w  #10000,%d1              | 3c484a98  323c 2710
2:      btst    #7,(2,%a1)              | 3c484a9c  0829 0007 0002
        bne.s   2f                      | 3c484aa2  6612
        dbf     %d1,2b                  | 3c484aa4  51c9 fff6
        movea.l (14,%sp),%a0            | 3c484aa8  206f 000e
        move.l  #0x002F0006,(%a0)       | 3c484aac  20bc 002f 0006
        clr.l   %d0                     | 3c484ab2  4280
        bra.s   4f                      | 3c484ab4  6010
2:      move.w  (4,%a1),(%a0)+          | 3c484ab6  30e9 0004
3:      dbf     %d0,1b                  | 3c484aba  51c8 ffdc
        movea.l (14,%sp),%a0            | 3c484abe  206f 000e
        clr.l   (%a0)                   | 3c484ac2  4290
        moveq   #-1,%d0                 | 3c484ac4  70ff
4:      rts                             | 3c484ac6  4e75

ETHERNET_$$PIO_WRITE:                   | 0x3C484AC8
        movea.l (4,%sp),%a1             | 3c484ac8  226f 0004
        movea.l (8,%sp),%a0             | 3c484acc  206f 0008
        move.w  (12,%sp),%d0            | 3c484ad0  302f 000c
        asr.w   #1,%d0                  | 3c484ad4  e240
        bra.s   3f                      | 3c484ad6  6022
1:      move.w  #10000,%d1              | 3c484ad8  323c 2710
2:      btst    #7,(2,%a1)              | 3c484adc  0829 0007 0002
        bne.s   2f                      | 3c484ae2  6612
        dbf     %d1,2b                  | 3c484ae4  51c9 fff6
        movea.l (14,%sp),%a0            | 3c484ae8  206f 000e
        move.l  #0x002F0006,(%a0)       | 3c484aec  20bc 002f 0006
        clr.l   %d0                     | 3c484af2  4280
        bra.s   4f                      | 3c484af4  6010
2:      move.w  (%a0)+,(4,%a1)          | 3c484af6  3358 0004
3:      dbf     %d0,1b                  | 3c484afa  51c8 ffdc
        movea.l (14,%sp),%a0            | 3c484afe  206f 000e
        clr.l   (%a0)                   | 3c484b02  4290
        moveq   #-1,%d0                 | 3c484b04  70ff
4:      rts                             | 3c484b06  4e75
