# The DIR subsystem in Domain Pascal

The directory manager (the per-object directory locks and handles, the
directory page cache, the operation dispatcher DIR_$DO_OP and its
handlers, the mount table, the old (pre-SR10) directory format, and the
remote directory server).

## Layout

Four map modules, so four module files:

- **`dir.pas`, `module dir;`** (the map segments' name): one compilation
  unit in two code sections and two data sections.  The .TEXT routines
  load A5 with the .DATA block's address plus 8; DIR_$INIT, in
  OS_INIT_PROC, loads the end of its 4-byte OS_INIT_DATA block and
  reaches the .DATA block by its address plus 8.
- **`old_dir.pas`, `module old_dir;`**: OLD_DIR, the same shape: its
  .TEXT routines load A5 with the .DATA block's start; DIR_$OLD_INIT, in
  OS_INIT_PROC, loads the end of its 4-byte block and reaches the .DATA
  block by its address.  It holds the fragments of ten routines of the
  name_ family (`../name/`), and FILE_'s MAP_CASE and UNMAP_CASE.
- **`dir_server.pas`, `module dir_server;`**: DIR_SERVER, one routine
  whose statics are the whole data block (A5 = the block's start).  Its
  heading and the request and reply views it reads are in
  `dir_server.ins.pas` (its records hold `../acl/acl.ins.pas`'s).
- **`dir_wired.pas`, `module dir_wired, , wired_data;`**: DIR_WIRED, data
  only, the four wired objects (FILE_WIRED's shape).

`tools/pascal_check.sh` finds all four (`dir.pas` by its name, the others
by their headings).

| module | section | code | routines (image order) | attribute |
|--------|---------|------|------------------------|-----------|
| DIR | OS_INIT_PROC | 0xE8 bytes | DIR_$INIT | `[section(os_init_proc, os_init_data)]` |
| DIR | .TEXT | 0x8FD0 bytes | audit_$log_prot_op .. DIR_$FIX_DIR: 31 globals and 75 module-local routines, 19 of them nested (table below) | none (the defaults) |
| OLD_DIR | OS_INIT_PROC | 0x28 bytes | DIR_$OLD_INIT | `[section(os_init_proc, os_init_data)]` |
| OLD_DIR | .TEXT | 0x4308 bytes | MAP_CASE .. DIR_$OLD_VALIDATE_ROOT_ENTRY: 27 globals and 30 module-local routines, none nested | none |
| DIR_SERVER | .TEXT | 0x1A0 bytes | DIR_$SERVER (global), and a 2-byte cell of zero after it | none |

Data:

| block | section | contents |
|-------|---------|----------|
| DIR, 0x212C bytes | .DATA | DIR's variables (below), A5 = +8 |
| DIR, 4 bytes | OS_INIT_DATA | zero; A5 = its end in DIR_$INIT, unused (TODO in `dir.pas`) |
| OLD_DIR, 0x4C0 bytes | .DATA | OLD_DIR's variables (below) |
| OLD_DIR, 4 bytes | OS_INIT_DATA | zero; A5 = its end in DIR_$OLD_INIT, unused (TODO in `old_dir.pas`) |
| DIR_SERVER, 0x80 bytes | .DATA | DIR_$SERVER's statics (`server.pas`): default_proj (+0x00, 16#C three times), saved_subsys (+0x10), saved_prot (+0x20), saved_re_sids (+0x30), saved_acl (+0x58), first_time (+0x7C, true); four 4-byte stand-ins (+0x0C, +0x1C, +0x2C, +0x54) for the 8-alignment from the block |
| DIR_WIRED, 0x1BC bytes | WIRED_DATA | DIR_$WT_FOR_HDNL_EC, DIR_$WAIT_ECS, DIR_$LINK_BUF_MUTEX, DIR_$MUTEX (`dir_wired.pas`) |

DIR's .DATA block (offsets from A5, the block + 8; a dpc probe gave
every offset below and the initial bytes):

| offset | variable | type, initial value |
|--------|----------|---------------------|
| -0x008 | (compiler) | the address of a zero longword cell in the code (TODO in `dir.pas`) |
| -0x004 | (compiler) | the address of a cell 16#000E0025 in the code (TODO in `dir.pas`) |
| +0x000 | `dir_$link_buf` | array[1..0x400] of char, zero |
| +0x400 | `dir_$entry_cache` | array[0..110] of dir_$entry_cache_t (0x28), zero |
| +0x1558 | DIR_$MTTAB (`define`d) | dir_$mttab_t (0xA4), zero |
| +0x15FC | `unused_15fc`, a stand-in | integer32, zero |
| +0x1600 | `dir_$proc_flags` | array[1..64] of dir_$proc_flags_t (set of 0..15; member 1 the short lock wait, dir_$lock_obj), zero |
| +0x1680 | `dir_$lock_tab` | array[0..31] of dir_$lock_entry_t (0x10), zero |
| +0x1880 | `dir_$handle_tab` | array[0..31] of dir_$handle_t (0x3C), zero |
| +0x2000 | `dir_$name_offset_table` | array[0..7] of integer: 0, 4, 16#10, 16#14, 16#0C, 0, 0, 0 |
| +0x2010 | DIR_$ENTRY_CACHE_TOO_LONG_NAME, _SKIPPED_ACL, _TRIES, _HITS, DIR_$HNDL_WAITS, DIR_$LK_TIMEOUTS, DIR_$LK_WAIT_2, DIR_$LK_WAITS (`define`d) | integer32 each, zero |
| +0x2030 | `dir_$lock_free` | dir_$lock_entry_ptr_t, zero |
| +0x2034 | `dir_$lock_in_use` | set of 0..31, zero |
| +0x2038 | `dir_$handle_free` | dir_$handle_ptr_t, zero |
| +0x203C | `dir_$handle_in_use` | set of 0..31, zero |
| +0x2040 | `dir_$link_buf_owner` | integer, zero |
| +0x2042 | DIR_$OP_TAB (`define`d) | array[21..46] of dir_$op_tab_entry_t (8) |
| +0x2112 | (2 bytes: the next longword) | |
| +0x2114 | `dir_$readu_cookie_first`, `_dotdot`, `_dot`: dir_$do_op_dir_readu's statics (`do_op_dir_readu.pas`) | integer32: 16#00020001, 16#00010001, 16#00000001 |
| +0x2120 | `bak`: dir_$do_op_add_bak's static (its only reader; `do_op_add_bak.pas` declares it) | array[1..4] of char: '.bak' |

OLD_DIR's .DATA block (a dpc probe gives the same 0x4C0 bytes):

| offset | variable | type, initial value |
|--------|----------|---------------------|
| +0x000 | `name_$leaf_char_set` | set of char: ['!'..'.', '0'..'[', ']'..'~'] |
| +0x020 | `name_$leaf_first_char_set` | set of char: ['!'..'-', '0'..'_', 'a'..'}'] |
| +0x040 | `name_$lock_slot` | array[1..64] of integer32, zero |
| +0x140 | `name_$lock_mode` | array[1..64] of integer, zero |
| +0x1C0 | `name_$lock_handle` | array[1..64] of integer32, zero |
| +0x2C0 | `name_$lock_uid` | array[1..64] of uid_$t, zero |

The variables' names are prefixed `dir_$` or `name_$`.  The types and
index bases are refined by the fragments that read them.

Records (probed with dpc):

| record | fields (offset) | size |
|--------|-----------------|------|
| dir_$lock_entry_t (`dir.pas`) | next / uid 0x00, waiters 0x08, lock_count 0x0C, index 0x0E | 0x10 |
| dir_$handle_t (`dir.pas`) | uid 0x00, owner 0x08, lock_mode 0x0A, dir_kind 0x0C, split_busy 0x0E, length 0x10, wired_page 0x14, buf 0x18, max_slots 0x1C, cur_slot 0x1E, map 0x20, next 0x30, lock_entry 0x34, slot_index 0x38, volume 0x3A | 0x3C |
| dir_$handle_map_t (`dir.pas`) | info (name_$mapped_info_t: active 0x00, first_base 0x04, second_base 0x0C) / slot[0..1] 0x00 (8 each) | 0x10 |
| dir_$page_cache_t (`dir.pas`) | unused_0 0x00, group 0x02, base 0x04 | 8 |
| dir_$entry_cache_t (`dir.pas`) | dir_uid 0x00, entry_uid 0x08, dtv 0x10, lf / entry_name / w 0x16 | 0x28 |
| dir_$mttab_t (`dir.pas`) | count 0x00, mount_uid 0x04, mount_tgt 0x44, mount_node 0x84 | 0xA4 |
| dir_$proc_flags_t (`dir.pas`) | set of 0..15 | 2 |
| dir_$page_flags_t (`dir.pas`) | packed: kind bits 15..14, reclaimable 13, split_mark 12, seg_map_valid 11, unused_6 10..6, format 5..0 | 2 |
| dir_$page_hdr_t (`dir.pas`) | flags 0x00, dir_uid 0x02, page_no 0x0A, next_page 0x0C, index_end 0x0E, heap_base 0x10 | 0x12 |
| dir_$op_tab_entry_t (`dir.ins.pas`) | version 0x00, reply_version 0x02, base_size 0x04, reply_size 0x06 | 8 |
| dir_$readu_cont_t (`dir.ins.pas`) | all 0x00 / entry_idx 0x00, page 0x02 / (sub, index) at 0x00, 0x02 | 4 |
| dir_$readu_entry_t (`dir.ins.pas`; Apollo's name_$canonical_dir_entry_t) | entnxt 0x00, enttype 0x02, entuid 0x04, entextra 0x0C, enthandle 0x10, entlen 0x14, entname 0x16 | 0x116 |
| dir_$readu_old_entry_t (`dir.pas`) | enttype 0x00, entlen 0x02, entuid 0x04, entextra 0x0C, entname 0x10 | 0x110 |

Routines: the map symbols of the five code segments are globals
(MAP_CASE and UNMAP_CASE have no `$`), the other routines module-local
(`internal`), nested where a fragment says so.  None is hand assembly
(there is no `dir/sau2/`).  Ten of OLD_DIR's module-local routines are
of the name_ family (name/README.md); their fragments are
`../name/<file>.pas`, included by `old_dir.pas`.  DIR_$OLD_SET_DAD and
DIR_$OLD_DROPU were translated from the image alone.

## Routines and their fragments

`dir.pas` and `old_dir.pas` include the fragments in image order (the
table's).  Constant cells after a routine's code are named in its
fragment.

| routine | module | kind | fragment |
|---------|--------|------|----------|
| DIR_$INIT | DIR | global | `init.pas` |
| DIR_$OLD_INIT | OLD_DIR | global | `old_init.pas` |
| audit_$log_prot_op | DIR | local | `../audit/log_prot_op.pas` (the AUDIT translation's fragment) |
| dir_$lock_obj | DIR | local | `lock_obj.pas` |
| dir_$unlock_obj | DIR | local | `unlock_obj.pas` |
| dir_$map_page | DIR | local | `map_page.pas` |
| dir_$validate_handle | DIR | local | `validate_handle.pas` |
| dir_$unmap_pages | DIR | local | `unmap_pages.pas` |
| dir_$wire_page | DIR | local | `wire_page.pas` |
| dir_$release_wire | DIR | local | `release_wire.pas` |
| dir_$alloc_handle | DIR | local | `alloc_handle.pas` |
| dir_$free_handle | DIR | local | `free_handle.pas` |
| dir_$release_handle | DIR | local | `release_handle.pas` |
| dir_$open_dir | DIR | local | `open_dir.pas` |
| dir_$is_retryable_status | DIR | local | `is_retryable_status.pas` |
| dir_$update_hint | DIR | local | `update_hint.pas` |
| audit_$log_mount_op | DIR | local | `../audit/log_mount_op.pas` (AUDIT's) |
| audit_$log_link_op | DIR | local | `../audit/log_link_op.pas` (AUDIT's) |
| audit_$log_dir_op | DIR | local | `../audit/log_dir_op.pas` (AUDIT's) |
| audit_$log_cname_op | DIR | local | `../audit/log_cname_op.pas` (AUDIT's) |
| audit_$log_resolve_op | DIR | local | `audit_log_resolve_op.pas` |
| DIR_$DO_OP | DIR | global | `do_op.pas` |
| dir_$find_entry | DIR | local | `find_entry.pas` |
| dir_$lookup_entry | DIR | local, nested in dir_$do_op_get_entryu | `lookup_entry.pas` (included by `do_op_get_entryu.pas`) |
| dir_$get_entry_cached | DIR | local, nested in dir_$do_op_get_entryu | `get_entry_cached.pas` (included by `do_op_get_entryu.pas`) |
| dir_$do_op_get_entryu | DIR | local | `do_op_get_entryu.pas` |
| dir_$get_parent_uid | DIR | local | `get_parent_uid.pas` |
| dir_$do_op_resolve | DIR | local | `do_op_resolve.pas` |
| DIR_$RESOLVE | DIR | global | `resolve.pas` |
| dir_$get_entryu_via_do_op | DIR | local, nested in DIR_$GET_ENTRYU | `get_entryu.pas` |
| DIR_$GET_ENTRYU | DIR | global | `get_entryu.pas` |
| dir_$map_link_page | DIR | local | `map_link_page.pas` |
| dir_$do_op_read_linku | DIR | local | `do_op_read_linku.pas` |
| DIR_$READ_LINKU | DIR | global | `read_linku.pas` |
| dir_$next_page | DIR | local | `next_page.pas` |
| dir_$refind_entry | DIR | local, nested in dir_$do_op_dir_readu | `refind_entry.pas` (included by `do_op_dir_readu.pas`; it uses that routine's locals handle, page_data, base_ptr, entry_ptr, entry_name, path, num_entries, depth, at_eof) |
| dir_$do_op_dir_readu | DIR | local | `do_op_dir_readu.pas` (includes `refind_entry.pas`) |
| dir_$read_canned_root | DIR | local, nested in dir_$dir_readu_fallback (itself nested in DIR_$DIR_READU) | `read_canned_root.pas` (included by `dir_readu_fallback.pas`; it uses the fallback's status_ret and DIR_$DIR_READU's dir_uid, continuation, max_entries, buf_size, buf, count_ret) |
| dir_$dir_readu_fallback | DIR | local, nested in DIR_$DIR_READU | `dir_readu_fallback.pas` (included by `dir_readu.pas`) |
| dir_$dir_readu_via_do_op | DIR | local, nested in DIR_$DIR_READU | `dir_readu_via_do_op.pas` (included by `dir_readu.pas`) |
| DIR_$DIR_READU | DIR | global | `dir_readu.pas` |
| dir_$do_op_find_uid | DIR | local | `do_op_find_uid.pas` |
| dir_$find_uid_internal | DIR | local | `find_uid_internal.pas` |
| DIR_$FIND_UID | DIR | global | `find_uid.pas` |
| DIR_$FIND_NET | DIR | global | `find_net.pas` |
| dir_$truncate_pages | DIR | local | `truncate_pages.pas` |
| dir_$alloc_overflow_page | DIR | local, nested in dir_$add_entry | `alloc_overflow_page.pas` (included by `add_entry.pas`) |
| dir_$purify_split_pages | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `purify_split_pages.pas` (included by `insert_entry.pas`) |
| dir_$alloc_split_page | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `alloc_split_page.pas` (included by `insert_entry.pas`) |
| dir_$finalize_split | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `finalize_split.pas` (included by `insert_entry.pas`) |
| dir_$calc_entry_size | DIR | local, nested in dir_$insert_entry (in dir_$add_entry; linkless) | `calc_entry_size.pas` (included by `insert_entry.pas`) |
| dir_$move_entries_to_page | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `move_entries_to_page.pas` (included by `insert_entry.pas`) |
| dir_$copy_name_cross_page | DIR | local, nested in dir_$write_entry_to_page (in dir_$insert_entry, in dir_$add_entry) | `copy_name_cross_page.pas` (included by `write_entry_to_page.pas`) |
| dir_$write_entry_to_page | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `write_entry_to_page.pas` (included by `insert_entry.pas`) |
| dir_$compact_page_entries | DIR | local, nested in dir_$insert_entry (in dir_$add_entry) | `compact_page_entries.pas` (included by `insert_entry.pas`) |
| dir_$insert_entry | DIR | local, nested in dir_$add_entry | `insert_entry.pas` (included by `add_entry.pas`) |
| dir_$add_entry | DIR | local (the family's parent) | `add_entry.pas` (includes `alloc_overflow_page.pas` and `insert_entry.pas`) |
| dir_$do_op_add_entry | DIR | local | `do_op_add_entry.pas` |
| dir_$add_entry_internal | DIR | local (no map symbol) | `add_entry_internal.pas` |
| DIR_$ADDU | DIR | global | `addu.pas` |
| dir_$do_op_validate_root_entry | DIR | local | `do_op_validate_root_entry.pas` |
| DIR_$VALIDATE_ROOT_ENTRY | DIR | global | `validate_root_entry.pas` |
| dir_$do_op_add_link | DIR | local | `do_op_add_link.pas` |
| DIR_$ADD_HARD_LINKU | DIR | global | `add_hard_linku.pas` |
| DIR_$ADD_LINKU | DIR | global | `add_linku.pas` |
| dir_$add_bak_default_prot | DIR | local, nested in dir_$do_op_add_bak | `add_bak_default_prot.pas` (included by `do_op_add_bak.pas`) |
| dir_$do_op_add_bak | DIR | local | `do_op_add_bak.pas` |
| DIR_$ADD_BAKU | DIR | global | `add_baku.pas` |
| dir_$remove_entry_from_page | DIR | local, nested in dir_$remove_entry (recursive) | `remove_entry.pas` |
| dir_$remove_entry | DIR | local | `remove_entry.pas` |
| dir_$do_op_drop_entry | DIR | local | `do_op_drop_entry.pas` |
| dir_$do_op_delete | DIR | local | `do_op_delete.pas` |
| DIR_$DELETE_FILEU | DIR | global | `delete_fileu.pas` |
| DIR_$DROPU | DIR | global | `dropu.pas` |
| DIR_$DROP_HARD_LINKU | DIR | global | `drop_hard_linku.pas` |
| DIR_$DROP_LINKU | DIR | global | `drop_linku.pas` |
| dir_$do_op_cname | DIR | local | `do_op_cname.pas` |
| DIR_$CNAMEU | DIR | global | `cnameu.pas` |
| dir_$read_def_prot | DIR | local | `read_def_prot.pas` |
| dir_$do_op_get_def_prot | DIR | local | `do_op_get_def_prot.pas` |
| DIR_$GET_DEF_PROTECTION | DIR | global | `get_def_protection.pas` |
| dir_$write_def_prot | DIR | local | `write_def_prot.pas` |
| dir_$do_op_set_def_prot | DIR | local | `do_op_set_def_prot.pas` |
| DIR_$SET_DEF_PROTECTION | DIR | global | `set_def_protection.pas` |
| dir_$do_op_set_prot | DIR | local | `do_op_set_prot.pas` |
| DIR_$SET_PROTECTION | DIR | global | `set_protection.pas` |
| dir_$create_dir_obj | DIR | local | `create_dir_obj.pas` |
| dir_$do_op_create_dir | DIR | local | `do_op_create_dir.pas` |
| dir_$do_op_drop_dir | DIR | local | `do_op_drop_dir.pas` |
| DIR_$CREATE_DIRU | DIR | global | `create_diru.pas` |
| DIR_$DROP_DIRU | DIR | global | `drop_diru.pas` |
| DIR_$SET_DAD | DIR | global | `set_dad.pas` |
| DIR_$ROOT_ADDU | DIR | global | `root_addu.pas` |
| dir_$do_op_set_acl | DIR | local | `do_op_set_acl.pas` |
| DIR_$SET_ACL | DIR | global | `set_acl.pas` |
| dir_$set_default_acl_internal | DIR | local | `set_default_acl_internal.pas` |
| dir_$do_op_set_default_acl | DIR | local | `do_op_set_default_acl.pas` |
| DIR_$SET_DEFAULT_ACL | DIR | global | `set_default_acl.pas` |
| dir_$do_op_get_default_acl | DIR | local | `do_op_get_default_acl.pas` |
| DIR_$GET_DEFAULT_ACL | DIR | global | `get_default_acl.pas` |
| dir_$do_op_add_mount | DIR | local | `do_op_add_mount.pas` |
| dir_$do_op_drop_mount | DIR | local | `do_op_drop_mount.pas` |
| DIR_$ADD_MOUNT | DIR | global | `add_mount.pas` |
| DIR_$DROP_MOUNT | DIR | global | `drop_mount.pas` |
| DIR_$CLEANUP | DIR | global | `cleanup.pas` |
| dir_$validate_pages | DIR | local | `validate_pages.pas` |
| dir_$do_op_fix_dir | DIR | local | `do_op_fix_dir.pas` |
| DIR_$FIX_DIR | DIR | global | `fix_dir.pas` |
| MAP_CASE | OLD_DIR | global | `../file/map_case.pas` (FILE_'s) |
| UNMAP_CASE | OLD_DIR | global | `../file/unmap_case.pas` (FILE_'s) |
| name_$validate_leaf | OLD_DIR | local | `../name/validate_leaf.pas` |
| dir_$old_init_buf | OLD_DIR | local | `old_init_buf.pas` |
| dir_$old_create_obj | OLD_DIR | local | `old_create_obj.pas` |
| name_$unlock_dir | OLD_DIR | local | `../name/unlock_dir.pas` |
| name_$lock_dir | OLD_DIR | local | `../name/lock_dir.pas` |
| DIR_$OLD_CLEANUP | OLD_DIR | global | `old_cleanup.pas` |
| dir_$old_hash_name | OLD_DIR | local | `old_hash_name.pas` |
| dir_$old_find_entry | OLD_DIR | local | `old_find_entry.pas` |
| dir_$old_chain_push | OLD_DIR | local | `old_chain_push.pas` |
| dir_$old_chain_unlink | OLD_DIR | local | `old_chain_unlink.pas` |
| dir_$old_find_free_inline_slot | OLD_DIR | local | `old_find_free_inline_slot.pas` |
| dir_$old_alloc_block | OLD_DIR | local | `old_alloc_block.pas` |
| dir_$old_reclaim_block | OLD_DIR | local | `old_reclaim_block.pas` |
| dir_$old_find_overflow_slot | OLD_DIR | local | `old_find_overflow_slot.pas` |
| dir_$old_free_slot | OLD_DIR | local | `old_free_slot.pas` |
| dir_$old_add_entry | OLD_DIR | local | `old_add_entry.pas` |
| dir_$old_add_entry_ext | OLD_DIR | local | `old_add_entry_ext.pas` |
| dir_$old_add_link_entry | OLD_DIR | local | `old_add_link_entry.pas` |
| dir_$old_delete_entry | OLD_DIR | local | `old_delete_entry.pas` |
| dir_$old_unlink_entry | OLD_DIR | local | `old_unlink_entry.pas` |
| dir_$old_read_link_data | OLD_DIR | local | `old_read_link_data.pas` |
| dir_$old_find_uid_slot | OLD_DIR | local | `old_find_uid_slot.pas` |
| DIR_$OLD_FIND_UID | OLD_DIR | global | `old_find_uid.pas` |
| dir_$old_find_node_slot | OLD_DIR | local | `old_find_node_slot.pas` |
| DIR_$OLD_FIND_NET | OLD_DIR | global | `old_find_net.pas` |
| DIR_$OLD_SET_DAD | OLD_DIR | global | `old_set_dad.pas` |
| DIR_$OLD_FIX_DIR | OLD_DIR | global | `old_fix_dir.pas` |
| DIR_$OLD_READ_INFOBLK | OLD_DIR | global | `old_read_infoblk.pas` |
| DIR_$OLD_WRITE_INFOBLK | OLD_DIR | global | `old_write_infoblk.pas` |
| DIR_$OLD_SET_DEFAULT_ACL | OLD_DIR | global | `old_set_default_acl.pas` |
| DIR_$OLD_GET_DEFAULT_ACL | OLD_DIR | global | `old_get_default_acl.pas` |
| name_$old_add_link_local | OLD_DIR | local | `../name/old_add_link_local.pas` |
| name_$old_add_entry | OLD_DIR | local | `../name/old_add_entry.pas` |
| name_$old_add_link | OLD_DIR | local | `../name/old_add_link.pas` |
| DIR_$OLD_ADDU | OLD_DIR | global | `old_addu.pas` |
| DIR_$OLD_ADD_HARD_LINKU | OLD_DIR | global | `old_add_hard_linku.pas` |
| DIR_$OLD_ROOT_ADDU | OLD_DIR | global | `old_root_addu.pas` |
| name_$old_drop_entry | OLD_DIR | local | `../name/old_drop_entry.pas` |
| DIR_$OLD_DROPU | OLD_DIR | global | `old_dropu.pas` |
| DIR_$OLD_DROP_HARD_LINKU | OLD_DIR | global | `old_drop_hard_linku.pas` |
| name_$old_delete_entryu | OLD_DIR | local | `../name/old_delete_entryu.pas` |
| DIR_$OLD_ADD_BAKU | OLD_DIR | global | `old_add_baku.pas` |
| DIR_$OLD_DELETE_FILEU | OLD_DIR | global | `old_delete_fileu.pas` |
| DIR_$OLD_CREATE_DIRU | OLD_DIR | global | `old_create_diru.pas` |
| DIR_$OLD_DROP_DIRU | OLD_DIR | global | `old_drop_diru.pas` |
| DIR_$OLD_CNAMEU | OLD_DIR | global | `old_cnameu.pas` |
| DIR_$OLD_ADD_LINKU | OLD_DIR | global | `old_add_linku.pas` |
| DIR_$OLD_READ_LINKU | OLD_DIR | global | `old_read_linku.pas` |
| DIR_$OLD_DROP_LINKU | OLD_DIR | global | `old_drop_linku.pas` |
| dir_$old_read_entries | OLD_DIR | local | `old_read_entries.pas` |
| DIR_$OLD_DIR_READU | OLD_DIR | global | `old_dir_readu.pas` |
| name_$old_get_entry_nonroot | OLD_DIR | local | `../name/old_get_entry_nonroot.pas` |
| name_$old_get_root_entry | OLD_DIR | local | `../name/old_get_root_entry.pas` |
| DIR_$OLD_GET_ENTRYU | OLD_DIR | global | `old_get_entryu.pas` |
| DIR_$OLD_VALIDATE_ROOT_ENTRY | OLD_DIR | global | `old_validate_root_entry.pas` |
| DIR_$SERVER | DIR_SERVER | global | `server.pas` |

## Insert files

- `dir.ins.pas` (users: volx, file, name, acl, flop, base, rem_file and
  DIR's own modules): the headings of DIR's and OLD_DIR's globals that
  other units call, DIR_$DO_OP's operation codes (dir_op_addu (16#2A) ..
  dir_op_drop_mount (16#5C)), its request and reply records and their
  bodies, dir_$old_entry_t, the DIR_READU continuation, buffer and entry
  records, the old-format info block, dir_$op_tab_entry_t and the extern
  DIR_$OP_TAB (DIR_SERVER reads the table).
- `dir_server.ins.pas`: DIR_$SERVER's heading and its request and reply
  records (they hold `../acl/acl.ins.pas`'s records); included by
  `dir_server.pas` and REM_FILE_$SERVER's module.
- `dir.pas`: the module's own types (the lock and handle records, the
  page and entry layouts, the entry cache, the mount table, the
  wrappers' request and reply records), the SR10 entry types
  (dir_entry_interior .. dir_entry_soft_link), the externs of DIR_WIRED's
  four objects and of the ten defined variables, DIR_$DIR_READU's extern
  heading (its continuation is rem_name/rem_name.ins.pas's record), and
  the forward headings of the module-local routines called before their
  bodies.
- `old_dir.pas`: the old-format directory's types and the forward
  headings of three module-local routines.
- Other subsystems' insert files hold what DIR's routines call: the
  naming statuses (`../name/name.ins.pas`), FILE_$SET_PROT and the
  protection headings (`../acl/acl.ins.pas`), REM_FILE_$RN_DO_OP and
  REM_FILE_$NAME_GET_ENTRYU (`../rem_file/rem_file.ins.pas`),
  AST_$GET_ACL_ATTRIBUTES (`../ast/ast_acl.ins.pas`), and the AST, FILE,
  REM_NAME, MST, FIM and AUDIT records and headings in their own insert
  files.  name_$complen_max and name_$name_t are
  `../base/base.ins.pas`'s.

## Open items

### Forms worth knowing

- DIR_$DO_OP's 16#2A add-entry, dir_$do_op_validate_root_entry,
  dir_$do_op_add_link, dir_$add_bak_default_prot and
  dir_$do_op_add_bak pass as the link text a zero-length constant cell,
  with the length 0 (the text is never read).
- The family nested in dir_$add_entry (dir_$move_entries_to_page,
  dir_$copy_name_cross_page, dir_$write_entry_to_page,
  dir_$compact_page_entries) reads its parents' state through the
  static links: dir_$insert_entry's variables, and dir_$add_entry's,
  which the recursion shares.  dir_$compact_page_entries's index loop
  runs to insert_entry's num_entries, which at both calls is the page's
  slot count.
- dir_$do_op_add_bak's image merges three duplicated tails (the
  soft-link refusal, the ACL_ failure test with its conversion, the "not
  a file" store); the Pascal writes each in place.
- DIR_$DROPU's constant flag word cell is also dir_$do_op_add_bak's
  ACL_$RIGHTS option word 0.
- dir_$do_op_cname passes a link length and buffer whatever the entry's
  kind (set only for a soft link); dir_$add_entry reads them only for a
  kind-4 entry.
- dir_$old_free_slot unlinks its block inline, dir_$old_chain_unlink's
  steps written again.
- dir_$get_entry_cached turns AST_$GET_DTV's file_$object_not_found
  (16#F0001) into 16#E0033, "directory object not found".
- dir_$read_canned_root sizes an entry (name_len + 16#19) rounded down
  to a multiple of 4, with no terminating 0 after the name, where
  dir_$do_op_dir_readu writes one and sizes from name_len + 16#1A; in
  the current reply format dir_$do_op_dir_readu clears a type-2 entry's
  extra longword.

### TODO(pascal)

- `dir.pas`: the 4-byte OS_INIT_DATA block; the two address cells before
  A5 (the stable dpc now places such cells itself).
- `do_op_cname.pas`: 22 open bytes of dir_$do_op_cname's frame.
- `do_op_get_def_prot.pas`: 4 open bytes of dir_$do_op_get_def_prot's
  frame.
- `remove_entry.pas`: 18 open bytes of dir_$remove_entry's frame and
  the 16 of its nested routine's.
- `do_op_add_bak.pas`: 14 open bytes of dir_$do_op_add_bak's frame.
- `resolve.pas`: DIR_$RESOLVE's request local is 0x100 bytes longer
  than its operation's (the stand-in unused_b0).
- `next_page.pas`: 0x1C bytes of dir_$next_page's frame that no object
  explains.
- `do_op_dir_readu.pas`: 38 open bytes of dir_$do_op_dir_readu's frame,
  16 of them before path.
- `insert_entry.pas`: 14 open bytes of dir_$insert_entry's frame, and
  the first shift loop's limit kept in a local.
- `do_op_find_uid.pas`: 30 bytes of dir_$do_op_find_uid's frame that no
  object explains.
- `add_entry.pas`: 14 bytes of dir_$add_entry's frame that no object
  explains (three words), and dpc's packed layout of the frame the
  nested routines address.
- `alloc_split_page.pas`: AST_$GET_SEG_MAP's location argument, a local
  never assigned (the callee clears it before reading it).
- `create_dir_obj.pas`: 0x30 bytes of dir_$create_dir_obj's frame that
  no object explains.
- `do_op_drop_dir.pas`: 21 bytes of dir_$do_op_drop_dir's frame that no
  object explains.
- `cleanup.pas`: 24 bytes of DIR_$CLEANUP's frame that no object
  explains.
- `validate_pages.pas`: 45 bytes of dir_$validate_pages' frame that no
  object explains.
- `do_op_fix_dir.pas`: 82 bytes of dir_$do_op_fix_dir's frame that no
  object explains.
- `old_dir.pas`: the two char sets (an insert file shared with NAMEU?);
  OLD_DIR's frames against their locals; the 4-byte OS_INIT_DATA block.
- `old_init_buf.pas`: the header's ten bytes copied from a constant in
  the code (FLP_$DINIT's form; five field stores).
- `dir_wired.pas`: the two runs of 4 bytes between DIR_WIRED's objects.
- `server.pas`: ACL_$SET_PROJ_LIST's list argument is UID_$NIL, an
  8-byte UID for acl/acl.ins.pas's `in acl_$proj_uids_t' (0x40 bytes):
  the original's formal was probably `univ'; the Pascal passes the
  address through a pointer transfer.
