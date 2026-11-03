# The AREA subsystem in Domain Pascal

The anonymous-area manager (the area table, per-address-space area lists,
the remote-UID hash of diskless areas, the overflow segment tables, and
the RPMAP cache of the partner's page maps).

## Layout

One module, `area.pas`, `module area_, wired_proc, wired_data;` (the map
segments' name), one compilation unit in two code sections and one data
section:

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | 0x2F20 bytes (SAU9 0x3428) | area_$rpmap_get, area_$alloc_resources, area_$wait_in_trans, area_$wait_pite_in_trans, area_$internal_create, AREA_$CREATE, AREA_$CREATE_FROM, area_$internal_delete, AREA_$DELETE, AREA_$DELETE_FROM, AREA_$FREE_ASID, AREA_$SHUTDOWN, AREA_$FREE_FROM, AREA_$TRANSFER, area_$free_slot_segments (nested), area_$free_segments, area_$remote_sync (nested), area_$resize, AREA_$GROW, AREA_$GROW_TO, AREA_$INVALIDATE, AREA_$COPY, area_$find_entry_by_uid, AREA_$TOUCH, AREA_$ASSOC, AREA_$THREAD_BSTES, AREA_$REMOVE_SEG, area_$get_aste, area_$alloc_seg_table, area_$free_seg_table, AREA_$DEACTIVATE_ASTE | none (the heading's) |
| OS_INIT_PROC | 0x154 bytes (SAU9 0x14C) | AREA_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the AREA_ block, 0x5E8 bytes in WIRED_DATA, through A5 in the
WIRED_PROC routines with frames (the module-local routines at the
segment's start run on their callers' A5), by its address in AREA_$INIT.
All zero but the three eventcounts' waiter links, each pointing at its
eventcount, and AREA_$FORMAT's first word.  Every offset below equals
the image's:

| offset | object | type |
|--------|--------|------|
| +0x000 | `area_$rpmap_page` | array[1..3] of integer32: the RPMAP pages' physical page numbers |
| +0x00C | `unused_00c`, a stand-in (TODO) | integer32 |
| +0x010 | `area_$rpmap_slots` | array[1..3] of area_$rpmap_slot_t (0xC each) |
| +0x034 | `unused_034`, a stand-in | integer32 |
| +0x038 | AREA_$RPMAP_IN_TRANS_EC (`define`d, map symbol) | ec_$eventcount_t, linked to itself |
| +0x044 | `unused_044`, a stand-in | integer32 |
| +0x048 | AREA_$IN_TRANS_EC (`define`d) | ec_$eventcount_t, linked to itself |
| +0x054 | `unused_054`, a stand-in | integer32 |
| +0x058 | AREA_$PITE_IN_TRANS_EC (`define`d) | ec_$eventcount_t, linked to itself |
| +0x064 | `unused_064`, a stand-in | integer32 |
| +0x068 | `area_$seg_table_list` | array[0..57] of area_$seg_table_ptr_t |
| +0x150 | `area_$seg_table_pool` | array[0..63] of area_$seg_table_t (0xC each) |
| +0x450 | `area_$uid_hash_free` | area_$uid_hash_ptr_t |
| +0x454 | `area_$uid_hash` | array[0..10] of area_$uid_hash_ptr_t |
| +0x480 | `area_$uid_hash_pool` | array[0..10] of area_$uid_hash_t (8 each) |
| +0x4D8 | `area_$asid_list` | array[0..57] of area_$entry_ptr_t |
| +0x5C0 | `area_$rpmap_seq` | linteger, the RPMAP cache's clock |
| +0x5C4 | `area_$next_caller_id` | integer32 |
| +0x5C8 | AREA_$FREE_LIST (`define`d) | area_$entry_ptr_t |
| +0x5CC | AREA_$PARTNER (`define`d) | uid_$t, the diskless partner's node |
| +0x5D4 | AREA_$FORMAT (`define`d) | area_$format_t (8 bytes) |
| +0x5DC | AREA_$DEL_DUP, +0x5DE AREA_$CR_DUP, +0x5E0 AREA_$N_FREE (`define`d) | integer |
| +0x5E2 | AREA_$N_AREAS (`define`d) | pinteger |
| +0x5E4 | AREA_$PARTNER_PKT_SIZE (`define`d) | integer |
| +0x5E6 | 2 bytes: the block's rounding to 4 | |

Not this unit's (externs): AREAS (the area entries, the AREA_PAGES load
section; `area.ins.pas`, `array[1..area_max_entries]`), AREA_$RPMAP_CACHE (three
1 KB pages, in AST_'s VM_TABLES segment; `area.pas`) and PIT_PAGES (the
overflow tables' 64 pages; `area.pas`).  No code segment names them;
AREA_ reaches them by absolute address.

Records (probed with dpc; every offset equals the image's
displacements):

| record | fields (offset) | size |
|--------|-----------------|------|
| area_$entry_t (`area.ins.pas`) | next 0x00, prev 0x04, virt_size 0x08, commit_size 0x0C, caller_id 0x10, first_bste 0x14, first_seg_index 0x16, seg_bitmap 0x18, remote_uid 0x20, volx 0x24, owner_asid 0x26, remote_volx 0x28, area_id 0x2A, generation 0x2C, flags 0x2E (a word set) | 0x30 |
| area_$seg_slot_t (`area.ins.pas`) | bits 0x0, state 0x1, aste_index 0x2; or daddr, bits 21..0 | 4 |
| area_$handle_t | generation 0x00, area_id 0x02 | 4 |
| area_$format_t | word_00 0x00, max_entries 0x02, seg_table_next 0x04, seg_table_count 0x06 | 8 |
| area_$rpmap_slot_t (`area.pas`) | seq at 0x0, volx 0x4, group 0x6, dirty 0x8, in_trans 0x9 | 0xC |
| area_$seg_table_t | area_id 0x0, table_index 0x2, allocated 0x3, next 0x4, bitmap 0x8 | 0xC |
| area_$uid_hash_t | next 0x0, first_entry 0x4 | 8 |
| network_$page_request_t (`network.ins.pas`, pmap's) | | 0x20 |

The names are the map's; the others carry the module's prefix.
Routines: AREA_ has 17 map symbols in its WIRED_PROC code (all
globals) plus AREA_$INIT; the other routines have no map symbol
(module-local, `internal`), and two are nested.  None is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| area_$rpmap_get | `rpmap_get.pas` |
| area_$alloc_resources | `alloc_resources.pas` (its page wiring written out twice, as the image has it) |
| area_$wait_in_trans | `wait_in_trans.pas` (it lies apart from the deletion routines) |
| area_$wait_pite_in_trans | `wait_pite_in_trans.pas` |
| area_$internal_create | `internal_create.pas` |
| AREA_$CREATE | `create.pas` |
| AREA_$CREATE_FROM | `create_from.pas` |
| area_$internal_delete | `internal_delete.pas` (area_$internal_delete's forward heading in area.pas: area_$internal_create calls it first) |
| AREA_$DELETE | `delete.pas` |
| AREA_$DELETE_FROM | `delete_from.pas` |
| AREA_$FREE_ASID | `free_asid.pas` |
| AREA_$SHUTDOWN | `shutdown.pas` |
| AREA_$FREE_FROM | `free_from.pas` |
| AREA_$TRANSFER | `transfer.pas` |
| area_$free_segments, its nested area_$free_slot_segments | `free_segments.pas` |
| area_$resize, its nested area_$remote_sync | `resize.pas` (forward heading in area.pas; the partner's size written out twice) |
| AREA_$GROW | `grow.pas` |
| AREA_$GROW_TO | `grow_to.pas` |
| AREA_$INVALIDATE | `invalidate.pas` |
| AREA_$COPY | `copy.pas` (its overflow-table search written out twice) |
| area_$find_entry_by_uid | `find_entry_by_uid.pas` |
| AREA_$TOUCH | `touch.pas` |
| AREA_$ASSOC | `assoc.pas` |
| AREA_$THREAD_BSTES | `thread_bstes.pas` |
| AREA_$REMOVE_SEG | `remove_seg.pas` |
| area_$get_aste | `get_aste.pas` (its row copy written out twice) |
| area_$alloc_seg_table | `alloc_seg_table.pas` |
| area_$free_seg_table | `free_seg_table.pas` |
| AREA_$DEACTIVATE_ASTE | `deactivate_aste.pas` (its row copy written out twice) |
| AREA_$INIT | `init.pas` |
| (data) | the variables in `area.pas` |

The `%include`s of every fragment are in `area.pas`, in image order.

Headings:
- `area.ins.pas`: the globals `val_param` but AREA_$SHUTDOWN and
  AREA_$INIT (no parameters) and AREA_$DEACTIVATE_ASTE (the default
  convention, `var aste`, `out status_ret`); the handle by value where
  the callers push its longword (CREATE's result, DELETE, GROW,
  INVALIDATE, COPY), `var` where they push its address (TRANSFER, TOUCH,
  THREAD_BSTES, REMOVE_SEG).  AREA_$CREATE and AREA_$COPY return the
  handle as an integer32, AREA_$CREATE_FROM the id as a pinteger,
  AREA_$TRANSFER the old first segment index.
- `area.pas`: the module-local routines are `internal` (words and bytes
  by value, records by address); area_$rpmap_get returns its page in A0
  (univ_ptr; its one caller, area_$get_aste, takes A0 into an address
  register: no D0 parking); area_$internal_create returns the handle in
  D0;
  area_$get_aste, area_$alloc_seg_table and area_$find_entry_by_uid
  return pointers in A0.

## Insert files

- `area.ins.pas`: the statuses AREA stores (16#320001, 16#320005,
  16#320006, 16#320007, 16#32000B) and 16#32000A; the flags word's and
  the slot cell's members; the types area_$flags_t, area_$seg_slot_t,
  area_$entry_t, area_$entry_words_t, area_$handle_t, area_$format_t;
  AREAS (bound area_max_entries: the segment holds 0xFC00 / 0x30 = 1344
  entries, 0x1F800 / 0x30 = 2688 with the large VM layout, and AREA_$INIT
  sets the maximum to it); the block's other map
  symbols; the headings.  Its user `pmap/write_page.pas` (area_$entry_t's
  area_id, remote_volx, volx through `area_$entry_ptr_t`, AREAS,
  AREA_$PARTNER, AREA_$PARTNER_PKT_SIZE) checks.
- `ast/ast.ins.pas` (AREA's additions): ast_$aste_t's next
  `ast_$aste_ptr_t`, fm_block the packed record ast_$fm_block_t (`all`,
  or `block` bits 31..4 and `group` bits 3..0), wire_count `[byte]
  0..255`, its flags word's second view flag_bits; the segment map's
  entry as a disk address (ast_$pmap_dentry_t), the row and the page-map
  block as longwords (ast_$pmap_lrow_t, ast_$pmap_lblock_t), ast_$ppn_list_t,
  AST_$ASTE_AREA_CNT, status_$ast_segment_not_deactivatable, and the
  headings of AST_$FREE_PAGES, _$FREE_ASTE, _$COPY_AREA, _$TOUCH_AREA,
  _$ASSOC_AREA, _$WAIT_FOR_AST_INTRANS and _$ALLOCATE_ASTE (a pointer
  function, A0).  Its readers of fm_block read `fm_block.block`
  (area/free_segments.pas, pmap/fill_write_qblks.pas).
- `ast/ast_net.ins.pas`: AST_$FETCH_PMAP_PAGE's heading (it takes
  NETWORK_'s request record).
- `rem_file/rem_file.ins.pas`: REM_FILE_$CREATE_AREA, _$DELETE_AREA,
  _$GROW_AREA.  `mmu/mmu.ins.pas`: MMU_$REMOVE_LIST.
  `network/network.ins.pas`: NETWORK_$GET_PKT_SIZE.
- `mst/mst.ins.pas` and `mst/mst_internal.ins.pas`, used as they are:
  with the large VM layout AREA_ reaches MST's tables (SMAPS, BST, MST
  and their per-ASID bases).
- Used as they are: `base`, `ec`, `ml`, `time`, `misc/crash_system`,
  `uid`, `as` (AS_$STACK_LOW), `file`, `mmu` (MMU_$VTOP, MMU_$INSTALL),
  `mmap` (MMAP_$FREE), `wp`, `proc1`, `pkt`, `disk`, `fm`, `vtoc`, `bat`,
  `dbuf`, `cal` (CAL_$BOOT_VOLX), `anon` (ANON_$UID), `acl`.
- In `area.pas`, not an insert: PIT_PAGES, AREA_$RPMAP_CACHE and the
  three eventcounts' externs.

## The other SAUs' forms

The part (`base/config.ins.pas`) that changes AREA_ is `large_vm`: the
arms are the SAU9's, and SAU4 and SAU6..SAU8 reach the same tables in
the same routines.  With it an area's segments are mapped through MST's
forward tables: each segment of an address space has a segment map
entry (SMAPS) and a BST link, and the links thread the address spaces
that map one page map.  AREA_ keeps them:

- AREA_$TOUCH and AREA_$COPY make a segment's map entry valid on its
  ASTE's page map (`touch.pas`, `copy.pas`);
- AREA_$THREAD_BSTES, AREA_$COPY, AREA_$TRANSFER and area_$resize set
  the BST links of an area's segments, or move them, under the PMAP
  lock (`thread_bstes.pas`, `copy.pas`, `transfer.pas`, `resize.pas`);
- area_$resize takes a shrunk area's threads apart and flushes the
  translations (MMU_$PURGE) after its frees; AREA_$REMOVE_SEG unlinks
  one segment from its thread instead of taking its pages out of the
  MMU, and AREA_$DEACTIVATE_ASTE makes the map entries along the
  thread invalid (`remove_seg.pas`, `deactivate_aste.pas`);
- area_$get_aste starts a new ASTE with an empty thread
  (`get_aste.pas`);
- AREAS has 2688 entries, AREA_$INIT's maximum (`init.pas`,
  `area.ins.pas` area_max_entries).

The 28-byte ASTE and the 21-bit disk addresses come in through the
types alone.  The rest of the SAU9's AREA_ code, and its data block, is
the SAU2's source compiled for the 68020.

The SAU8's AREA_ is the SAU9's code but for area_$resize's MST test in
a shrink: its MST is 7168 words (`mst_7168_words`,
`mst/mst_internal.ins.pas`), so the index is a word, and the SAU8 image
forms it in 16 bits.

## Open items

### TODO(pascal)

- `area.pas`: the block's five unaddressed 4-byte gaps (+0x00C, +0x034,
  +0x044, +0x054, +0x064), held by stand-ins; an 8-byte alignment
  explains them, but not the hash buckets, AREA_$PARTNER and
  AREA_$FORMAT at 4 mod 8.
- `area.pas`: the frames against the locals: area_$rpmap_get,
  area_$alloc_resources, area_$internal_create, AREA_$CREATE_FROM,
  AREA_$INIT, area_$internal_delete, area_$free_segments,
  area_$free_slot_segments, area_$resize, area_$remote_sync,
  AREA_$INVALIDATE, AREA_$COPY, area_$find_entry_by_uid, AREA_$TOUCH and
  area_$alloc_seg_table leave bytes no object explains;
  AREA_$REMOVE_SEG, area_$get_aste and AREA_$DEACTIVATE_ASTE add up but
  the places of their register-held locals are not checked.
