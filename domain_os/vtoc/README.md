# The VTOC subsystem in Domain Pascal

The volume table of contents (VTOCE lookup, allocation, reading, writing
and truncation, the file map's trees, the UID cache, volume mount and
dismount).

## Layout

One module, `vtoc.pas`, `module vtoc_;` (the map segments' name), in
the default sections, with an overlay section.  It holds two routines
of other directories: OS_DISK_PROC (`../os/disk_proc.pas`, the first
routine of the .TEXT segment) and FM_$READ and FM_$WRITE
(`../fm/read.pas`, `../fm/write.pas`), the segment's last two.

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | 0x1B4 bytes | VTOCE_$OLD_TO_NEW | `[section(wired_proc, wired_data)]` |
| .TEXT | 0x2364 bytes | OS_DISK_PROC, vtoc_$uid_cache_insert, vtoc_$uid_cache_lookup, vtoc_$hash_uid, VTOCE_$NEW_TO_OLD, VTOC_$MOUNT, VTOC_$DISMOUNT, VTOC_$ALLOCATE, VTOC_$LOOKUP, VTOC_$GET_UID, VTOC_$GET_NAME_DIRS, VTOC_$SET_NAME_DIRS, VTOCE_$READ, VTOCE_$WRITE, vtoc_$fm_traverse (nested), VTOCE_$LOOKUP_FM, vtoc_$free_indirect (nested), VTOCE_$TRUNCATE, FM_$READ, FM_$WRITE | none (the heading's) |

Data: the map's VTOC_ data segment, 0x688 bytes, in .DATA, through A5;
zero but the byte at +0x286:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `vtoc_$mount_locs` | array[1..8] of vtoc_$mount_loc_t (the volumes' mount words) |
| +0x010 | `vtoc_$vols` | array[1..6] of vtoc_$vol_t (100 bytes each) |
| +0x268 | VTOC_CACH_HITS (`define`d, map symbol) | integer32 |
| +0x26C | VTOC_CACH_LOOKUPS (`define`d, map symbol) | integer32 |
| +0x270 | `vtoc_$cach_wp_flag` | array[1..8] of boolean |
| +0x278 | `vtoc_$mounted` | array[1..8] of boolean |
| +0x280 | `vtoc_$format` | array[1..6] of boolean |
| +0x286 | `vtoc_$dirty` | boolean, 16#FF (true) |
| +0x287 | 1 byte: the next object's alignment | |
| +0x288 | `vtoc_$free_list` | array[1..256] of integer32 |

The overlay, the map's VTOC_CACHE load section, 0x1940 bytes: `var
(vtoc_cache) vtoc_$uid_cache: array[0..100] of
vtoc_$uid_cache_bucket_t` (101 buckets of four 16-byte entries),
reached by its address.  OS_DISK_DATA, the map's symbol at the block's
start, is a link mark, no object.  The layouts were checked with a dpc
unit storing to every field.

Routines: fourteen VTOC_ globals (every map symbol of the two code
segments but FM_'s; OS_DISK_PROC has no `$`, as the data's
VTOC_CACH_HITS and _LOOKUPS) and FM_'s two; three module-local
(`internal`, no map symbol): the UID cache's vtoc_$uid_cache_insert,
vtoc_$uid_cache_lookup and vtoc_$hash_uid; two nested: vtoc_$fm_traverse
in VTOCE_$LOOKUP_FM and vtoc_$free_indirect in VTOCE_$TRUNCATE (they
read their static link, and lie before their parents).  None is hand
assembly; there is no `vtoc/sau2/`.

`search_volumes.pas` holds vtoc_$search_volumes, AST_'s module-local
routine (in AST_'s code segment, between AST_$UPDATE and
AST_$LOOKUP_WITH_HINTS, reading AST_'s block through the inherited A5):
`../ast/ast.pas` includes it.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| VTOCE_$OLD_TO_NEW | `old_to_new.pas` |
| OS_DISK_PROC | `../os/disk_proc.pas` |
| vtoc_$uid_cache_insert | `uid_cache_insert.pas` |
| vtoc_$uid_cache_lookup | `uid_cache_lookup.pas` |
| vtoc_$hash_uid | `hash_uid.pas` |
| VTOCE_$NEW_TO_OLD | `new_to_old.pas` |
| VTOC_$MOUNT | `mount.pas` |
| VTOC_$DISMOUNT | `dismount.pas` |
| VTOC_$ALLOCATE | `allocate.pas` |
| VTOC_$LOOKUP | `lookup.pas` |
| VTOC_$GET_UID | `get_uid.pas` |
| VTOC_$GET_NAME_DIRS | `get_name_dirs.pas` |
| VTOC_$SET_NAME_DIRS | `set_name_dirs.pas` |
| VTOCE_$READ | `vtoce_read.pas` |
| VTOCE_$WRITE | `vtoce_write.pas` |
| vtoc_$fm_traverse | `lookup_fm.pas` (nested in VTOCE_$LOOKUP_FM) |
| VTOCE_$LOOKUP_FM | `lookup_fm.pas` |
| vtoc_$free_indirect | `truncate.pas` (nested in VTOCE_$TRUNCATE) |
| VTOCE_$TRUNCATE | `truncate.pas` |
| (FM_$READ, FM_$WRITE) | `../fm/*.pas` (`../fm/README.md`) |
| vtoc_$search_volumes | `search_volumes.pas` (AST_'s) |
| (data) | the block in `vtoc.pas`; VTOC_$UID, VTOC_BKT_$UID and the nil UIDs are UID_LIST's cells (`vtoc.ins.pas`, `../uid/uid.ins.pas`, `../rgyc/rgyc.ins.pas`) |

Each fragment's header has the routine's image address.

Headings (`vtoc.ins.pas`): VTOCE_$OLD_TO_NEW, _$NEW_TO_OLD,
VTOC_$ALLOCATE, _$LOOKUP, _$GET_UID, VTOCE_$READ the default convention
(every argument by address); VTOC_$MOUNT, _$DISMOUNT, _$GET_NAME_DIRS,
_$SET_NAME_DIRS, VTOCE_$WRITE, _$LOOKUP_FM, _$TRUNCATE `val_param`
(words, bytes or longwords read from their slots); OS_DISK_PROC
`val_param` (`../os/os.ins.pas`).  No routine returns a pointer.

## Insert files

- `vtoc.ins.pas`: the statuses, the lock number and the bucket magic;
  the VTOCE header (a packed record), the in-core VTOCE (0x90 bytes),
  the old and new disk entries as full records (the file-map views'
  names kept), the bucket and bucket-block records, fm_$buffer_t's
  variants, the volume record, the location request (with its two
  packed longwords), the audit records, the UID cache's entry and
  bucket, VTOC_$UID, VTOC_BKT_$UID, VTOC_CACH_HITS and _LOOKUPS, and
  every global's heading.  The fm and bat and cal and volx users still
  check.
- `../fm/fm.ins.pas`: `fm_$entry_t`'s blocks indexed from 0
  (VTOCE_$TRUNCATE indexes the direct map by the block number; no
  fragment indexed it but fm/read.pas's zero fill, now 0..31, which
  compiles the same); `fm_$block_addr_t` has a whole-longword variant
  `all` (VTOC_ tests and compares locations whole), its two fields and
  layout unchanged.
- `../bat/bat.ins.pas`: bat_$label_t's vtoc_header is vtoc_$vol_t (the
  same 100 bytes): VTOC_$MOUNT and _$DISMOUNT copy it whole to and from
  the volume's record, a record assignment.  No other user names the
  field; bat.ins.pas needs fm.ins.pas and vtoc.ins.pas before it, which
  every includer has.
- `../os/os.ins.pas`: OS_DISK_PROC's heading.
- `../disk/disk.ins.pas`: DISK_$WRITE_PROTECT's heading.
- `../file/file.ins.pas`: status_$file_volume_has_been_mounted_read_only
  and file_$object_not_found.
- `../uid/uid.ins.pas`: PPO_$NIL_USER_UID and PPO_$NIL_ORG_UID;
  `../rgyc/rgyc.ins.pas`: RGYC_$G_NIL_UID.
- Used as they are: `base`, `ec`, `ml`, `time`, `node`, `acl`, `audit`,
  `misc/crash_system`, `proc1`, `dbuf`, `pkt`, `route` (ROUTE_$PORT's
  first longword), `network` (NETWORK_$REALLY_DISKLESS), `netlog`
  (NETLOG_$OK_TO_LOG, NETLOG_$LOG_IT), `bat` (BAT_$MOUNT, _$DISMOUNT,
  _$ALLOCATE, _$FREE, _$ALLOC_FM, _$ADD_PART_VTOCE, _$ALLOC_VTOCE).

## Open items

### Names and forms

- The image has room for 8 write-protect flags and 6 format flags in
  the block (vtoc.pas).
- OS_DISK_PROC's argument and the cache entries' word are the cache
  entry's volume (VTOC_$DISMOUNT passes its volume).
- AST_'s block word at +0x420 is the set of volumes being dismounted
  (vtoc_$search_volumes tests a member).
- The location request is three types for one record
  (vtoc_$lookup_req_t, file_$obj_loc_t, fm_$file_ref_t); the tree keeps
  the three.

### TODO(pascal)

- `vtoc.pas`: the module's frames: bytes no object explains in most
  routines, not held by stand-ins.
- `old_to_new.pas`: the 12-byte ACL cell copied from a constant in the
  code (FLP_$DINIT's case).

## Named dispatch codes

VTOC_$MOUNT passes DISK_$WRITE_PROTECT's mode as
`disk_$write_protect_set` (disk/disk.ins.pas, disk's dispatch-code
block).
