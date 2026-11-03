# The SM_C subsystem in Domain Pascal

The second storage module controller's disk driver, on the SAUs whose
kernel has the storage module drivers (the part `smd_disk`,
`../base/config.ins.pas`: the SR10.2 SAU3..SAU6). Translated from the
SAU5 image, with the SAU3's I/O map entries; the SAU2 build compiles
the module to an empty object.

## Layout

One module, `sm_c.pas`, `module sm_c, , wired_data;` (the map segment's
name), its whole body under `%if smd_disk`:

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| .TEXT (default) | SM_C, 0xD5C bytes | eight module-local routines, SM_C_$INT, SM_C_$CINIT, SM_C_$DINIT, SM_C_$GET_STATS, SM_C_$DO_IO, SM_C_$REVALIDATE, SM_C_$SPIN_DOWN | none |
| WIRED_DATA | SM_C data, 0x98 bytes | the jump table and the driver's variables | module variables |

The map's SM_X_ASM segment (SM_FIX_ECC) is hand assembly,
`m68k/sm_x_asm.s`, assembled under `smd_disk` (the same bytes on the
SAU3..SAU6); SM_C_END_ADDR is
`m68k/end_addr.s` (the same on every SAU).  The driver uses SM_$CB,
SM_BLK_HDR and the PBU headings of `../sm/sm.ins.pas` (SM_$CB's second
variant is this controller's layout).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| sm_c_$wire (at the map's SM_C_$PROC_START) | `wire.pas` |
| sm_c_$fix_ecc | `fix_ecc.pas` |
| sm_c_$check_status | `check_status.pas` |
| sm_c_$command | `command.pas` |
| SM_C_$INT | `int.pas` |
| sm_c_$start_drive | `start_drive.pas` |
| SM_C_$CINIT | `cinit.pas` |
| sm_c_$delay | `delay.pas` |
| SM_C_$DINIT | `dinit.pas` |
| sm_c_$reinit | `reinit.pas` |
| sm_c_$format | `format.pas` |
| SM_C_$GET_STATS | `get_stats.pas` |
| SM_C_$DO_IO | `do_io.pas` |
| SM_C_$REVALIDATE | `revalidate.pas` |
| SM_C_$SPIN_DOWN | `spin_down.pas` |
| SM_FIX_ECC | none: hand assembly, `m68k/sm_x_asm.s` |
| SM_C_$PROC_END | none: hand assembly, `m68k/end_addr.s` |

## Open items

- TODO(sau): the SAU6's own SM_C code.
- The SAU4's SM_C is the SAU3's with `mbus_map_64k`, `word_iomap`,
  `large_vm` (sm_c_$fix_ecc) and without `memory_parity`.
- TODO(pascal): the data block's open words (`sm_c.pas`).
- The status codes the controller returns have no known names; the case
  labels are their numbers (`check_status.pas`).
