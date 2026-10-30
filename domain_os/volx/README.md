# The VOLX subsystem in Domain Pascal

The volume mount table.

## Layout

One module, `volx.pas`, `module volx_;` (the map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | VOLX_, 0x620 bytes | FIND_VOLX, VOLX_$MOUNT, VOLX_$DISMOUNT (and its cell), VOLX_$SHUTDOWN, VOLX_$GET_INFO, VOLX_$GET_UIDS, VOLX_$REC_ENTRY | none |

Data: the VOLX_ data segment (0xC0 bytes) in .DATA, all zero, no
interior symbol: one module variable,

| offset | variable | type |
|--------|----------|------|
| +0x00 | `volx_$table` | array[1..6] of volx_$entry_t |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| FIND_VOLX (find_volx) | `find_volx.pas` (global, `val_param`) |
| VOLX_$MOUNT | `mount.pas` |
| VOLX_$DISMOUNT | `dismount.pas` (and its cell, the constant 0 passed by address, which VOLX_$SHUTDOWN names too) |
| VOLX_$SHUTDOWN | `shutdown.pas` |
| VOLX_$GET_INFO | `get_info.pas` |
| VOLX_$GET_UIDS | `get_uids.pas` |
| VOLX_$REC_ENTRY | `rec_entry.pas` |
| (data) | the table in `volx.pas` |

No routine is nested.  FIND_VOLX: the map lists it, without `$`.  It
is global, `val_param`, `define`d, its heading in `volx.ins.pas`: the
map is the binder's list of global symbols (TTY's internal routines are
not in it), and other `$`-less code symbols are called across modules
(NAME_CONVERT_ACL_STATUS, thirteen callers) and have no reserved slot.
Its frame then has 4 bytes no declaration explains (TODO there): the
reserved slot of an internal routine would have fitted.

`volx.ins.pas` (the MOUNT and DISMOUNT headings from FLOP's
translation, kept as reviewed; the image agrees with them) has the
volume manager's status codes, the table's bound, the entry (`e_`
fields) and the seven headings (the default convention but FIND_VOLX;
SHUTDOWN an integer32 function, the status's longword).

Changes to shared insert files:
- `disk/disk.ins.pas`: status_$disk_already_mounted, DISK_$PV_MOUNT,
  _$LV_UID, _$LV_MOUNT, _$DISMOUNT, _$REVALIDATE.
- `vtoc/vtoc.ins.pas`: vtoc_$mount_loc_t (the packed mount word),
  VTOC_$MOUNT, _$GET_NAME_DIRS, _$DISMOUNT.
- `dir/dir.ins.pas`: DIR_$ADD_MOUNT, DIR_$DROP_MOUNT.
- `ast/ast.ins.pas`: AST_$DISMOUNT.  `name/name.ins.pas`:
  name_$directory_full (Apollo's).  `cal/cal.ins.pas`: CAL_$BOOT_VOLX.
  `network/network.ins.pas`: NETWORK_$REALLY_DISKLESS.
- `bat/bat.ins.pas`: status_$bat_not_mounted, BAT_$N_FREE.

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Behavior

VOLX_$MOUNT stores bus and lv_num into the packed mount word without
masking them, and does not read VTOC_$DISMOUNT's status.  The table's
lower bound 1 is the entries' index bias.

### TODO(pascal)

- `mount.pas`, `dismount.pas`: the frame is not reproduced (the value
  parameters' copies among the locals).
- `get_uids.pas`: the value parameters' copies in reverse order.
- `rec_entry.pas`: 4 frame bytes (stand-in `unused_4`).
- `find_volx.pas`: 4 frame bytes of a global routine unexplained.
