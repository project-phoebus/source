# The AST subsystem in Domain Pascal

The active segment and active object tables (the AOTE and ASTE pools and
their hash, activation and deactivation, page-in from disk and network,
write-back and purification, attributes, truncation, invalidation,
dismount).

The module file's define list holds AST_'s 47 map symbols (the WP_ four
among them) but not OS_INIT_START, the OS_INIT_PROC section's mark at
AST_$INIT's address (not a routine, as file/file.pas's
OS_DATA_SHUTWIRED); on the SAU9 it holds the seven more of "The large VM
layout" below.

## Layout

One map module, `AST_`, so one module file, **`ast.pas`, `module ast_,
wired_proc, wired_data;`** (log/log.pas's form):

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | AST_, 0x6788 bytes | ast_$validate_uid .. AST_$REMOVE_CORRUPTED_PAGE: 44 globals (four of them WP_$) and 30 module-local routines (table below) | none (the module's) |
| OS_INIT_PROC | AST_, 0x3A8 bytes | AST_$INIT, AST_$ACTIVATE_AOTE_CANNED, AST_$ACTIVATE_ASTE_CANNED | `[section(os_init_proc, os_init_data)]` |

The WIRED_PROC routines with frames load A5 with the WIRED_DATA block's
start; the module-local ones run on their callers' A5.  Of the
OS_INIT_PROC routines, the two _CANNED ones load A5 with the end of the
4-byte OS_INIT_DATA block and never use it, reaching WIRED_DATA through
its start as an immediate; AST_$INIT loads none.

Data:

| block | section | contents |
|-------|---------|----------|
| AST_, 0x498 bytes | WIRED_DATA | the module's variables (below), 21 map symbols |
| AST_, 4 bytes | OS_INIT_DATA | zero; A5 = its end in the _CANNED routines (TODO in `ast.pas`) |

The tables AST (504 ASTEs of 0x14), AOT (280 AOTEs of 0xC0) and
AST_PMAPS (a page map of 0x80 bytes per ASTE) are the VM_TABLES
module's (in the load sections AST_AOT and VM_TABLES), no module file
here: `ast.ins.pas` declares them `extern`.

The WIRED_DATA block (checked with a dpc probe, which gives every
offset, the initial bytes and the size 0x498):

| offset | variable | type, initial value |
|--------|----------|---------------------|
| +0x000 | AOTH (`define`d) | array[0..250] of ast_$aote_ptr_t, zero |
| +0x3EC | `ast_$free_aote_head` | ast_$aote_ptr_t, zero |
| +0x3F0 | `ast_$aote_scan_pos`, `ast_$aote_limit` | ast_$aote_ptr_t := addr(aot) |
| +0x3F8 | `ast_$free_aste_head` | ast_$aste_ptr_t, zero |
| +0x3FC | `ast_$aste_scan_pos`, `ast_$aste_limit` | ast_$aste_ptr_t := addr(ast) |
| +0x404 | `ast_$dism_seqn` | integer32, zero |
| +0x408 | `ast_$dism_ec` | ec_$eventcount_t, its waiter list at itself |
| +0x414 | `ast_$vol_indices` | array[1..6] of integer, zero (volumes 1..6) |
| +0x420 | `ast_$vol_info_count` | set of 0..15, zero (the dismounting volumes) |
| +0x422 | `unused_422`, a stand-in | 6 bytes (TODO) |
| +0x428 | AST_$AST_IN_TRANS_EC (`define`d) | eventcount at itself |
| +0x434 | `ast_$aote_seqn` | integer32, zero |
| +0x438 | AST_$DISMOUNT_FAILED_PTR, _ALLOC_WORST_AOT, _ALLOC_TOTAL_AOT, _ALLOC_WORST_AST, _ALLOC_TOTAL_AST (`define`d) | a pointer and four integer32, zero |
| +0x44C | AST_$PMAP_IN_TRANS_EC (`define`d) | eventcount at itself |
| +0x458 | AST_$WS_FLT_CNT, _PAGE_FLT_CNT, _ALLOC_TOO_FEW_CNT, _ALLOC_CNT (`define`d) | integer32, zero |
| +0x468 | AST_$FREE_ASTES, _FREE_AOTES, _GROW_AHEAD_CNT, _SIZE_AOT, _SIZE_AST, _ASTE_AREA_CNT, _ASTE_R_CNT, _ASTE_L_CNT (`define`d) | integer, zero but _GROW_AHEAD_CNT 8 |
| +0x478 | AST_$NOT_FOUND (`define`d) | ast_$not_found_t (0xC), zero |
| +0x484 | `ast_$update_scan` | ast_$aote_ptr_t := addr(aot) |
| +0x488 | `ast_$update_timestamp` | pinteger := 16#FFFF (compared unsigned with the segment number) |
| +0x48A | `unused_48a`, a stand-in | 2 bytes (TODO) |
| +0x48C | `ast_$attr_timestamp_mask` | set of 0..31 := [2..4, 12, 13, 19..22, 25] (tested with the attribute number) |
| +0x490 | `ast_$clobbered_uid` | uid_$t, zero |

The names are the map's for its symbols, with the prefix `ast_$` for
the others.  The types and index bases are the users' (each
fragment says what it reads).

Routines: the map symbols of the two code segments are globals, the other
routines module-local (`internal`), nested where a fragment says so.  None
is hand assembly (there is no `ast/sau2/`).  Six routines of the WIRED_PROC
segment have their fragments in other directories, included by `ast.pas`:
ZERO_PAGE (`../misc/zero_page.pas`, module-local), VTOC_$SEARCH_VOLUMES
(`../vtoc/search_volumes.pas`, module-local: no map symbol) and WP_$CALLOC,
_CALLOC_LIST, _UNWIRE, _WIRE (`../wp/*.pas`, globals).  Small helpers (the
one-bit segment-map set, the ACL image copy, the UID compares) have no
routine in the image: their code is inline.

## Routines and their fragments

| routine | section | kind | fragment |
|---------|---------|------|----------|
| ast_$validate_uid | WIRED_PROC | local | `validate_uid.pas` |
| ast_$wait_for_page_transition | WIRED_PROC | local | `wait_for_page_transition.pas` |
| AST_$WAIT_FOR_AST_INTRANS | WIRED_PROC | global | `wait_for_ast_intrans.pas` |
| ast_$allocate_pages_log | WIRED_PROC | nested in ast_$allocate_pages | `allocate_pages.pas` |
| ast_$allocate_pages | WIRED_PROC | local | `allocate_pages.pas` |
| zero_page | WIRED_PROC | local | `../misc/zero_page.pas` |
| AST_$PAGE_ZERO | WIRED_PROC | global | `page_zero.pas` |
| AST_$INVALIDATE_PAGE | WIRED_PROC | global | `invalidate_page.pas` |
| ast_$release_aote | WIRED_PROC | local | `release_aote.pas` |
| AST_$FREE_ASTE | WIRED_PROC | global | `free_aste.pas` |
| AST_$ADD_AOTES | WIRED_PROC | global | `add_aotes.pas` |
| AST_$ADD_ASTES | WIRED_PROC | global | `add_astes.pas` |
| AST_$GET_DISM_SEQN | WIRED_PROC | global | `get_dism_seqn.pas` |
| ast_$purify_aote | WIRED_PROC | local | `purify_aote.pas` |
| ast_$update_aste_log | WIRED_PROC | nested in ast_$update_aste | `update_aste.pas` |
| ast_$update_aste | WIRED_PROC | local | `update_aste.pas` |
| AST_$UPDATE | WIRED_PROC | global | `update.pas` |
| ast_$deactivate_segment_log | WIRED_PROC | nested in ast_$deactivate_segment | `deactivate_segment.pas` |
| ast_$deactivate_segment | WIRED_PROC | local | `deactivate_segment.pas` |
| ast_$process_aote | WIRED_PROC | local | `process_aote.pas` |
| vtoc_$search_volumes | WIRED_PROC | local | `../vtoc/search_volumes.pas` |
| ast_$lookup_with_hints | WIRED_PROC | local | `lookup_with_hints.pas` |
| ast_$allocate_aote | WIRED_PROC | local | `allocate_aote.pas` |
| AST_$ALLOCATE_ASTE | WIRED_PROC | global | `allocate_aste.pas` |
| ast_$lookup_aote_by_uid | WIRED_PROC | local | `lookup_aote_by_uid.pas` |
| ast_$force_activate_segment | WIRED_PROC | local | `force_activate_segment.pas` |
| AST_$LOAD_AOTE | WIRED_PROC | global | `load_aote.pas` |
| ast_$lookup_aste | WIRED_PROC | local | `lookup_aste.pas` |
| ast_$lookup_or_create_aste | WIRED_PROC | local | `lookup_or_create_aste.pas` |
| ast_$clear_transition_bits | WIRED_PROC | local | `clear_transition_bits.pas` |
| ast_$setup_page_read | WIRED_PROC | local | `setup_page_read.pas` |
| ast_$read_area_pages | WIRED_PROC | local | `read_area_pages.pas` |
| ast_$read_area_pages_net_log | WIRED_PROC | nested in ast_$read_area_pages_network | `read_area_pages_network.pas` |
| ast_$read_area_pages_network | WIRED_PROC | local | `read_area_pages_network.pas` |
| AST_$MSTE_ACTIVATE_AND_WIRE | WIRED_PROC | global | `mste_activate_and_wire.pas` |
| AST_$ACTIVATE_AND_WIRE | WIRED_PROC | global | `activate_and_wire.pas` |
| ast_$count_valid_pages | WIRED_PROC | nested in AST_$TOUCH | `count_valid_pages.pas` (included by `touch.pas`) |
| AST_$TOUCH | WIRED_PROC | global | `touch.pas` |
| AST_$TOUCH_AREA | WIRED_PROC | global | `touch_area.pas` |
| AST_$COPY_AREA | WIRED_PROC | global | `copy_area.pas` |
| ast_$flush_installed_pages | WIRED_PROC | nested in AST_$FREE_PAGES | `flush_installed_pages.pas` (included by `free_pages.pas`) |
| AST_$FREE_PAGES | WIRED_PROC | global | `free_pages.pas` |
| AST_$FETCH_PMAP_PAGE | WIRED_PROC | global | `fetch_pmap_page.pas` |
| AST_$PMAP_ASSOC | WIRED_PROC | global | `pmap_assoc.pas` |
| AST_$ASSOC | WIRED_PROC | global | `assoc.pas` |
| AST_$ASSOC_AREA | WIRED_PROC | global | `assoc_area.pas` |
| AST_$GET_LOCATION | WIRED_PROC | global | `get_location.pas` |
| AST_$GET_ATTRIBUTES | WIRED_PROC | global | `get_attributes.pas` |
| AST_$GET_COMMON_ATTRIBUTES | WIRED_PROC | global | `get_common_attributes.pas` |
| AST_$GET_ACL_ATTRIBUTES | WIRED_PROC | global | `get_acl_attributes.pas` |
| ast_$set_attr_dispatch | WIRED_PROC | nested in ast_$set_attribute_internal | `set_attribute_internal.pas` |
| ast_$set_attribute_internal | WIRED_PROC | local | `set_attribute_internal.pas` |
| AST_$SET_ATTRIBUTE | WIRED_PROC | global | `set_attribute.pas` |
| AST_$SET_ATTR | WIRED_PROC | global | `set_attr.pas` |
| AST_$GET_DTV | WIRED_PROC | global | `get_dtv.pas` |
| AST_$SET_DTS | WIRED_PROC | global | `set_dts.pas` |
| AST_$PURIFY | WIRED_PROC | global | `purify.pas` |
| AST_$COND_FLUSH | WIRED_PROC | global | `cond_flush.pas` |
| AST_$TRUNCATE | WIRED_PROC | global | `truncate.pas` |
| ast_$invalidate_with_wait | WIRED_PROC | nested in AST_$INVALIDATE | `invalidate_with_wait.pas` (included by `invalidate.pas`) |
| ast_$invalidate_no_wait | WIRED_PROC | nested in AST_$INVALIDATE | `invalidate_no_wait.pas` (included by `invalidate.pas`) |
| AST_$INVALIDATE | WIRED_PROC | global | `invalidate.pas` |
| AST_$RESERVE | WIRED_PROC | global | `reserve.pas` |
| AST_$DISMOUNT | WIRED_PROC | global | `dismount.pas` |
| AST_$GET_SEG_MAP | WIRED_PROC | global | `get_seg_map.pas` |
| AST_$RELEASE_PAGES | WIRED_PROC | global | `release_pages.pas` |
| AST_$LOCATE_ASTE | WIRED_PROC | global | `locate_aste.pas` |
| WP_$CALLOC | WIRED_PROC | global | `../wp/calloc.pas` |
| WP_$CALLOC_LIST | WIRED_PROC | global | `../wp/calloc_list.pas` |
| WP_$UNWIRE | WIRED_PROC | global | `../wp/unwire.pas` |
| WP_$WIRE | WIRED_PROC | global | `../wp/wire.pas` |
| AST_$ALLOC_CONTIG | WIRED_PROC | global (`pmmu_page_maps`) | `alloc_contig.pas` |
| AST_$REMOVE_PAGE | WIRED_PROC | global (`pmmu_page_maps`) | `remove_page.pas` |
| AST_$ASSOC_IOPPN | WIRED_PROC | global (`pmmu_page_maps`) | `assoc_ioppn.pas` |
| AST_$REMOVE_IOPPN | WIRED_PROC | global (`pmmu_page_maps`) | `remove_ioppn.pas` |
| AST_$SET_TROUBLE | WIRED_PROC | global | `set_trouble.pas` |
| AST_$SAVE_CLOBBERED_UID | WIRED_PROC | global | `save_clobbered_uid.pas` |
| AST_$PTOV | WIRED_PROC | global (`pmmu_page_maps`) | `ptov.pas` |
| AST_$REMOVE_CORRUPTED_PAGE | WIRED_PROC | global | `remove_corrupted_page.pas` |
| AST_$CACHE_INHIBIT_PPN | WIRED_PROC | global (`pmap_cache_inhibit`) | `cache_inhibit_ppn.pas` |
| AST_$CACHE_ENABLE_PPN | WIRED_PROC | global (`pmap_cache_inhibit`) | `cache_enable_ppn.pas` |
| AST_$INIT | OS_INIT_PROC | global | `init.pas` |
| AST_$ACTIVATE_AOTE_CANNED | OS_INIT_PROC | global | `activate_aote_canned.pas` |
| AST_$ACTIVATE_ASTE_CANNED | OS_INIT_PROC | global | `activate_aste_canned.pas` |

## The large VM layout (SAU9)

The SAU9 (DN2500) builds the same module with the parts of
`base/config.ins.pas`'s VM table (`large_vm`, `vm_5760_astes`,
`pmap_threads`, `pmmu_page_maps`, `pmap_cache_inhibit`,
`mmap_ppns_10000`), and its AST_ segments are 0x69E0 bytes (WIRED_PROC)
and 0x370 (OS_INIT_PROC); the data blocks are the SAU2's sizes.

- The ASTE is 28 bytes (`ast.ins.pas`): the page map's physical address
  at +0x0C, the head of its MST thread at +0x10, the SAU2 fields after
  them.  The tables hold 5760 ASTEs and 1280 AOTEs
  (`ast_$max_astes`, `ast_$max_aotes`), the hint is 14 bits.
- A page-map entry is an MC68030 page descriptor, a packed record of
  the same field names: `vpn` the frame (bits 31..10), `dentry.daddr`
  the disk address (bits 30..10), the flags in the low word
  (`ast_$pmap_in_trans` 9, `ast_$pmap_installed` 8, the descriptor's
  resident, used, modified and cache-inhibit bits 0, 3, 4, 6), the no
  disk copy mark in the high word (`hi_flags` member 15, the SAU2's
  member 6).  The fragments name the members by those constants, so one
  source serves both layouts; the arms (`%if pmmu_page_maps`) are where
  the code differs: the PFT's used and modified bits become the
  descriptor's, MMU_$REMOVE becomes clearing the resident bit and
  MMU_$PURGE, and the disk address merges become stores to `vpn`.
- The pageable pages are 16#10000..16#1FFFF (`mmap_$first_ppn`,
  `mmap_$last_ppn`, `mmap/mmap.ins.pas`).
- Seven routines exist only there (the table above).  None of AST_'s
  SAU9 routines is hand assembly; MMU_$PURGE and MMU_$PURGE_TB, which
  they call, are the SAU9's MMU_ASM (`mmu/mmu.ins.pas`, no `.s` yet).

## The SAU8

The SAU8 (DN3000 family) builds the large layout of the SAU9 with
`large_vm`, `pmap_threads` and `pmmu_page_maps`, but neither
`pmap_cache_inhibit` nor `vm_5760_astes` nor `mmap_ppns_10000`:

- The tables hold 1536 ASTEs and 640 AOTEs (`vm_1536_astes`); the map's
  AST (0xA800 bytes, 28 bytes each) and AST_PMAPS (0x30000 bytes, 128
  each) agree.
- The pageable pages are 16#400..16#23FF (`mmap_ppns_400`,
  `mmap/mmap.ins.pas`).
- The page maps' pages are not cache-inhibited: AST_$ADD_ASTES does not
  call MMU_$CACHE_INHIBIT_VA, AST_$ASSOC_IOPPN's descriptor has no
  cache-inhibit bit, and AST_$CACHE_INHIBIT_PPN and
  AST_$CACHE_ENABLE_PPN are not in the map.

Its AST_ segments are 0x68C4 bytes (WIRED_PROC) and 0x370
(OS_INIT_PROC), the data blocks the SAU2's sizes.  Every other routine
is the SAU9's code with these constants; none is hand assembly.

## The SAU4

The SAU4 (DN460, DN660, DSP160) builds the large layout with
`large_vm`, `vm_2432_astes`, `pmap_threads` and `region_mmu`, without
`pmmu_page_maps` or `memory_parity`.  Its AST_ segments are 0x6678
bytes (WIRED_PROC) and 0x408 (OS_INIT_PROC), the WIRED_DATA block
0x490 bytes (no ast_$clobbered_uid), the OS_INIT_DATA block 4.

- The tables hold 2432 ASTEs and 1280 AOTEs (`vm_2432_astes`); the
  map's AST (0x10A00 bytes, 28 each) and AST_PMAPS (0x4C000 bytes, 128
  each) agree.
- A page-map entry has the SAU2's shape (the flags word, then the page
  number word; the disk address in bits 21..0), but its flags are the
  region registers' MMU's: resident 15, used 14, modified 13, in
  transition 10, installed 9 (`ast_$pmap_*`), and the bits the SAU2's
  PFT holds (used, modified) are the entry's own.  So the fragments
  take the page descriptors' arms for what the PFT did
  (`pmmu_page_maps or region_mmu`: the flags set in the entry, a
  resident page made not resident and MMU_$PURGE instead of
  MMU_$REMOVE and MMU_$REMOVE_LIST, MMU_$INSTALL_LIST not called) and
  the SAU2's arms for the entry's shape (`%if pmmu_page_maps` alone).
- AST_$ACTIVATE_ASTE_CANNED and ast_$lookup_or_create_aste clear the
  flags 15..11 one by one; AST_$TOUCH_AREA reads up to 4 pages in a
  run (`region_mmu`).
- The MMAP entries' disk addresses are 22 bits, the SAU2's
  (`mmap/mmap.ins.pas`, under `pmmu_page_maps`).
- AST_$ASSOC_IOPPN and AST_$REMOVE_IOPPN are in the map (also the
  SAU6's), in the SAU2's entry shape; AST_$SET_TROUBLE,
  AST_$SAVE_CLOBBERED_UID and AST_$REMOVE_CORRUPTED_PAGE are not (the
  SAU4 has no parity memory, `memory_parity`).  The map's define list
  is 46 symbols.
- Under `-cpu 460` AST_$GET_SEG_MAP's two divisions are the machine's
  unsigned divide; its `mod` still calls the run-time.  None of AST_'s
  SAU4 routines is hand assembly.

## Insert files

- `ast.ins.pas`: the common attribute record and its views, the AOTE
  (two views: its fields, and the location byte pair ast_$aote_loc_t),
  the ASTE with its flag word (a set, and its packed fields) and its
  file-map block (a packed record), the page-map entry (its flags and
  page number, its longword, its disk address) and the rows and blocks
  of them, the externs AST, AOT and AST_PMAPS and the counters other
  modules read, AST_$ZERO_BUFF and AST_$COPY_BUFF, the AST_ statuses,
  the page and page-number list types, the purify list, the
  segment-map output and flags, the locate request and the MSTE, and
  every AST_ heading the other modules call.  Its users (OSINFO, MMAP,
  PMAP, AREA, MISC, HINT, VOLX, PARITY, LOG, FILE_, DIR, MST and others)
  include it after base and file.
- `ast_acl.ins.pas`: AST_$GET_ACL_ATTRIBUTES' heading, whose record is
  acl/acl.ins.pas's ast_$acl_attr_t and whose location is
  file/file.ins.pas's.  Neither ast.ins.pas (19 includers lack
  acl/acl.ins.pas before it) nor acl.ins.pas (six lack file/file.ins.pas)
  can hold it.  Included after base, file and acl by acl/acl.pas,
  dir/dir.pas, rem_file/rem_file.pas and ast.pas.
- `ast_net.ins.pas`: AST_$FETCH_PMAP_PAGE's heading, with the body's
  modes (`var req', `out page'), which needs network/network.ins.pas;
  included by area/area.pas after network.
- `ast.pas`'s own types: the attribute numbers (the dispatch's `case'
  labels), the module-local views of the AOTE's attribute record (as
  the common attributes, file_$attributes_t, network_$attr_rec_t,
  vtoce_$t, the dispatch's record), of its location record (as
  file_$obj_loc_t, network_$obj_loc_t, vtoc_$lookup_req_t,
  fm_$file_ref_t) and of its location longword, which ast.ins.pas's AOTE
  cannot name (its includers lack network and vtoc); the file-map
  image, the hint list, the page-map run and the ASTE and row views for
  FM_, the attribute value view, and the canned routines' bit-field
  views.
- `../file/file_prot.ins.pas`: FILE_$SET_PROT_INT's heading and its
  value record file_$set_prot_rec_t (its first view ACL_'s protection
  record), included by file/file.pas and rem_file/rem_file.pas.
- `../file/file.ins.pas`: file_$uid_view_t; file_$obj_loc_t's node is a
  linteger (both merges into a 20-bit field are unmasked, the form of a
  linteger: AST_$ACTIVATE_AOTE_CANNED, MST_$LOOKUP_OBJECT).
- `../pmap/pmap_flush.ins.pas`: PMAP_$FLUSH's heading and flags type,
  included by ast.pas and pmap.pas.
- `../pmap/pmap.ins.pas`, `../mmap/mmap.ins.pas`:
  status_$pmap_read_concurrency_violation (16#0005000A),
  status_$mmap_bad_install (16#0006000C).

## Open items

### Forms the image settles

- ast_$lookup_with_hints reads and masks the UID's node again for its
  hint compare, after NETWORK_$AST_GET_INFO's `in out' location record:
  a cached node would differ only if that callee rewrites the record's
  UID.
- The status ast_$count_valid_pages stores is 16#50008, the PMAP
  manager's "page null" (pmap/pmap.ins.pas status_$pmap_page_null).
- `../vtoc/search_volumes.pas`'s call of ast_$validate_uid passes
  `status.all`: the heading takes a flags longword (the other callers
  pass site constants 16#30F00 and 16#30F01).

### TODO(pascal)

- `ast.pas`: the 4-byte OS_INIT_DATA block; the stand-ins of the
  WIRED_DATA block (unused_422, unused_48a); AST_'s frames against their
  locals.
- `touch_area.pas`: page's type, which the SAU4's run limit shows to
  be an unsigned word.
- In the fragments: RESERVE's and invalidate_with_wait's signed and
  unsigned page compares; invalidate_with_wait's and RELEASE_PAGES'
  stand-ins; GET_SEG_MAP's frame; LOCATE_ASTE's hint compare with
  AST_$SIZE_AST; SET_TROUBLE's value offset; INIT's rshft for the
  unsigned division.
