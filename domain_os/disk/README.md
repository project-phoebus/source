# The DISK subsystem in Domain Pascal

The disk manager (the queue blocks and their pool, the elevator queues,
the request chains' mapping onto physical volumes and their transfer,
the error record and log, the driver table, the volumes' mounting and
assignment).

Two routines of other map modules are here too: DISK_INTERRUPT,
`interrupt.pas`, included by ATBUS_'s module file `../sysbus/atbus_.pas`,
and CHKSUM, `chksum_page.pas`, included by the CHKSUM module's file
`chksum.pas` (below).

## Layout

The map's DISK_ module is **three compilation units that carry one module
name**: each code segment loads its own data block as A5 and no other (a
byte search of the image finds each block's address only in its own
unit), and the first two pairs are adjacent in the map, as separately
compiled modules linked in order are.  So there is one
module file per unit, each `module disk_;`; the checker finds all three
by their headings:

| file | code | data | routines |
|------|------|------|----------|
| `disk.pas` | the map's first DISK_ code segment, 0x1E2C bytes, .TEXT | its first DISK_ data segment, 0xB90 bytes, .DATA | the request layer: GET_BLOCK .. WRITE_PROTECT (26 routines, 3 of them nested) |
| `disk_dev.pas` | the second, 0x2A8 bytes, .TEXT | the second, 0x198 bytes, .DATA | the driver table: REGISTER .. SHUTDOWN (9 routines) |
| `disk_vol.pas` | the third, 0x1AF0 bytes, .TEXT | the third, 0x64 bytes, .DATA | the volumes: diskless_init .. LVUID_TO_VOLX (24 routines, 2 of them nested) |

All six segments are in the default sections, so no routine has a
section attribute.  The module files' address tables give the blocks'
addresses.  Loop alignment: the first unit aligns up to DISK_$INVALIDATE
and not from disk_$grow_qblk_pool on (its `--loop-align-off-from`
routine); the second aligns throughout; the third aligns through
DISK_$LV_MOUNT and not at DISK_$LVUID_TO_VOLX.

### The first unit's block (`disk.pas`), 0xB90 bytes

Zero but the words 1 at +0xAF2 and +0xAF4:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `disk_$ec` | ec_$eventcount_t |
| +0x00C | `unused_0c`, a stand-in (`disk.pas`, the TODO) | integer32 |
| +0x010 | `disk_$req_queue` | array[1..64] of pinteger (the waiting counts' ring) |
| +0x090 | `disk_$exclusion` | ml_$exclusion_t (the queue blocks' lock) |
| +0x0A2 | `unused_a2`, `unused_a4`, stand-ins | integer, integer32 |
| +0x0A8 | `disk_$exclusion_2` | ml_$exclusion_t (DISK_IO's lock) |
| +0x0BC | `disk_$reserve_block` | disk_$io_req_ptr_t |
| +0x0C0 | `disk_$free_head` | disk_$io_req_ptr_t |
| +0x0C4 | DISK_$DVTBL (`define`d, map symbol) | array[1..10] of disk_$volume_t |
| +0x394 | DISK_BPTBL (`define`d, map symbol) | array[1..64] of disk_$bp_slot_t |
| +0xA94 | DISK_$ERROR_INFO (`define`d, map symbol) | disk_$error_info_t (0x56) |
| +0xAEA | 2 bytes: the next longword's alignment | |
| +0xAEC | DISK_$RAW_PPN (`define`d, map symbol) | integer32 |
| +0xAF0 | `disk_$pages_alloc` | pinteger |
| +0xAF2 | `disk_$req_read_idx` | pinteger := 1 |
| +0xAF4 | `disk_$req_write_idx` | pinteger := 1 |
| +0xAF6 | `disk_$pending_count` | integer |
| +0xAF8 | DISK_$NFBLKS (`define`d, map symbol) | integer |
| +0xAFA | `disk_$alloc_disabled` | boolean |
| +0xAFC | `disk_$reserve_avail` | boolean |
| +0xAFE | DISK_$DIAG (`define`d, map symbol) | boolean |
| +0xB00 | DISK_$DO_CHKSUM (`define`d, map symbol) | boolean |
| +0xB02 | `unused_b02`, `unused_b04`, stand-ins | integer, integer32 |
| +0xB08 | `disk_$que_array` | array[0..33] of disk_$io_req_ptr_t (DISK_$ADD_QUE's runs) |

### The second unit's block (`disk_dev.pas`), 0x198 bytes

All zero:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `disk_$devices` | array[1..32] of disk_$device_entry_t |
| +0x180 | `stats_template`, DISK_$GET_STATS' static | disk_$stats_t (0x16) |
| +0x196 | 2 bytes: the block's rounding to 4 | |

### The third unit's block (`disk_vol.pas`), 0x64 bytes

The three objects are disk_$pv_mount_internal's statics (their only
readers are it and its nested finder), declared in that routine
(`pv_mount_internal.pas`), so the unit's heading names no section:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `vol_template` | disk_$volume_t := [addr_start 1, sec_per_track 1, num_heads 2, blocks_per_cyl 4, bat_step 1, num_parts 1] |
| +0x48 | `log2_table` | array[0..9] of pinteger := 0 0 1 0 2 0 0 0 3 0 |
| +0x5C | `pow2_table` | array[0..3] of pinteger := 1 2 4 0 |

## Routines and fragments

Unit 1 (`disk.pas`), in image order.  Globals: every map symbol of the
segment (DISK_IO has no `$`).  Module-local (`internal`, no
map symbol): the lower-case routines.  Nested: DISK_$SORT's exchange and
DISK_$ADD_QUE's two merges (they read the static link, or lie in the
family).

| routine | fragment |
|---------|----------|
| DISK_$GET_BLOCK | `get_block.pas` |
| DISK_$SET_BUFF | `set_buff.pas` |
| DISK_$INVALIDATE | `invalidate.pas` |
| disk_$grow_qblk_pool | `grow_qblk_pool.pas` (before its caller: no forward heading) |
| disk_$get_qblks_internal | `get_qblks_internal.pas` |
| DISK_$GET_QBLKS | `get_qblks.pas` |
| disk_$rtn_qblks_internal | `rtn_qblks_internal.pas` |
| DISK_$RTN_QBLKS | `rtn_qblks.pas` |
| DISK_$INIT | `init.pas` |
| disk_$io_error | `io_error.pas` |
| disk_$sort_swap_entries | `sort.pas` (nested in DISK_$SORT) |
| DISK_$SORT | `sort.pas` |
| DISK_$INIT_QUE | `init_que.pas` |
| disk_$add_que_merge_ascending | `add_que.pas` (nested in DISK_$ADD_QUE) |
| disk_$add_que_merge_descending | `add_que.pas` (nested in DISK_$ADD_QUE) |
| DISK_$ADD_QUE | `add_que.pas` |
| disk_$wait_io | `wait_io.pas` |
| DISK_$WAIT_QUE | `wait_que.pas` |
| disk_$map_request | `map_request.pas` |
| DISK_$WRITE | `write.pas` |
| disk_$set_chain_status | `set_chain_status.pas` (the byte-identical conformance unit `disk_set_chain_status.pas`) |
| DISK_$WRITE_MULTI | `write_multi.pas` |
| DISK_$READ | `read.pas` |
| DISK_$READ_MULTI | `read_multi.pas` |
| DISK_$FORMAT_WHOLE | `format_whole.pas` |
| DISK_$FORMAT | `format.pas` |
| DISK_IO | `io.pas` |
| DISK_$WRITE_PROTECT | `write_protect.pas` |
| (data) | the variables in `disk.pas` |

Unit 2 (`disk_dev.pas`): all globals, none module-local or nested.

| routine | fragment |
|---------|----------|
| DISK_$REGISTER | `register.pas` |
| DISK_$GET_DRTE | `get_drte.pas` |
| DISK_$MNT_DINIT | `mnt_dinit.pas` |
| DISK_$DO_IO | `do_io.pas` |
| DISK_$ERROR_QUE | `error_que.pas` |
| DISK_$SPIN_DOWN | `spin_down.pas` |
| DISK_$REVALID | `revalid.pas` |
| DISK_$GET_STATS | `get_stats.pas` |
| DISK_$SHUTDOWN | `shutdown.pas` |
| (data) | the variable in `disk_dev.pas`, GET_STATS' static |

Unit 3 (`disk_vol.pas`).  Globals: every map symbol of the segment
(AS_IO_SETUP has no `$`).  Module-local: disk_$diskless_init
and disk_$pv_mount_internal.  Nested in disk_$pv_mount_internal: the slot
finder (it reads its static link) and the label check (in the family:
between the nested finder and the parent, which is its only caller).

| routine | fragment |
|---------|----------|
| disk_$diskless_init | `diskless_init.pas` |
| AS_IO_SETUP | `as_io_setup.pas` |
| DISK_$READ_MFG_BADSPOTS | `read_mfg_badspots.pas` |
| DISK_$AS_READ | `as_read.pas` |
| DISK_$AS_WRITE | `as_write.pas` |
| DISK_$AS_XFER_MULTI | `as_xfer_multi.pas` |
| DISK_$DIAG_IO | `diag_io.pas` |
| DISK_$UNASSIGN | `unassign.pas` |
| DISK_$UNASSIGN_ALL | `unassign_all.pas` (the byte-identical conformance unit `disk_unassign_all.pas`) |
| DISK_$GET_MNT_INFO | `get_mnt_info.pas` |
| DISK_$REVALIDATE | `revalidate.pas` |
| DISK_$GET_ERROR_INFO | `get_error_info.pas` |
| DISK_$AS_OPTIONS | `as_options.pas` |
| disk_$pvmi_find_slot | `pv_mount_internal.pas` (nested in disk_$pv_mount_internal) |
| disk_$validate_pv_label | `pv_mount_internal.pas` (nested in disk_$pv_mount_internal) |
| disk_$pv_mount_internal | `pv_mount_internal.pas` |
| DISK_$PV_ASSIGN_N | `pv_assign_n.pas` |
| DISK_$PV_ASSIGN | `pv_assign.pas` |
| DISK_$PV_MOUNT | `pv_mount.pas` |
| DISK_$LV_MOUNT | `lv_mount.pas` |
| DISK_$LV_UID | `lv_uid.pas` |
| DISK_$LV_ASSIGN | `lv_assign.pas` |
| DISK_$DISMOUNT | `dismount.pas` |
| DISK_$LVUID_TO_VOLX | `lvuid_to_volx.pas` |
| (data) | disk_$pv_mount_internal's statics |

Routines of other map modules whose fragments are in `disk/`:

| routine | fragment | module file |
|---------|----------|-------------|
| DISK_INTERRUPT | `interrupt.pas` | `../sysbus/atbus_.pas` (the map's ATBUS_ code segment, 0x118 bytes, WIRED_PROC; the module's first routine) |
| CHKSUM | `chksum_page.pas` | `chksum.pas` (the map's CHKSUM code segment, 0x84 bytes, WIRED_PROC, the module's one routine; no data) |

- `chksum.pas` is `module chksum;` (the map's name), with no sections in
  its heading (no module variables) and the routine headed
  `[section(wired_proc, wired_data)]`, as `../dma/dma.pas`.  The file is
  in `disk/` because the routine's caller (DISK_IO) is.  It carries
  CHKSUM_$GET_CHKSUM's heading (hand assembly, CHKSUM_ASM) under a
  TODO(merge) for `../chksum/chksum.ins.pas`.  CHKSUM uses its reviewed
  heading in `chksum/chksum.ins.pas` unchanged.
- `interrupt.pas` reads the shared disk register block's status word
  through the type-1 (floppy) DCTE as `flp/flp.ins.pas`'s word set and
  calls the type-1 or type-0 controller's do_io routine through ATBUS_'s
  block; its crash status, `status_$disk_unrecognized_interrupt`
  (16#00080026), is in `disk.ins.pas`.

No routine of the three units is hand assembly (no `disk/sau2/`).  None
returns a pointer that its callers park in D0, but DISK_$GET_BLOCK: one
of its six callers (the label check in unit 3) copies the result to D0,
the others to address registers, so its heading keeps the pointer
result (the conformance unit's).  That caller is no D0-parking one: its
pointer local shares D0 with its own pointer result, which goes back in
A0, so it is written with a pointer local and no
conversion.

Headings (`disk.ins.pas`): the user entries DISK_$FORMAT_WHOLE and
_$FORMAT, and DISK_$INIT_QUE, _$GET_DRTE, _$DO_IO, _$REVALID, _$SORT and
_$REGISTER the default convention; the rest of the first two units
`val_param` (words and longwords read from the slots).  The third unit:
the SVC entries (READ_MFG_BADSPOTS, AS_READ, AS_WRITE, AS_XFER_MULTI,
DIAG_IO, UNASSIGN, GET_MNT_INFO, GET_ERROR_INFO, AS_OPTIONS, PV_ASSIGN_N,
PV_ASSIGN, LV_ASSIGN), UNASSIGN_ALL, LV_MOUNT and LVUID_TO_VOLX the
default convention; AS_IO_SETUP, PV_MOUNT, LV_UID, DISMOUNT and
REVALIDATE `val_param`.  The driver's entries are routine-pointer types,
`disk_$*_proc_t`, converted at each call from the jump table's univ_ptr
cells.

## Insert files

- `disk.ins.pas`: the module's statuses, types, variables and headings;
  it needs `ec/ec.ins.pas` before it (disk_$bp_slot_t's eventcounts).
  It names DISK_IO's operations (`disk_$io_*`), a
  queue block's owner_op.op (`disk_$req_op_*`) and DISK_$WRITE_PROTECT's
  modes; used in disk/io, read, write, as_read, as_write,
  read_mfg_badspots, read_multi, write_multi, diag_io, format,
  format_whole, map_request, write_protect, and by flp/flp_do_io,
  win/do_io, win/read_or_write_disk_record and vtoc/mount.
- status_$disk_driver_logic_error (WIN_$CHECK_DISK_STATUS's too) is
  declared in `disk.ins.pas`, which precedes `win/win.ins.pas` in
  `win/win.pas`.
- What the units take from other insert files: `uid/uid.ins.pas`
  PV_LABEL_$UID; `acl/acl.ins.pas` ACL_$IS_SUSER; `cache/cache.ins.pas`
  CACHE_$FLUSH_VIRTUAL (hand assembly); `os/os.ins.pas` the OS_DISK
  markers; `pmap/pmap.ins.pas` MOUNT_LOCK (an ml_$exclusion_t, so the
  file needs ml first); `mmu/mmu.ins.pas` MMU_$MCR_CHANGE (hand
  assembly); `chksum/chksum.ins.pas` CHKSUM's heading; and, as they are,
  `ec`, `ml`, `time`, `proc1`, `proc2`, `log`, `mst`, `wp`, `mmap`,
  `mmu`, `netlog`, `dbuf`, `io`, `network`, `bat`, `audit`,
  `misc/crash_system`.

Layout facts the records depend on:
- disk_$io_req_t's owner (0x1E) and flags (0x1F) are one 2-byte packed
  record, `owner_op: disk_$owner_op_t`: a record
  field cannot sit at 0x1F (the comment in
  `disk.ins.pas`).  Its users read `req.owner_op.owner`, `.all`, `.op`,
  `.chksum`, `.mark`: `disk/add_que.pas`, `as_xfer_multi.pas`,
  `format.pas`, `format_whole.pas`, `get_qblks_internal.pas`, `io.pas`,
  `map_request.pas`, `write_multi.pas`, `flp/flp_do_io.pas`,
  `flp/format_track.pas`, `win/do_io.pas`, `win/format_track.pas`,
  `win/read_or_write_disk_record.pas`, `pmap/fill_write_qblks.pas`.
- disk_$bp_slot_t's pad is three chars, not a 3-char array, which is
  word aligned (ref 3.10.5.5) and made the slot 0x1E bytes where the
  image's are 0x1C.

## Open items

### Names and forms

- The device entry's field names are misleading: the
  word at +0x08 (unit_count) is the driver's flags word (bit 9 the
  block-addressed drive or the own queue, bits 11 and 14 tested by
  DISK_$WRITE_MULTI), and DISK_$REGISTER stores its third argument there
  (FLP passes its unit count); +0x0A (flags) is DISK_$ADD_QUE's ML lock
  number.
- The jump table's entry at 0x0C is the revalidate entry (DISK_$REVALID,
  FLP_$REVALIDATE); disk_$que_t's first longword (current) is
  DISK_$ADD_QUE's spin lock.
- DISK_$ERROR_QUE is a procedure: no caller reads a function result.
- AS_IO_SETUP is a map symbol, a global; CHKSUM too.
- READ_MFG_BADSPOTS, AS_READ, AS_WRITE and DIAG_IO take the caller's
  page by address, whose address (the slot) is checked and wired.
- The slot finder and the label check are nested in
  disk_$pv_mount_internal (the finder reads the parent's cells through
  its static link); the parent has no map symbol.
- DISK_$PV_ASSIGN_N's and DISK_$PV_MOUNT's unit_id cells are the unit id
  the dinit fills; DISK_$PV_ASSIGN_N's fifth argument gets that unit id,
  not a volume index (the internal's result, the index, is not read).
- The partition words and the mount flags of DISK_$GET_MNT_INFO are
  packed records' fields (`disk.ins.pas` disk_$part_info_t,
  disk_$mnt_flags_t).
- DISK_$ADD_QUE's merges are nested and reach the parent's group_end
  through the static link.
- DISK_IO and DISK_$READ_MULTI compare the header's first two longwords
  as one 8-byte record (the UID) and the third (the hint) alone.
- disk_$set_chain_status's callers pass constant cells, an `in univ'
  parameter (the conformance unit's `var' has no caller).

### TODO(pascal)

- `disk.pas`: the first block's three gaps (+0x0C, +0xA2, +0xB02),
  stand-ins; 8-byte alignment from the block's start fits them but not
  the volume table nor the process slots.
- `disk.pas`: the first unit's frames against their locals (the
  register-held locals' slots, DISK_$INIT's 4 bytes; disk_$grow_qblk_pool,
  DISK_$WRITE_MULTI and DISK_$READ_MULTI 12 bytes no object's,
  DISK_$FORMAT 16 bytes below its locals, DISK_IO).
- `disk_dev.pas`: the second unit's frames, 8 bytes in each routine that
  calls through the jump table.
- `disk_vol.pas`: the third unit's frames against their locals (the
  bytes no object fills, routine by routine).
- `read_multi.pas`: the failed block's search tests its pointer before a
  `while' that tests it again; the source construct is not identified.
