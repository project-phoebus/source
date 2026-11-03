# The SM subsystem in Domain Pascal

The storage module disk driver, on the SAUs whose kernel has the storage
module drivers (the part `smd_disk`, `../base/config.ins.pas`: the
SR10.2 SAU3..SAU6).  Translated from the SAU5 image, with the SAU3's
I/O map entries; the SAU2 build compiles the module to an empty object.

## Layout

One module, `sm.pas`, `module sm;` (the map segment's name), its whole
body under `%if smd_disk`:

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| .TEXT (default) | SM, 0xB1C bytes | eight module-local routines, SM_$INT, SM_$CINIT, SM_$DINIT, SM_$GET_STATS, SM_$DO_IO, SM_$REVALIDATE, SM_$SPIN_DOWN | none |
| .DATA (default) | SM data, 0x5C bytes | the jump table and the driver's variables | module variables |

The map's SM_END_ADDR segment is hand assembly, `m68k/end_addr.s` (the
same on every SAU).  The command block SM_$CB, SM_$CNT and SM_BLK_HDR
are the PBU page's hand-written data (declared in `sm.ins.pas`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| sm_$page_offset (at the map's SM_$PROC_START) | `page_offset.pas` |
| sm_$wait_ready | `wait_ready.pas` |
| sm_$reset | `reset.pas` |
| sm_$wire | `wire.pas` |
| sm_$check_status | `check_status.pas` |
| sm_$command | `command.pas` |
| SM_$INT | `int.pas` |
| SM_$CINIT | `cinit.pas` |
| SM_$DINIT | `dinit.pas` |
| sm_$format | `format.pas` |
| SM_$GET_STATS | `get_stats.pas` |
| SM_$DO_IO | `do_io.pas` |
| SM_$REVALIDATE | `revalidate.pas` |
| sm_$seek | `seek.pas` |
| SM_$SPIN_DOWN | `spin_down.pas` |
| SM_$PROC_END | none: hand assembly, `m68k/end_addr.s` |

`sm.ins.pas` holds the statuses, the command block's and register
page's types, the module's headings (SM_$CINIT's is the one IO_'s DCTES
use) and SM_BLK_HDR, and, until the SAU5 PBU is translated, the PBU
headings the driver calls (TODO(merge)).

## Open items

- TODO(sau): the SAU4's I/O map entries (`cinit.pas`); the SAU4's and
  SAU6's own SM code.
- TODO(pascal): the data block's open longword at +0x1C (`sm.pas`).
- TODO(merge): the PBU headings (`sm.ins.pas`).
