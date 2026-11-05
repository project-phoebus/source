|
| vme/sau6/vme_asm.s - VME_ASM: VME_$SAVE_VME, save the VME bus adapter's
| state, and VME_$SAVE, where it saves it
|
| SAU6 map: "D 780251B0 VME_ASM size = 4C" (WIRED_DATA), two symbols:
|
|   +0x00  VME_$SAVE_VME  the routine, 0x38 bytes
|   +0x38  VME_$SAVE      the saved state, 0x14 bytes, zero
|                         (vme/vme.ins.pas vme_$save_t): the clock's
|                         high half and the adapter's words at 0x00,
|                         0x06, 0x08, 0x0A, 0x60, 0x70, 0x80 and 0x90
|
| Hand-written (the `_ASM' segment, code in a data section, no frame):
| called from the bus error and NMI handlers (fim/sau6/bus_err.s) with
| JSR; it keeps every register, saving and restoring the two it uses.
|
| The SAU6's only (`vme_vectored_ints', base/config.ins.pas): the SAU5's
| VME_ASM is other code (vme/sau5/vme_asm.s) and its VME_$SAVE_VME is
| Pascal (vme/save_vme.pas).  The Makefile assembles */$(TARGET_SAU)/*.s,
| so only a SAU6 build takes this file; the bytes in the right column
| are the image's, checked by assembling the file with m68k-elf-as
| -m68020 and comparing the object with the image at the map's address.
|
        .section ".text.VME_$SAVE_VME","ax",@progbits
        .even

        .globl  VME_$SAVE_VME
        .globl  VME_$SAVE

        .extern VME_CTL                 | the VME adapter's registers (I/O definitions)
        .extern TIME_$CLOCKH

VME_$SAVE_VME:                          | 0x780251B0
        movem.l %a0-%a1,-(%sp)          | 780251b0  48e7 00c0
        lea     (VME_CTL).l,%a0         | 780251b4  41f9 7fff 9400
        lea     (VME_$SAVE,%pc),%a1     | 780251ba  43fa 002c
        move.l  (TIME_$CLOCKH).l,(%a1)+ | 780251be  22f9 7802 e5d2
        move.w  (%a0),(%a1)+            | 780251c4  32d0
        move.w  (6,%a0),(%a1)+          | 780251c6  32e8 0006
        move.w  (8,%a0),(%a1)+          | 780251ca  32e8 0008
        move.w  (10,%a0),(%a1)+         | 780251ce  32e8 000a
        move.w  (0x60,%a0),(%a1)+       | 780251d2  32e8 0060
        move.w  (0x70,%a0),(%a1)+       | 780251d6  32e8 0070
        move.w  (0x80,%a0),(%a1)+       | 780251da  32e8 0080
        move.w  (0x90,%a0),(%a1)+       | 780251de  32e8 0090
        movem.l (%sp)+,%a0-%a1          | 780251e2  4cdf 0300
        rts                             | 780251e6  4e75

VME_$SAVE:                              | 0x780251E8
        .space  0x14                    | 780251e8  0000 ... (20 bytes)
