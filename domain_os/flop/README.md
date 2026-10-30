# The FLOP subsystem in Domain Pascal

Booting from the floppy.

## Layout

One module, `flop.pas`, `module flop_boot;` (the map segment's name):

| section      | code          | routines | attribute |
|--------------|---------------|----------|-----------|
| OS_INIT_PROC | FLOP_BOOT, 0x38C bytes | flop_$boot_errchk (nested), flop_$mount_floppy (nested), FLOP_$BOOT, each followed by its cells | `[section(os_init_proc, os_init_data)]` on FLOP_$BOOT, inherited by the nested ones |

Data: none (no FLOP_BOOT data segment in the map; no A5).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| flop_$boot_errchk | inside `boot.pas`: nested in FLOP_$BOOT (it reads the static link) |
| flop_$mount_floppy | `mount_floppy.pas`, included in FLOP_$BOOT's declarations by `boot.pas`: nested (in FLOP_$BOOT's family, called only by it, no link read) |
| FLOP_$BOOT | `boot.pas` |
| (cells) | the compiler's cells of literal arguments; the image's layout follows the compiler's order exactly, with the cells of flop_$mount_floppy shared by FLOP_$BOOT's calls |

`flop.ins.pas`: the header type `flop_$header_t` (six longwords) and its
pointer, FLOP_$BOOT's heading (`out entry_point`, `out status_ret`, a
boolean function).

The module also uses these shared insert files' declarations:
- `base/base.ins.pas`: Apollo's name_$long_complen_max and
  name_$long_name_t.
- `name/name.ins.pas`: Apollo's name_$already_exists; NAME_$GET_NODE_UID.
- `disk/disk.ins.pas`: status_$disk_write_protected.
- `mst/mst.ins.pas`: MST_$MAP (a univ_ptr function), MST_$UNMAP,
  MST_$MAP_AT (a procedure).
- `volx/volx.ins.pas`: status_$volume_disk_is_write_protected,
  VOLX_$MOUNT, VOLX_$DISMOUNT (value parameters where the callee copies).
- `dir/dir.ins.pas`: DIR_$ADDU, DIR_$SET_DAD, DIR_$DROPU.
- `os/os.ins.pas`: OS_$BOOT_ERRCHK (a boolean function).  Its third
  argument is a length: FLOP passes 21, the length of its second.

The FILE_$LOCK heading (`var lock_info: integer32`) fits: FLOP_$BOOT's
lock_info is a longword local.

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### TODO(pascal)

None.  (`mount_floppy.pas`'s 4 unaddressed frame bytes are the rounding that
puts node_uid at a multiple of 8, and its object at -0x34 is
NAME_$GET_NODE_UID's result temporary: no stand-in is left.)
