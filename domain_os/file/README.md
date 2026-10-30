# The FILE subsystem in Domain Pascal

The file manager (object creation, deletion and attributes, protection,
force-writes, and the lock object table with its per-process lists).

The directory's other two routines, OLD_DIR's MAP_CASE and UNMAP_CASE,
are fragments of that module: `map_case.pas` and `unmap_case.pas`, their
headings in `dir/dir.ins.pas`.

## Layout

Two module files, one per map module:

- `file.pas`, `module file_;` (the map segments' name): one compilation
  unit in four code sections and four data sections, with the overlay
  section FILE_$LOT_DATA.  The .TEXT routines load A5 with the .DATA
  block, and FILE_$LOCK_INIT reaches the same block by its address.
- `file_wired.pas`, `module file_wired, , wired_data;`: the FILE_WIRED
  segment, data only, the eventcount FILE_$UID_LOCK_EC (ACL_WIRED's
  shape, `acl/acl_wired.pas`).

`tools/pascal_check.sh` finds both (the first by its name, the second by
its heading).

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| OS_INIT_PROC | 0xF0 | FILE_$LOCK_INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | 0x3F88 | OS_PROC_SHUTWIRED .. FILE_$UNLOCK_PROC: 60 globals and 14 module-local routines, 7 of them nested (table below) | none (the defaults) |
| PROC2_CREATE_PRO | 0x408 | FILE_$SET_LEN, _$SET_LEN_D, _$TRUNCATE, _$TRUNCATE_D, _$GET_SEG_MAP, _$EXPORT_LK, _$FORK_LOCK, _$RESERVE | `[section(proc2_create_pro, proc2_create_dat)]` |
| PROC2_DELETE_PRO | 0xB8 | FILE_$UNLOCK_ALL, FILE_$INVALIDATE | `[section(proc2_delete_pro, proc2_delete_dat)]` |

Data:

| block | section | contents |
|-------|---------|----------|
| FILE_, 0x2D4 bytes | .DATA | the module's variables (below) |
| FILE_, 4 bytes | OS_INIT_DATA | zero; A5 = its end in FILE_$LOCK_INIT, unused |
| FILE_, 4 bytes | PROC2_CREATE_DAT | zero; A5 = its end in the PROC2_CREATE_PRO routines, unused |
| FILE_, 4 bytes | PROC2_DELETE_DAT | zero; A5 = its end in the PROC2_DELETE_PRO routines, unused |
| FILE_$LOT_DATA, 0x1086C bytes | its own load section | the overlay `var (file_$lot_data)` (below) |
| FILE_WIRED, 0xC bytes | WIRED_DATA | FILE_$UID_LOCK_EC (`file_wired.pas`) |

The .DATA block (offsets checked with a dpc probe unit, which also gives
the initial bytes and the size 0x2D4):

| offset | variable | type, initial value |
|--------|----------|---------------------|
| +0x000 | `file_$uid_lock_holders` | array[0..16] of file_$byte_t, zero |
| +0x011 | (the next array's alignment byte) | |
| +0x012 | `unused_012`, a stand-in (never addressed; TODO) | array[1..6] of char |
| +0x018 | `file_$lock_conflict_table` | array[0..7] of file_$lock_mode_set_t |
| +0x028 | `file_$lock_compat_table` | array[0..11] of integer |
| +0x040 | `file_$lock_mode_map` | array[0..11] of integer |
| +0x058 | `file_$lock_mode_table` | array[0..1] of array[0..11] of integer |
| +0x088 | `file_$lock_req_table` | array[0..11] of pinteger |
| +0x0A0 | `file_$lock_cvt_table` | array[0..11] of file_$lock_mode_set_t |
| +0x0B8 | `file_$base_uid` | file_$base_uid_t (a uid_$t, or its low longword's 20-bit node field), zero |
| +0x0C0 | `file_$generated_uid` | uid_$t, zero |
| +0x0C8 | FILE_$LOT_HASHTAB (`define`d, a map symbol) | array[0..250] of integer, zero |
| +0x2BE | `unused_2be`, a stand-in (never addressed; TODO) | integer |
| +0x2C0 | `file_$default_size` | integer32: 16#1010100F |
| +0x2C4 | `file_$lot_seqn` | integer32: 1 |
| +0x2C8 | `file_$lock_illegal_mask` | set of 0..15: [3, 5, 6, 7] |
| +0x2CA | `file_$lot_pending` | integer, zero |
| +0x2CC | `file_$lot_high` | integer, zero |
| +0x2CE | FILE_$LOT_FREE (`define`d, a map symbol) | integer, zero |
| +0x2D0 | `file_$lot_full` | boolean, zero |
| +0x2D1 | (3 bytes: the block's rounding to 4) | |

The map's OS_DATA_SHUTWIRED is +0x000 (see the TODO in `file.pas`).

The overlay FILE_$LOT_DATA (zero: loaded past the file's end):

| offset | variable | type |
|--------|----------|------|
| +0x00000 | `file_$lock_entries` | array[1..1792] of file_$lot_entry_t (0x1C each) |
| +0x0C400 | `file_$lock_table` | array[0..57] of array[1..150] of integer |
| +0x107F8 | `file_$lock_table2` | array[0..57] of pinteger |

The tables past 0x8000 bytes are reached from the section's start plus
60000.

The lock object table's entry, file_$lot_entry_t (`file.pas`, probed
with dpc): context 0x00, node 0x04 (node_low, node_high), uid 0x0C, next
0x14, sequence 0x16, and at 0x18 the 32-bit packed record state
(refcount, read_only, loc_rights, rights, side, mode, remote, pending,
flag0) with a second view whose byte 0x1B is the set flags_set; 0x1C
bytes.

Routines: FILE_ has 71 map symbols in its code, all globals,
OS_PROC_SHUTWIRED among them (its fragment is the os translation's
`os/proc_shutwired.pas`, included by `file.pas`).  The other routines have
no map symbol (module-local, `internal`), and seven of those are nested.
None is hand assembly (there is no `file/sau2/`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| FILE_$LOCK_INIT | `lock_init.pas` |
| OS_PROC_SHUTWIRED | `../os/proc_shutwired.pas` (the os translation's fragment for this module; FILE_'s first routine) |
| file_$uid_lock_acquire | `uid_lock_acquire.pas` |
| file_$uid_lock_release | `uid_lock_release.pas` |
| FILE_$CHECK_PROT | `check_prot.pas` |
| FILE_$SET_ATTRIBUTE | `set_attribute.pas` |
| FILE_$PRIV_CREATE | `priv_create.pas` |
| FILE_$CREATE | `create.pas` |
| FILE_$CREATE_IT | `create_it.pas` |
| FILE_$GET_ATTR_INFO | `get_attr_info.pas` |
| FILE_$GET_ATTRIBUTES | `get_attributes.pas` |
| FILE_$ATTRIBUTES | `attributes.pas` |
| FILE_$ACT_ATTRIBUTES | `act_attributes.pas` |
| FILE_$DELETE_OBJ | `delete_obj.pas` |
| FILE_$DELETE | `delete.pas` |
| FILE_$DELETE_FORCE | `delete_force.pas` |
| FILE_$MK_PERMANENT | `mk_permanent.pas` |
| FILE_$MK_TEMPORARY | `mk_temporary.pas` |
| FILE_$MK_IMMUTABLE | `mk_immutable.pas` |
| FILE_$SET_AUDITED | `set_audited.pas` |
| FILE_$SET_TROUBLE | `set_trouble.pas` |
| FILE_$SET_MAND_LOCK | `set_mand_lock.pas` |
| file_$audit_set_prot | `audit_set_prot.pas` |
| FILE_$SET_PROT_INT | `set_prot_int.pas` |
| FILE_$SET_PROT, file_$get_default_prot (nested) | `set_prot.pas` |
| FILE_$SET_ACL | `set_acl.pas` |
| FILE_$OLD_AP | `old_ap.pas` |
| FILE_$SET_TYPE | `set_type.pas` |
| FILE_$SET_DIRPTR | `set_dirptr.pas` |
| FILE_$SET_DTM_F | `set_dtm_f.pas` |
| FILE_$SET_DTM | `set_dtm.pas` |
| FILE_$SET_DTU_F | `set_dtu_f.pas` |
| FILE_$SET_DTU | `set_dtu.pas` |
| FILE_$SET_DEVNO | `set_devno.pas` |
| FILE_$SET_MGR_ATTR | `set_mgr_attr.pas` |
| FILE_$SET_REFCNT | `set_refcnt.pas` |
| file_$check_same_volume | `check_same_volume.pas` |
| FILE_$NEIGHBORS | `neighbors.pas` |
| FILE_$PURIFY | `purify.pas` |
| FILE_$FW_FILE | `fw_file.pas` |
| FILE_$FW_PARTIAL | `fw_partial.pas` |
| FILE_$FW_PAGES | `fw_pages.pas` |
| file_$audit_lock | `audit_lock.pas` |
| file_$delete_int | `delete_int.pas` |
| FILE_$LOCK_D | `lock_d.pas` |
| FILE_$CHANGE_LOCK_D | `change_lock_d.pas` |
| FILE_$LOCK | `lock.pas` |
| FILE_$PRIV_LOCK and its six nested routines (priv_lock_alloc_entry .. priv_lock_check_conflicts) | `priv_lock.pas` |
| FILE_$DELETE_WHEN_UNLOCKED | `delete_when_unlocked.pas` (the three WHEN_UNLOCKED routines lie apart from the three above) |
| FILE_$DELETE_FORCE_WHEN_UNLOCKED | `delete_force_when_unlocked.pas` |
| FILE_$REMOVE_WHEN_UNLOCKED | `remove_when_unlocked.pas` |
| FILE_$UNLOCK_D | `unlock_d.pas` |
| FILE_$UNLOCK | `unlock.pas` |
| FILE_$PRIV_UNLOCK | `priv_unlock.pas` |
| FILE_$IMPORT_LK | `import_lk.pas` |
| FILE_$READ_LOCK_ENTRYU | `read_lock_entryu.pas` |
| FILE_$READ_LOCK_ENTRYUI | `read_lock_entryui.pas` |
| FILE_$LOCAL_READ_LOCK | `local_read_lock.pas` |
| FILE_$LOCATE | `locate.pas` |
| FILE_$LOCATEI | `locatei.pas` |
| file_$verify_lock_holder | `verify_lock_holder.pas` |
| FILE_$LOCAL_LOCK_VERIFY | `local_lock_verify.pas` |
| FILE_$READ_LOCK_ENTRY | `read_lock_entry.pas` |
| FILE_$READ_LOCK_ENTRYI | `read_lock_entryi.pas` |
| FILE_$PRIV_UNLOCK_ALL | `priv_unlock_all.pas` |
| FILE_$UNLOCK_VOL | `unlock_vol.pas` |
| FILE_$FORCE_UNLOCK | `force_unlock.pas` |
| FILE_$UNLOCK_PROC | `unlock_proc.pas` |
| FILE_$SET_LEN | `set_len.pas` |
| FILE_$SET_LEN_D | `set_len_d.pas` |
| FILE_$TRUNCATE | `truncate.pas` |
| FILE_$TRUNCATE_D | `truncate_d.pas` |
| FILE_$GET_SEG_MAP | `get_seg_map.pas` |
| FILE_$EXPORT_LK | `export_lk.pas` |
| FILE_$FORK_LOCK | `fork_lock.pas` |
| FILE_$RESERVE | `reserve.pas` |
| FILE_$UNLOCK_ALL | `unlock_all.pas` |
| FILE_$INVALIDATE | `invalidate.pas` |
| MAP_CASE | `map_case.pas` (OLD_DIR's global: a fragment for that module, included by no module file) |
| UNMAP_CASE | `unmap_case.pas` (OLD_DIR's, as MAP_CASE; its set constants follow its code) |

The constant cells after a routine's code are named in its fragment.

## Insert files

- `file.ins.pas`: the object-location record, the attribute records
  and their views, the lock record, the statuses, FILE_$SET_PROT's
  protection kinds, and the headings of FILE_'s globals but the ones
  below.
- `file_prot.ins.pas`: file_$set_prot_rec_t and FILE_$SET_PROT_INT's
  heading, which need ACL_'s protection record (included after base,
  file and acl).
- `../acl/acl.ins.pas`: the headings of FILE_$SET_PROT and FILE_$OLD_AP
  (they take ACL_'s protection record; `in' for the UID, the record and
  the default ACL, as their fragments).
- `file.pas`: the lock object table's types, FILE_$PRIV_CREATE's and
  FILE_$PRIV_LOCK's record views, the audit records, the externs of
  FILE_$UID_LOCK_EC, FILE_$LOT_HASHTAB and FILE_$LOT_FREE, FILE_$LOCATEI's
  heading (its location is hint/hint.ins.pas's hint_$addr_t, an insert
  included after `file.ins.pas`), and the forward headings of
  file_$delete_int, file_$check_same_volume and
  file_$verify_lock_holder.  FILE_$ATTRIBUTES' and
  FILE_$ACT_ATTRIBUTES' headings are their fragments' only (their buffer
  is vtoc/vtoc.ins.pas's vtoce_$old_fm_t; only the SVC table calls them).
- Appended by this translation to other units' inserts:
  `../ast/ast.ins.pas` (AST_$SET_ATTRIBUTE, _$SET_ATTR,
  _$GET_ATTRIBUTES, _$LOAD_AOTE, _$GET_DISM_SEQN, _$COND_FLUSH,
  _$GET_DTV, _$SET_DTS, _$GET_SEG_MAP with ast_$seg_map_t,
  _$INVALIDATE, _$RESERVE; status_$ast_incompatible_request,
  status_$ast_refcount_says_unused), `../rem_file/rem_file.ins.pas`
  (REM_FILE_$UNLOCK_ALL, _$FILE_SET_ATTRIB, _$CREATE_TYPE,
  _$CREATE_TYPE_PRESR10 with rem_file_$owner_info_t, _$FILE_SET_PROT,
  _$NEIGHBORS, _$LOCK, _$UNLOCK, _$LOCAL_READ_LOCK, _$LOCAL_VERIFY),
  `../dir/dir.ins.pas` (DIR_$FIND_NET, MAP_CASE, UNMAP_CASE).
- Statuses of other units used here are theirs (acl/acl.ins.pas,
  name/name.ins.pas, uid/uid.ins.pas for DISKLESS_$UID).

## Open items

### TODO(pascal)

- `file.pas`: the three 4-byte data blocks and the A5 loads into them;
  the .DATA block's unaddressed bytes and OS_DATA_SHUTWIRED; FILE_'s
  frames against their locals.
- `map_case.pas`: MAP_CASE's 4 unexplained frame bytes.
- `priv_lock.pas`: new_entry widened with two signs (the parent
  sign-extends, the nested routines zero-extend).
- `priv_unlock_all.pas`: file_$lock_table2's element type (pinteger) is
  not settled: FILE_$PRIV_UNLOCK_ALL's inner `for` has a signed guard
  and a zero-extended index, FILE_$UNLOCK_PROC's the same guard and a
  sign-extended index, FILE_$EXPORT_LK compares an element signed
  (integer elements), FILE_$FORK_LOCK's `for` over an element has the
  unsigned guard (a pinteger bound and index).
