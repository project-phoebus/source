# The PMAP subsystem in Domain Pascal

The page purifier and working-set scanner (PMAP_: writing a segment's
dirty pages back, the two purifier processes, the purifier, update and
working-set timers and their callbacks).

## Layout

One module, `pmap.pas`, `module pmap_, wired_proc, wired_data;` (the map
segments' name), one compilation unit: both code segments reach the one
WIRED_DATA block, the WIRED_PROC routines through A5, the OS_INIT_PROC
routine by its address.

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | 0x19E4 bytes (SAU9 0x1948) | pmap_$wait_in_transit, pmap_$write_complete, pmap_$write_page, pmap_$fill_write_qblks, pmap_$update_seg_map (nested), pmap_$flush_write_batch (nested), PMAP_$FLUSH, PMAP_$WAKE_PURIFIER, PMAP_$PURIFIER_L, PMAP_$PURIFIER_R, PMAP_$UPDATE_CALLBACK, PMAP_$T_PURIF_CALLBACK, PMAP_$WS_SCAN_CALLBACK, PMAP_$INIT_WS_SCAN, PMAP_$PURGE_WS | none (the heading's) |
| OS_INIT_PROC | 0xD8 bytes | pmap_$init_timers | `[section(os_init_proc, os_init_data)]` |

Data: the map's PMAP_ data segment in WIRED_DATA, 0x7A4 bytes (the
module's variables and the map symbols it `define`s, in block order):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `pmap_$update_timer` | time_$queue_elem_t (0x1A) |
| +0x01A | `unused_1a`, a stand-in (TODO) | 6 bytes |
| +0x020 | `pmap_$purifier_timer` | time_$queue_elem_t |
| +0x03A | `unused_3a`, a stand-in (TODO) | 6 bytes |
| +0x040 | `pmap_$ws_timer` | array[1..64] of pmap_$ws_slot_t (0x1C each) |
| +0x740 | PMAP_$IDLE_INTERVAL, _$T_PUR_SCANS, _$PUR_R_CNT, _$PUR_L_CNT (defined) | integer32 each; 1596, 0, 0, 0 |
| +0x750 | PMAP_$PAGES_EC, _$R_PURIFIER_EC, _$L_PURIFIER_EC (defined) | ec_$eventcount_t each, self-linked |
| +0x774 | MOUNT_LOCK (defined; no `$`) | ml_$exclusion_t, self-linked, f5 = -1 |
| +0x786 | `unused_786`, a stand-in (TODO) | integer |
| +0x788 | PMAP_$SCAN_FRACT .. PMAP_$WS_INTERVAL (defined) | words: 1, 0, 0, 2, 1, 8, 5 |
| +0x796 | PMAP_$SHUTTING_DOWN_FLAG (defined) | boolean |
| +0x798 | `pmap_$short_wait_delay` | time_$clock_t, (0, 5) |
| +0x79E | `pmap_$ws_random_seed` | pinteger, 16#4D |
| +0x7A0 | `pmap_$current_slot` | pinteger, 5 |

The load section OS_PMAPS holds MMAP, the page-entry table
(mmap/mmap.ins.pas), not PMAP data; the segment map PMAP_ walks is AST_'s
AST_PMAPS (ast/ast.ins.pas).

Routines: PMAP_$FLUSH, _$WAKE_PURIFIER, _$PURIFIER_L, _$PURIFIER_R,
_$UPDATE_CALLBACK, _$T_PURIF_CALLBACK, _$WS_SCAN_CALLBACK, _$INIT_WS_SCAN
and _$PURGE_WS are globals (every map symbol of the code segments); five
are module-local (`internal`, no map symbol): pmap_$wait_in_transit,
pmap_$write_complete, pmap_$write_page, pmap_$fill_write_qblks and
pmap_$init_timers; two are nested in PMAP_$FLUSH, pmap_$update_seg_map
(the static link: its sibling calls it) and pmap_$flush_write_batch (the
dynamic link).  None is hand assembly (there is no `pmap/sau2/`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| pmap_$wait_in_transit | `wait_in_transit.pas` |
| pmap_$write_complete | `write_complete.pas` |
| pmap_$write_page | `write_page.pas` (its word shift inline) |
| pmap_$fill_write_qblks | `fill_write_qblks.pas` (the ASTE lookup and the neighbor scans inline) |
| pmap_$update_seg_map | `flush.pas` (nested in PMAP_$FLUSH, before it in the image) |
| pmap_$flush_write_batch | `flush.pas` (nested in PMAP_$FLUSH) |
| PMAP_$FLUSH | `flush.pas` |
| PMAP_$WAKE_PURIFIER | `wake_purifier.pas` |
| PMAP_$PURIFIER_L | `purifier_l.pas` (the AOTE lookup and the working-set pass inline) |
| PMAP_$PURIFIER_R | `purifier_r.pas` |
| PMAP_$UPDATE_CALLBACK | `update_callback.pas` |
| PMAP_$T_PURIF_CALLBACK | `t_purif_callback.pas` |
| PMAP_$WS_SCAN_CALLBACK | `ws_scan_callback.pas` |
| PMAP_$INIT_WS_SCAN | `init_ws_scan.pas` |
| PMAP_$PURGE_WS | `purge_ws.pas` |
| pmap_$init_timers | `init_timers.pas` |
| (data) | the variables in `pmap.pas` |

Headings: PMAP_$FLUSH, _$WAKE_PURIFIER, _$INIT_WS_SCAN and _$PURGE_WS
`val_param` (words and bytes read from their slots); the callbacks and
the purifier bodies the default convention.  PMAP_$FLUSH's heading and
pmap_$flush_flags_t are in `pmap_flush.ins.pas`, not `pmap.ins.pas`,
because the heading takes AST_'s records, which that insert's
includers (disk/disk_vol.pas, proc1/proc1.pas) do not include;
`pmap.pas` and `../ast/ast.pas` include it.  No routine returns a
pointer, so no D0 parking.  `pmap.pas` has a forward `internal` heading
for pmap_$init_timers (OS_INIT_PROC, after its caller);
pmap_$write_page and pmap_$fill_write_qblks come before their callers,
so their headings are in their fragments (the callers' pushes agree
with them: the page number by value, the status `var` and the byte by
value; the list `in`, the request and the count by value).
PMAP_$PURIFIER_L and _$PURIFIER_R are in the define list, in map order;
they take no arguments (process entry points: OS_$INIT pushes their
addresses) and end in endless loops with no epilogue.

## Insert files

- `pmap.ins.pas`: the three interval words pinteger (PMAP_ compares
  them unsigned); PMAP_$INIT_WS_SCAN's index pinteger (widened with
  zeros); the PMAP statuses (from the SR10.2 status tables),
  PMAP_$MID_THRESH, _$LOW_THRESH, _$WS_SCAN_DELTA, _$SHUTTING_DOWN_FLAG,
  the headings of PMAP_$WAKE_PURIFIER, _$PURIFIER_L, _$PURIFIER_R, the
  three callbacks, and pmap_$ws_scan_arg_t.  It needs only base and ml.
  Users: disk/disk_vol.pas, osinfo/osinfo.pas, proc1/proc1.pas.
- `ast/ast.ins.pas`: ast_$aote_t's DTU, DTV, DTA clocks (0x30, 0x38,
  0x40), its fields from 0x9C to 0xB8 (unknown_9c, unknown_9d,
  unknown_9e, obj_loc_uid, obj_loc_addr, obj_loc_res_18, vol_index),
  length linteger (compared unsigned), loc_flags a signed byte
  (ast_$sbyte_t: `set of 0..7`, which a word holds, put every field
  after it late) and flags one word set at 0xBE (MMAP's two tests of
  loc_flags' bit 7 are `loc_flags < 0`, mmap/trim_wsl.pas,
  mmap/release_pages.pas; PMAP_$FLUSH's `flags + [5]`), checked with a
  dpc probe (`../tmp/pmap2a/lay`); ast_$aste_t's flags the word set
  ast_$aste_flags_t; ast_$byte_t, ast_$sbyte_t, ast_$pmap_entry_ptr_t,
  three AST statuses; the headings of AST_$INVALIDATE_PAGE, AST_$UPDATE
  and AST_$SAVE_CLOBBERED_UID.
- `mmap/mmap.ins.pas`: the page entry's disk address the packed record
  mmap_$daddr_t (the whole longword, or bits 31..23, aste_dirty at bit
  22 and the 22-bit address); the pointer type mmap_$mmape_ptr_t;
  MMAP_$PAGEABLE_PAGES linteger (PMAP_$PURIFIER_L divides it unsigned;
  MMAP's own code only adds and subtracts).
- `area/area.ins.pas`: AREA_'s internal-error status, area_$entry_t
  (0x30 bytes, checked with the probe), AREAS, AREA_$PARTNER and
  AREA_$PARTNER_PKT_SIZE.  An area segment's ASTE names an area entry
  in place of an AOTE; its words at 0x24, 0x2A are the entry's volx
  and area_id.
- `anon/anon.ins.pas`: ANON_$UID.
- `network/network.ins.pas`: network_$page_request_t (32 bytes,
  checked), NETWORK_$WRITE_VIOL_CNT and NETWORK_$WRITE's heading
  (`val_param`).
- `disk/disk.ins.pas`: a third view of disk_$block_hdr_t, the bytes
  0x10, 0x11, 0x12..0x1B pmap_$fill_write_qblks writes one by one.
- `log/log.ins.pas` (LOG_$UPDATE, LOG_$LOGFILE_PTR), `cal/cal.ins.pas`
  (CAL_$SHUTDOWN).
- Used as they are: `ec`, `ml`, `time`, `misc/crash_system`, `uid`,
  `file`, `mmu` (the PFT, MMU_$REMOVE, MMU_$PURGE), `proc1`, `netlog`, `disk`,
  `pkt`, `fm`, `vtoc`, `bat` (BAT_$ALLOCATE).

## The other SAUs' forms

The parts (`base/config.ins.pas`) that change PMAP_:

- `pmmu_page_maps` (SAU7..SAU9): the page-map entries' in-transit and
  installed bits are ast_$pmap_in_trans and ast_$pmap_installed, a
  page's modified and used bits its descriptor's (ast_$pmap_modified,
  ast_$pmap_used), not the PFT's.  A page taken out of the MMU has its
  descriptor's resident bit cleared and the translations flushed
  (MMU_$PURGE) instead of MMU_$REMOVE, and PMAP_$FLUSH flushes them
  before each write and batch: `flush.pas`, `write_page.pas`,
  `fill_write_qblks.pas`, `write_complete.pas`, `purifier_l.pas`,
  `purifier_r.pas`.
- `boot_time_lock` (SAU2, SAU5): the purifiers start by taking and
  giving back lock 1, which OS_$INIT holds while a node without a
  calendar fetches the time; the other SAUs have neither.
- `mmap_ppns_10000` (SAU9), `mmap_ppns_400` (SAU8): PMAP_$FLUSH's
  pageable range is mmap_$first_ppn..mmap_$last_ppn, and the
  purifiers reach MMAP's entries from that lower bound.

The large-VM layouts (the 28-byte ASTE, the 21-bit disk address in
MMAP's entries) come in through the types alone.  The rest of the
SAU9's PMAP_ code, and its data block, is the SAU2's source compiled
for the 68020; the SAU8's is the SAU9's with its own pageable range.

## Open items

### Source forms

- PMAP_$FLUSH's batch, count, segment map and status are reached by
  its two nested routines in the parent's frame, not passed.
- PMAP_$FLUSH's flags are a word set whose members 0, 1 and 2 are
  tested on its low byte.
- PMAP_$UPDATE_CALLBACK and PMAP_$PURGE_WS load A5 and use nothing of
  the block.
- pmap_$fill_write_qblks reads pages[i] at each use (no page-number
  local).
- PMAP_$PURIFIER_L's count from MMAP_$GET_IMPURE is one longword (the
  routine writes one there); PMAP_$PURIFIER_R's carryover test falls
  into the clear, as PMAP_$PURIFIER_L's does.

### TODO(pascal)

- `pmap.pas`: the block's three unaddressed gaps (+0x01A, +0x03A,
  +0x786), stand-ins.
- `pmap.pas`: the frames of pmap_$write_complete,
  PMAP_$T_PURIF_CALLBACK, _$WS_SCAN_CALLBACK, _$INIT_WS_SCAN,
  pmap_$init_timers, PMAP_$FLUSH, pmap_$write_page,
  pmap_$fill_write_qblks, PMAP_$PURIFIER_L and _$PURIFIER_R against
  their locals (no stand-ins).
- `ws_scan_callback.pas`: what the callback's argument points to (the
  word at +2 read as the process's number, where TIME_$Q_SCAN_QUEUE
  passes the element's pointer by address and PMAP_$INIT_WS_SCAN stores
  the number as the element's callback_arg).
- `purifier_l.pas`: the deadlines are compared signed with the clock and
  unsigned with each other in both purifiers; no one declaration gives
  both while TIME_$CLOCKH is linteger (the clock is transferred to
  integer32 in the two comparisons).
