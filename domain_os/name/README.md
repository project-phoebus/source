# The NAME subsystem in Domain Pascal

The naming server: pathname validation and resolution, the working and
naming directories of each address space and their mappings, and the
initialization of the root, node and /com directories. In Domain Pascal,
as `tty/`, `audit/` and the others are.

## Layout

Two map modules, two module files, both found by `tools/pascal_check.sh`
(`name/name.pas` as `<sub>/<sub>.pas`, `name/nameu.pas` by its heading):

| file | heading | code | data |
|------|---------|------|------|
| `name.pas` | `module name;` | OS_INIT_PROC (0x394); .TEXT (0x5B0); PROC2_CREATE_PRO (0x204); PROC2_DELETE_PRO (0x84) | .DATA (0xB20), the module variables; OS_INIT_DATA (0x108), NAME_$INIT's statics |
| `nameu.pas` | `module nameu;` | .TEXT (0x5C0) | .DATA (0x40), two unreferenced sets |

Sections in `name.pas`: the .TEXT routines take the defaults; NAME_$INIT
is headed `[section(os_init_proc, os_init_data)]`, NAME_$INIT_ASID and
NAME_$FORK `[section(proc2_create_pro, proc2_create_dat)]`,
NAME_$FREE_ASID `[section(proc2_delete_pro, proc2_delete_dat)]`.  The
.TEXT routines that use the block load it into A5; the others reach it
by its address.

NAME's .DATA block (all zero), every object a map symbol, `define`d in
`name.pas` and declared in `name.ins.pas`:

| offset | variable | type |
|--------|----------|------|
| +0x000 | NAME_$NODE_DATA_UID | uid_$t |
| +0x008 | NAME_$COM_MAPPED_INFO | name_$mapped_info_t (16 bytes) |
| +0x018 | NAME_$COM_UID | uid_$t |
| +0x020 | NAME_$NODE_MAPPED_INFO | name_$mapped_info_t |
| +0x030 | NAME_$NODE_UID | uid_$t |
| +0x038 | NAME_$ROOT_UID | uid_$t |
| +0x040 | NAME_$NDIR_MAPPED_INFO | array[0..57] of name_$mapped_info_t |
| +0x3E0 | NAME_$NDIR_UID | array[0..57] of uid_$t |
| +0x5B0 | NAME_$WDIR_MAPPED_INFO | array[0..57] of name_$mapped_info_t |
| +0x950 | NAME_$WDIR_UID | array[0..57] of uid_$t |

The per-address-space arrays are indexed by the address space from 0,
no bias: each map symbol is the element of address space 0
(NAME_$GET_WDIR_UID's index; NAME_$INIT's loop clears from the
symbols), and the 58 elements end at the next symbol.  Every site uses
the address space itself: PROC1_$AS_ID (the getters, _$SET_WDIRUS,
_$SET_NDIRUS, _$INIT_ASID), the argument word (_$INIT_ASID, _$FORK,
_$FREE_ASID), a local found by searching PROC2_$UID (_$READ_DIRS_PS),
the loop index (_$INIT).

NAME_$INIT's OS_INIT_DATA block: path_buf (256 bytes, zero) at +0x000
and the nested routine's crash_delay (16#28 high, 0 low, then 2 bytes
of rounding) at +0x100.

NAMEU's .DATA block: two 32-byte sets of char (+0x00, +0x20), the
bytes OLD_DIR's block begins with; nothing in NAMEU addresses them (a
TODO in `nameu.pas`).

Routines: NAME, 16 globals (every map symbol of its four code segments,
NAME_CONVERT_ACL_STATUS without `$`) and two module-local (`internal`)
routines, name_$map_dir and name_$unmap_dir_buffers, and one nested,
name_$init_check_status in NAME_$INIT.  NAMEU, 6 globals (NAMEQ without
`$`) and 4 module-local: name_$split_path, name_$parse_component,
name_$resolve_internal, name_$resolve_dir_and_leaf.  None is hand
assembly (there is no `name/sau2/`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| NAME_$INIT, name_$init_check_status (nested) | `init.pas` |
| name_$split_path | `split_path.pas` |
| NAMEQ | `nameq.pas` |
| NAME_$VALIDATE | `validate.pas` |
| name_$parse_component | `parse_component.pas` |
| name_$resolve_internal | `resolve_internal.pas` |
| name_$resolve_dir_and_leaf | `resolve_dir_and_leaf.pas` |
| NAME_$RESOLVE | `resolve.pas` |
| NAME_$DROP | `drop.pas` |
| NAME_$CR_FILE | `cr_file.pas` |
| NAME_$SET_WDIR | `set_wdir.pas` |
| name_$map_dir | `map_dir.pas` |
| name_$unmap_dir_buffers | `unmap_dir_buffers.pas` |
| NAME_$CLEANUP | `cleanup.pas` |
| NAME_CONVERT_ACL_STATUS | `../misc/name_convert_acl_status.pas` |
| NAME_$SET_ACL | `set_acl.pas` |
| NAME_$SET_WDIRUS | `set_wdirus.pas` (it and NAME_$SET_NDIRUS are two full copies in the image, no shared helper) |
| NAME_$SET_NDIRUS | `set_ndirus.pas` |
| NAME_$READ_DIRS_PS | `read_dirs_ps.pas` |
| NAME_$GET_WDIR_UID | `get_wdir_uid.pas` |
| NAME_$GET_NDIR_UID | `get_ndir_uid.pas` |
| NAME_$GET_ROOT_UID | `get_root_uid.pas` |
| NAME_$GET_NODE_UID | `get_node_uid.pas` |
| NAME_$GET_NODE_DATA_UID | `get_node_data_uid.pas` |
| NAME_$GET_CANNED_ROOT_UID | `get_canned_root_uid.pas` |
| NAME_$INIT_ASID | `init_asid.pas` |
| NAME_$FORK | `fork.pas` |
| NAME_$FREE_ASID | `free_asid.pas` |
| (data) | `name.pas`, `init.pas`, `nameu.pas` |

A group of routines that lie apart in the image, or in two units or
sections, has one fragment per contiguous group, named after the
routine.

**Fragments for OLD_DIR.**  Ten fragments here are module-local
routines of OLD_DIR's code segment (.TEXT; OLD_DIR's map module):
`../dir/old_dir.pas` includes them in image order (their headings, notes
and the open items are `../dir/README.md`'s).  NAME's module
files do not include them.

| routine | fragment |
|---------|----------|
| name_$validate_leaf | `validate_leaf.pas` (the set test inline) |
| name_$unlock_dir (no map symbol) | `unlock_dir.pas` |
| name_$lock_dir (no map symbol) | `lock_dir.pas` |
| name_$old_add_link_local | `old_add_link_local.pas` |
| name_$old_add_entry | `old_add_entry.pas` |
| name_$old_add_link | `old_add_link.pas` |
| name_$old_drop_entry | `old_drop_entry.pas` |
| name_$old_delete_entryu (no map symbol) | `old_delete_entryu.pas` |
| name_$old_get_entry_nonroot | `old_get_entry_nonroot.pas` |
| name_$old_get_root_entry | `old_get_root_entry.pas` |

Headings (`name.ins.pas`): every global uses the default convention
(every argument by address: OS_$INIT, PROC2, LOG_$INIT, HINT_$INIT and
the SVC table push addresses).  The module-local routines take words by
value (`internal`).  No routine returns a pointer, so no D0 parking.

## Insert files

- `name.ins.pas` (users: rem_name, misc, hint, log, flop, volx, fim,
  audit, peb): the start-path constants, the statuses, name_$max_asids,
  name_$mapped_info_t, name_$event_uid_t, the ten .DATA variables,
  NAME_$CANNED_ROOT_UID (UID_LIST's object), and the headings of
  NAME_$INIT, NAMEQ, _$VALIDATE, _$SET_WDIR, _$SET_ACL, _$SET_WDIRUS,
  _$SET_NDIRUS, _$READ_DIRS_PS, the five getters, _$INIT_ASID, _$FORK,
  _$FREE_ASID.  It needs only base before it (the asid formals are
  integer, not proc1_$asid_t, so that its includers need no proc1).
  Also status_$naming_vol_mounted_read_only (16#000E0030) and
  status_$naming_bad_directory (16#000E000D), moved from
  file/file.ins.pas; the old-format and DIR_$GET_ENTRYU entry types,
  Apollo's name_$file = 1 and name_$link = 3 (customer name.ins.pas)
  and name_$entry_none (0, new), the `case` labels of
  `resolve_internal.pas` (and of OLD_DIR's routines).
- `dir/dir.ins.pas`: DIR_$INIT, dir_$old_entry_t, DIR_$GET_ENTRYU,
  DIR_$SET_ACL, DIR_$CLEANUP.
- `acl/acl.ins.pas`: ACL_$FILE_ACL, ACL_$FILEIN_ACL (UID_LIST),
  ACL_$COPY.
- `ast/ast.ins.pas`: ast_$location_t, AST_$GET_LOCATION.
- `file/file.ins.pas`: FILE_$SET_DIRPTR.
- `proc2/proc2.ins.pas`: proc2_$uid_not_found, moved from
  `xpd/xpd.ins.pas` (every includer of that file includes proc2's
  first).
- Used as they are: base, ec, ml, time, uid, vfmt, misc/crash_system,
  proc1, mst, node, cal, fm, vtoc, audit.

## Open items

### Types and names

- Ten fragments here are OLD_DIR's module-local routines (the table
  above), not NAME's; name_$lock_dir and name_$unlock_dir are not map
  symbols.
- NAME_$SET_WDIRUS and _$SET_NDIRUS are full copies; there is no shared
  helper in the image.
- NAME_$CANNED_ROOT_UID and NAME_$CANNED_REP_ROOT_UID are objects of the
  UID_LIST segment, not of NAME's units.
- name_$validate_leaf's set test is inline.
- The four per-address-space arrays start at address space 0 at their
  symbols (no bias).

### TODO(pascal)

- `nameu.pas`: NAMEU's two unreferenced char sets (a declaration shared
  with OLD_DIR?).
- `resolve_internal.pas`: 4 frame bytes of name_$resolve_internal
  (stand-in unused_24).
- `resolve.pas`: 4 frame bytes of NAME_$RESOLVE (unused_14).
- `set_acl.pas`: 8 frame bytes of NAME_$SET_ACL (unused_8).
- `read_dirs_ps.pas`: 4 frame bytes of NAME_$READ_DIRS_PS (unused_8).
- `free_asid.pas`: 4 frame bytes of NAME_$FREE_ASID (unused_4).
- `init.pas`: NAME_$INIT's frame against its locals (unused_14,
  unused_1a, unused_28).

The other frames are explained exactly by their locals (with an 8-byte
alignment) and register-held locals' slots: name_$map_dir,
name_$unmap_dir_buffers, name_$split_path, NAMEQ, NAME_$VALIDATE,
name_$parse_component, name_$resolve_dir_and_leaf, NAME_$DROP,
NAME_$CR_FILE, NAME_$SET_WDIR, NAME_$SET_WDIRUS, _$SET_NDIRUS,
NAME_$INIT_ASID, the nested check, and the frameless routines.
