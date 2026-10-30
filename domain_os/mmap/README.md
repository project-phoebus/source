# The MMAP subsystem in Domain Pascal

The physical memory map and the working set lists (the page entries'
lists, the free, pure, impure, dirty and wired pools, the address
spaces' lists, the paging daemon's scans and trims, the allocators and
the boot-time map).

## Layout

Two map modules, two module files (the checker finds the second by its
heading):

| file | heading | code | data |
|------|---------|------|------|
| `mmap.pas` | `module mmap_, wired_proc, wired_data;` | WIRED_PROC, MMAP_, 0x14D8 bytes (SAU9 0x16A0) | WIRED_DATA, MMAP_, 0xAA8 bytes, through A5 |
| `mmap_unwired.pas` | `module mmap_unwired;` | OS_INIT_PROC, MMAP_UNWIRED, 0x278 bytes (SAU9 0x290; `[section(os_init_proc, os_init_data)]`); .TEXT, MMAP_UNWIRED, 0xC bytes | none (the MMAP_ block by its symbols' addresses) |

The MMAP_ block (zero but the seeds below), module variables in
`mmap.pas`, the map symbols `define`d:

| offset | variable | type | image |
|--------|----------|------|-------|
| +0x000 | `mmap_$lock` (no map symbol) | integer32 | 0 |
| +0x004 | MMAP_$HI_INDX | integer32 | mmap_$last_ppn (16#FFF; SAU9 16#1FFFF) |
| +0x008 | MMAP_$LO_INDX | integer32 | mmap_$first_ppn (16#200; SAU9 16#10000) |
| +0x00C..+0x028 | MMAP_$WS_REMOVE, _$RECLAIM_PUR_CNT, _$RECLAIM_SHAR_CNT, _$WS_SCAN_CNT, _$WS_OVERFLOW, _$STEAL_CNT, _$ALLOC_PAGES, _$ALLOC_CNT | integer32 | 0 |
| +0x02C | MMAP_$WSL | array[0..69] of mmap_$ws_hdr_t (0x24 each) | 0 |
| +0xA04 | MMAP_$MIN_RMT_POOL | integer32 | 16#42 |
| +0xA08 | MMAP_$HPPN | linteger | 1 |
| +0xA0C | MMAP_$LPPN | linteger | mmap_$lppn_seed (16#FFF; SAU9 16#FFFF) |
| +0xA10 | MMAP_$PAGEABLE_PAGES_LOWER_LIMIT | integer32 | 16#42 |
| +0xA14..+0xA1C | MMAP_$PAGEABLE_PAGES, _$REMOTE_PAGES, _$REAL_PAGES | integer32 | 0 |
| +0xA20 | MMAP_$FORMAT | integer | 1 |
| +0xA22 | MMAP_$WSL_HI_MARK | pinteger | 8 |
| +0xA24 | MMAP_$WS_OWNER | array[1..64] of pinteger | 0 |
| +0xAA4 | MMAP_$RMT_LIMIT | integer32 | 0 |

The table MMAP (in the map's OS_PMAPS) is no module's data
(`mmap.ins.pas` declares it extern, mmap_$first_ppn..mmap_$last_ppn:
16#200..16#FFF, on the SAU9 16#10000..16#1FFFF), nor is DUMP_$ADDRS
(`../dump/dump.ins.pas`).  The SAU9's MMAP_ data block is the SAU2's
layout, byte for byte as dpc lays it out.

Routines: 25 MMAP_ globals in MMAP_ (every map symbol of its code
segment) and 2 in MMAP_UNWIRED; module-local (`internal`, no map
symbol): mmap_$add_to_wsl, _$add_pages_to_wsl, _$remove_from_wsl,
_$trim_wsl (the segment's first four routines) and
_$alloc_pages_from_wsl; nested: mmap_$move_pages_to_wsl_type in
MMAP_$WS_SCAN (it reads its parent's frame).  MMAP_UNWIRED also holds
mmu/'s module-local mmu_$vtop_or_crash (`../mmu/vtop_or_crash.pas`),
included by `mmap_unwired.pas`.  None is hand assembly (there is no
mmap/sau2/).

### MMAP_$WS_OWNER and the other address space indexed sites

MMAP_$WS_OWNER is `array[1..64] of pinteger`, and
every reader indexes it by the address space number with no `- 1`:

| site | Pascal |
|------|--------|
| MMAP_$SET_WS_PRI | `mmap_$ws_owner[proc1_$current]` |
| MMAP_$GET_WS_INDEX | `mmap_$ws_owner[pid]` |
| MMAP_$UNWIRE, _$INSTALL_LIST, _$RECLAIM, _$ALLOC_PURE | `mmap_$ws_owner[proc1_$current]` |
| MMAP_$INSTALL_PAGES, _$RELEASE_PAGES | `mmap_$ws_owner[pid]` |
| MMAP_$FREE_WSL (read, cleared; the search) | `mmap_$ws_owner[pid]`, `for i := 1 to 64` |
| MMAP_$SET_WS_INDEX | `mmap_$ws_owner[pid] := wsl_index` |
| MMAP_$INIT | `for i := 2 to 64 do ...[i] := 0; ...[1] := 7` |
| OSINFO_$GET_MMAP (osinfo/get_mmap.pas) | `mmap_$ws_owner[asid]`, `[k]` |

The A5 forms' displacement 0xA22 is the element's +0xA24 less the
bias of 2 (the lower bound folded in).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| mmap_$add_to_wsl | `add_to_wsl.pas` |
| mmap_$add_pages_to_wsl | `add_pages_to_wsl.pas` |
| mmap_$remove_from_wsl | `remove_from_wsl.pas` |
| mmap_$trim_wsl | `trim_wsl.pas` |
| MMAP_$SET_WS_PRI | `set_ws_pri.pas` |
| MMAP_$GET_WS_SIZ | `get_ws_siz.pas` |
| MMAP_$GET_WS_INDEX | `get_ws_index.pas` |
| MMAP_$SET_WS_MAX | `set_ws_max.pas` |
| MMAP_$FREE | `free.pas` |
| MMAP_$FREE_LIST | `free_list.pas` |
| MMAP_$FREE_REMOVE | `free_remove.pas` |
| MMAP_$IMPURE_TRANSFER | `impure_transfer.pas` |
| MMAP_$UNAVAIL_REMOV | `unavail_remov.pas` |
| MMAP_$AVAIL | `avail.pas` |
| MMAP_$WIRE | `wire.pas` |
| MMAP_$UNWIRE | `unwire.pas` |
| MMAP_$INSTALL_LIST | `install_list.pas` |
| MMAP_$INSTALL_PAGES | `install_pages.pas` |
| MMAP_$FREE_PAGES | `free_pages.pas` |
| MMAP_$RELEASE_PAGES | `release_pages.pas` |
| MMAP_$PURGE | `purge.pas` |
| MMAP_$FREE_WSL | `free_wsl.pas` |
| MMAP_$SET_WS_INDEX | `set_ws_index.pas` |
| mmap_$move_pages_to_wsl_type | `ws_scan.pas` (nested in MMAP_$WS_SCAN, before it in the image) |
| MMAP_$WS_SCAN | `ws_scan.pas` |
| MMAP_$GET_IMPURE | `get_impure.pas` |
| mmap_$alloc_pages_from_wsl | `alloc_pages_from_wsl.pas` |
| MMAP_$ALLOC_PURE | `alloc_pure.pas` |
| MMAP_$ALLOC_FREE | `alloc_free.pas` |
| MMAP_$ALLOC_CONTIG | `alloc_contig.pas` |
| MMAP_$RECLAIM | `reclaim.pas` |
| (mmu_$vtop_or_crash) | `../mmu/vtop_or_crash.pas` |
| MMAP_$INIT | `init.pas` |
| MMAP_$REMOTE_POOL | `remote_pool.pas` |
| (data) | the variables in `mmap.pas` |

Headings (`mmap.ins.pas`, in map order): every MMAP_ global takes its
words, bytes and longwords by value and its records and arrays by
address, `val_param` (MMAP_$INIT, one record by address, and
MMAP_$SET_WS_PRI, none, the default); the page lists are `univ
mmap_$vpn_list_t` (`in` or `out`), the page entries `var`. Functions:
MMAP_$WS_SCAN (linteger), MMAP_$ALLOC_PURE and _$ALLOC_FREE (pinteger),
MMAP_$REMOTE_POOL (integer32).  No routine returns a pointer, so no D0
parking.

The constant cells (statuses passed by address) are listed in the
header of `mmap.pas` and in each fragment.

## Insert files

- `mmap.ins.pas` (its users `osinfo/get_mmap.pas`, `osinfo/osinfo.pas`,
  `netbuf/*.pas`, `netlog/cntl.pas`, `dbuf/init.pas`, `wp/*.pas`
  check):
  - the statuses, `mmap_$wsl_in_use`, the probe word's set;
  - mmap_$mmape_t is a packed record (its flag bits are set, cleared and
    tested one by one and two of them cleared on the word), with osinfo's
    field names kept (wsl_index, in_wsl, flags2_7, segment) and impure,
    modified and the probe variant;
  - mmap_$ws_hdr_t's first word is a word set, its counts linteger
    (compared unsigned);
  - mmap_$vpn_list_t and mmap_$init_table_t;
  - the variables of every MMAP_ map symbol and the headings of every
    MMAP_ global.
- `../ast/ast.ins.pas`: ast_$aote_t declares its fields to 0xB9 (the
  location as two words, the attribute flags as one word, the DTM a
  time_$clock_t, the location's flag byte a set at 0xB9); ast_$pmap_t is
  `array[0..31] of ast_$pmap_entry_t` (a flag-word set and the page
  number), indexed from 0 by the offset in the segment
  (mmap_$trim_wsl).  Its users (`osinfo/get_mmap.pas`,
  `osinfo/get_seg_table.pas`, `osinfo/osinfo.ins.pas`) check.
- `../dump/dump.ins.pas`: DUMP_$ADDRS and its range record.
- Used as they are: `base`, `ec`, `ml`, `time` (TIME_$CLOCKH), `proc1`
  (PROC1_$CURRENT), `misc/crash_system`, `mmu` (PFT, MMU_$REMOVE,
  MMU_$PURGE), `file`; `ast` also for AST_$REMOVE_PAGE and the page-map
  entry's members.

## The other SAUs' forms

The parts (`base/config.ins.pas`) that change MMAP_:

- `mmap_ppns_10000` (SAU9): MMAP spans 16#10000..16#1FFFF, so the page
  entry's list links are 22-bit packed fields (`mmap.ins.pas`); the
  table, the boot maximum and the MMAP_$LPPN seed follow it
  (`mmap_$table_pages`, `mmap_$boot_ws_max`, `mmap_$lppn_seed`).
- `pmmu_page_maps` (SAU7..SAU9): a page's used and modified bits are its
  page descriptor's (ast_$pmap_used, ast_$pmap_modified), not the PFT's;
  taking a page out clears the descriptor's resident bit and the
  translations are flushed once (MMU_$PURGE), not page by page
  (MMU_$REMOVE): `trim_wsl.pas` (mmap_$trim_wsl), `ws_scan.pas`,
  `release_pages.pas`.  MMAP_$ALLOC_CONTIG has its body
  (`alloc_contig.pas`; the SAU2's is a stub).

The rest of the SAU9's MMAP_ code is the SAU2's source compiled for the
68020 (scaled indexes, bit-field instructions for the 22-bit links).

## Open items

Facts of the image's form:
- MMAP_$WSL_HI_MARK is the high mark, a word, and MMAP_$WS_OWNER after
  it is the address-space-to-list map, entries 1..64 (MMAP_$INIT clears
  2..64 and sets 1 to 7).
- The 2-byte pushes before the module-local calls are alignment pads.
- The page entry's flag bytes are packed booleans (two cleared together
  on the word), and the list header's first word is a set of 16.
- The AOTE's attribute word is loaded as one word.
- mmap_$move_pages_to_wsl_type is nested in MMAP_$WS_SCAN, reading its
  parent's values.
- MMAP_$WS_SCAN has no `take` variable (its branches go straight to the
  taken page's code and to the step); MMAP_$GET_IMPURE's take is a
  variable.

### TODO(pascal)

- `free_pages.pas`: the frames of the MMAP_ routines against their
  locals (one TODO for the module: FREE_PAGES, add_pages_to_wsl,
  trim_wsl, FREE_WSL, RELEASE_PAGES, move_pages_to_wsl_type, WS_SCAN,
  GET_IMPURE, alloc_pages_from_wsl, ALLOC_PURE, RECLAIM, INIT,
  REMOTE_POOL).

The small routines' frames are explained
exactly by their locals and one 4-byte slot per `with` statement.
