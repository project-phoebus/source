|
| svc/m68k/svc_macros.inc - instruction-encoding macros shared by the
| Domain/OS TRAP dispatchers (svc/m68k/trap0.s .. trap8.s).
|
| Shared by the SAU2, SAU5 and SAU9 dispatchers (their images have the
| same code but for the value of PROT, below).
|
| Included as:   .include "svc/m68k/svc_macros.inc"
| (the Makefile assembles with the tree root, domain_os/, as the working
| directory, and gas resolves .include relative to it.)
|
| ---------------------------------------------------------------------
| Why this file exists
| ---------------------------------------------------------------------
| The Apollo assembler emitted the CMP "immediate effective address"
| forms for a compare of an immediate against a data register:
|
|       CMP.W #imm,Dn   ->   1011 nnn 001 111100   = 0xB07C | (n << 9)
|       CMP.L #imm,Dn   ->   1011 nnn 010 111100   = 0xB0BC | (n << 9)
|
| GNU as always assembles `cmp.w #imm,%dn' / `cmp.l #imm,%dn' as the CMPI
| forms instead (0x0C40 / 0x0C80 | ea).  Same operation, same operand
| size, same CCR result, same instruction length - but different bytes,
| and byte fidelity against the image is the goal here.  gas offers no
| syntax to request the CMP spelling, so the two macros below emit the
| encoding literally.
|
| TODO: the same byte-fidelity pass restored the image's
| `lea (SVC_$TRAPn_TABLE:w,%pc),%aN' at 0xE7B04C, 0xE7B064, 0xE7B09C,
| 0xE7B0E0, 0xE7B128, 0xE7B184, 0xE7B1E0 and (already present) 0xE7B240,
| 0xE7B27C, 0xE7B28E, 0xE7B2CC.  All eleven R_68K_PC16 relocations overflow
| under the linker script of the time (sau2.ld, now kernel.ld), which put
| .data ~0x11000 past .text where the image keeps the tables 0x290..0xC08
| bytes past the code.  The fix belongs in the link
| script, not here.
|
| Usage: the register operand is the register *number*, not `%dN':
|
|       cmp_w_imm 0x20, 0       | cmp.w #0x20,%d0   -> b0 7c 00 20
|       cmp_l_imm 0xCC0000, 0   | cmp.l #0xCC0000,%d0 -> b0 bc 00 cc 00 00
|

| ---------------------------------------------------------------------
| The top of the user address space
| ---------------------------------------------------------------------
| The dispatchers compare USP and each argument pointer against the map's
| PROT, the first VA past the user's space: 0xCC0000 on the SAU2, SAU3
| and SAU5, 0x3BFC0000 on the SAU7 and SAU9 (`large_address_space',
| base/config.ins.pas).  Those images hold it as a literal (the SAU2's
| fixup table lists none of these cells), so it is an equate here, not
| a reference to the absolute symbol PROT (arch/m68k/<sau>/iodefs.s).
| Where the segment layout is chosen at boot (`run_time_layout', the
| SAU8: 0x39C0000) the cells are in the fixup table, which COLD applies
| for the MC68851's layout, so they are references to PROT.  The SAU4's
| 8192-segment space (`vm_8192_segs') ends the user's at 0xF7C0000, a
| literal, and the SAU6's 65536-segment space (`vm_65536_segs') at
| 0x77FC0000.

        .include "base/config.inc"
        .if large_address_space
        .equ    PROT_LITERAL, 0x3BFC0000
        .elseif vm_8192_segs
        .equ    PROT_LITERAL, 0x0F7C0000
        .elseif vm_65536_segs
        .equ    PROT_LITERAL, 0x77FC0000
        .elseif run_time_layout
        .equ    PROT_LITERAL, PROT
        .else
        .equ    PROT_LITERAL, 0x00CC0000
        .endif

| CMP.W #imm,Dn  (image form; gas would emit CMPI.W 0c40)
        .macro  cmp_w_imm imm, dreg
        .short  0xb07c + (\dreg << 9)
        .short  \imm
        .endm

| CMP.L #imm,Dn  (image form; gas would emit CMPI.L 0c80)
        .macro  cmp_l_imm imm, dreg
        .short  0xb0bc + (\dreg << 9)
        .long   \imm
        .endm
