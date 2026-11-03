# The MST subsystem in Domain Pascal

The segment tables: the per-ASID MST words and MSTEs that say which
object backs each segment of an address space, the mapping and
unmapping of objects and areas, touching and wiring pages, and the
ASIDs themselves.

Every routine of the three map modules has its source: 54 Pascal
routines (and with the large address space MST_$MAP_SPECIAL and
mst_$free_region), and MST_$SET and MST_$SET_CLEAR in hand assembly
(`m68k/set.s`).

## Layout

MST_ is three map modules:

| map segment | size | section | holds | module file |
|-------------|------|---------|-------|-------------|
| `I MST_WIRED` | 0x570 | WIRED_PROC | MST_$VA_TO_SEGNO .. MST_$WIRE (5 globals) | `mst_wired.pas` |
| `D MST_WIRED` | 0x164 | WIRED_DATA | MST_$DISKLESS_MSG .. MST_$GOT_COLOR (22 map symbols) | `mst_wired.pas` |
| `I MST_ASM` | 0x38 | WIRED_PROC | MST_$SET, MST_$SET_CLEAR: hand assembly | `m68k/set.s` |
| `I MST_UNWIRED` | 0x6A8 | OS_INIT_PROC | MST_$PRE_INIT .. MST_$MAP_CANNED_AT (5 globals, 2 nested) | `mst_unwired.pas` |
| `I MST_UNWIRED` | 0x1F50 | .TEXT | MST_$ALLOC_ASID .. MST_$WIRE_AREA (31 globals, 6 local, 1 nested) | `mst_unwired.pas` |
| `I MST_UNWIRED` | 0x1C0 | PROC2_CREATE_PRO | MST_$FORK | `mst_unwired.pas` |
| `I MST_UNWIRED` | 0x1B0 | PROC2_DELETE_PRO | 2 local, MST_$FREE_ASID | `mst_unwired.pas` |
| `D MST_UNWIRED` | 0x48 | .DATA | MST_$MST_PAGES_LIMIT, MST_$MST_PAGES_WIRED and four unnamed objects | `mst_unwired.pas` |
| `D MST_UNWIRED` | 0x4 | DATA$ | nothing (A5 at its end) | `mst_unwired.pas` |

Two module files, one per compilation unit, each named after its map
segment; neither is `mst/mst.pas`.  MST_ASM's two routines are hand
assembly (no frame, the arguments read off SP).

- **MST_WIRED** (`mst_wired.pas`): `module mst_wired, wired_proc,
  wired_data;`.  The data block is module variables, every one a map
  symbol read by several routines and units: LOG_'s and DXM's shape.
  MST_$VA_TO_SEGNO and MST_$TOUCH load A5 with the block; the other
  three load none.  The three exclusion locks (0x12 bytes) sit 0x18
  apart, each at a multiple of 8 with 6 open bytes after it, as RIP's:
  stand-ins `unused_9a`, `unused_b2`, `unused_ca`.  dpc lays the block out
  at the image's offsets (0x164 bytes, every symbol where the map has it).
- **MST_UNWIRED** (`mst_unwired.pas`): `module mst_unwired;`.  The
  .DATA block is reached from three code sections (A5 in .TEXT; the
  block's address in MST_$INIT's nested routines and in
  mst_$unwire_asid_pages), so it is module variables, and .DATA and
  .TEXT are the defaults.  The other sections' routines are headed
  `[section(os_init_proc, os_init_data)]`, `[section(proc2_create_pro,
  data$)]` and `[section(proc2_delete_pro, data$)]`: MST_$FORK and
  MST_$FREE_ASID both load A5 with the end of MST's DATA$ block, and MST
  has no block in PROC2_CREATE_DAT or PROC2_DELETE_DAT; no OS_INIT_PROC
  routine loads A5 and MST has no OS_INIT_DATA block.  Of
  the .DATA block's unnamed objects, page_avail_bitmap and
  page_alloc_hint are module variables, +0x36 a stand-in, and
  prot_rights mst_$lookup_object's static.

The insert files:
- `mst/mst.ins.pas` (public): the routine headings other units call,
  the statuses, and the six segment words AS_ reads and
  MST_$MST_PAGES_LIMIT (OS_ reads it).
- `mst/mst_internal.ins.pas`: the lock numbers (`mst_lock_asid`, `_ast`,
  `_mmu`), `mst_max_asid` and `mst_asid_none`, `mst_asid_base_t`, the
  rest of MST_WIRED's block and MST_$MST_PAGES_WIRED as externs, the
  MSTE record and the MST tables, and the headings only MST calls
  (MST_$REMOVE_SEG, MST_$SET, MST_$SET_CLEAR).  Apart from mst.ins.pas
  because three of mst.ins.pas's includers (as, flop, pacct) include
  neither `ml/ml.ins.pas` nor `ast/ast.ins.pas`.
- Elsewhere: `ast/ast.ins.pas` has `ast_$locate_request_t` and the
  headings of AST_$LOCATE_ASTE and AST_$RELEASE_PAGES (their one caller
  is MST_$REMOVE_SEG), AST_$MSTE_ACTIVATE_AND_WIRE and AST_$TOUCH;
  `proc1/proc1.ins.pas` PROC1_$GET_CPU_USAGE's heading;
  `asknode/asknode.pas` includes `mst/mst.ins.pas` (for
  MST_$GET_PRIVATE_SIZE); `pacct/pacct.ins.pas` and `pacct/log.pas`:
  PACCT_$LOG's proc_times `univ`.

## Routines and their fragments

| routine | section | fragment |
|---------|---------|----------|
| MST_$VA_TO_SEGNO | WIRED_PROC | `va_to_segno.pas` |
| MST_$TOUCH | WIRED_PROC | `touch.pas` |
| MST_$REMOVE_SEG | WIRED_PROC | `remove_seg.pas` |
| MST_$UNTHREAD_PMAP | WIRED_PROC (`pmap_threads`) | `unthread_pmap.pas` |
| MST_$BST_TO_VA | WIRED_PROC (`pmap_threads`) | `bst_to_va.pas` |
| mst_$va_to_aste (local) | WIRED_PROC (`pmap_threads`) | `va_to_aste.pas` |
| MST_$ASSOC | WIRED_PROC (`pmap_threads`) | `assoc.pas` |
| MST_$INSTALL_IOPPN | WIRED_PROC (`pmap_threads`) | `install_ioppn.pas` |
| MST_$REMOVE_IOPPN | WIRED_PROC (`pmap_threads`) | `remove_ioppn.pas` |
| MST_$FIND | WIRED_PROC | `find.pas` |
| MST_$WIRE | WIRED_PROC | `wire.pas` |
| MST_$SET, MST_$SET_CLEAR | WIRED_PROC (MST_ASM) | `m68k/set.s` (hand assembly) |
| MST_$PRE_INIT | OS_INIT_PROC | `pre_init.pas` |
| MST_$INIT, its nested mst_init_page and mst_init_global_page | OS_INIT_PROC | `init.pas` |
| MST_$DISKLESS_INIT | OS_INIT_PROC | `diskless_init.pas` |
| MST_$MAP_CANNED | OS_INIT_PROC | `map_canned.pas` |
| MST_$MAP_CANNED_AT | OS_INIT_PROC | `map_canned_at.pas` |
| mst_$init_table_page (module-local) | .TEXT | `init_table_page.pas` |
| MST_$ALLOC_ASID | .TEXT | `alloc_asid.pas` |
| MST_$DEALLOCATE_ASID | .TEXT | `deallocate_asid.pas` |
| MST_$MAPS_AT | .TEXT | `maps_at.pas` |
| MST_$MAP_INITIAL_AREA | .TEXT | `map_initial_area.pas` |
| MST_$MAP_AT | .TEXT | `map_at.pas` |
| MST_$CHANGE_RIGHTS | .TEXT | `change_rights.pas` |
| mst_$alloc_segs (module-local), its nested mst_$audit_map | .TEXT | `alloc_segs.pas` |
| MST_$GROW_AREA | .TEXT | `grow_area.pas` |
| MST_$MAP | .TEXT | `map.pas` |
| MST_$MAP_TOP | .TEXT | `map_top.pas` |
| MST_$MAP_GLOBAL | .TEXT | `map_global.pas` |
| MST_$MAPS | .TEXT | `maps.pas` |
| MST_$REMAP | .TEXT | `remap.pas` |
| MST_$REMAP_PRIVI | .TEXT | `remap_privi.pas` |
| MST_$MAP_AREA | .TEXT | `map_area.pas` |
| MST_$MAP_AREA_AT | .TEXT | `map_area_at.pas` |
| mst_$lookup_object (module-local) | .TEXT | `lookup_object.pas` |
| mst_$set_mstes (module-local) | .TEXT | `set_mstes.pas` |
| mst_$alloc_table_page (module-local) | .TEXT | `alloc_table_page.pas` |
| MST_$GET_UID | .TEXT | `get_uid.pas` |
| MST_$GET_UID_ASID | .TEXT | `get_uid_asid.pas` |
| MST_$GET_VA_INFO | .TEXT | `get_va_info.pas` |
| mst_$va_to_pte (module-local) | .TEXT | `va_to_pte.pas` |
| MST_$INVALIDATE | .TEXT | `invalidate.pas` |
| MST_$MAP_SPECIAL | .TEXT (`large_address_space`) | `map_special.pas` |
| MST_$PRIV_SET_TOUCH_AHEAD_CNT | .TEXT | `priv_set_touch_ahead_cnt.pas` |
| MST_$SET_TOUCH_AHEAD_CNT | .TEXT | `set_touch_ahead_cnt.pas` |
| MST_$UNMAP | .TEXT | `unmap.pas` |
| MST_$UNMAP_GLOBAL | .TEXT | `unmap_global.pas` |
| MST_$UNMAPS | .TEXT | `unmaps.pas` |
| MST_$UNMAP_AND_FREE_AREA | .TEXT | `unmap_and_free_area.pas` |
| MST_$UNMAPS_AND_FREE_AREA | .TEXT | `unmaps_and_free_area.pas` |
| MST_$UNMAP_ALL | .TEXT | `unmap_all.pas` |
| MST_$SET_GUARD | .TEXT | `set_guard.pas` |
| MST_$UNMAP_PRIVI | .TEXT | `unmap_privi.pas` |
| MST_$GET_PRIVATE_SIZE | .TEXT | `get_private_size.pas` |
| MST_$WIRE_AREA | .TEXT | `wire_area.pas` |
| MST_$FORK | PROC2_CREATE_PRO | `fork.pas` |
| mst_$unwire_page (module-local) | PROC2_DELETE_PRO | `unwire_page.pas` |
| mst_$unwire_asid_pages (module-local) | PROC2_DELETE_PRO | `unwire_asid_pages.pas` |
| mst_$free_region (module-local, `large_address_space`) | PROC2_DELETE_PRO | `free_region.pas` |
| MST_$FREE_ASID | PROC2_DELETE_PRO | `free_asid.pas` |

The `%include`s of every fragment are in the two module files, in image
order; each fragment is included exactly once.  The routines and their
boundaries are the map's symbols and the image's frames (every routine
above has one).  The nested ones (MST_$INIT's two, mst_$alloc_segs's
audit_map) are confirmed by their static links; mst_$unwire_page and
mst_$unwire_asid_pages are module-level.  Each fragment has a
`<name>.codegen.md` beside it with the image's evidence; the module
files and the inserts have theirs too.

Names: the map's for the globals and the data symbols; MST_$MAP_CANNED,
MST_$MAPS_AT and MST_$UNMAP_ALL have no earlier source and no caller in
the image, so their headings are their bodies'.  MST_$FIND has no caller
in the image; MST_$FIND's crash status, 16#40005, is "reference to
out-of-bounds address" (stcode.db.10.2).  MST_$MAP and MST_$MAP_TOP both
search from the top (hint 16#7FFFFFFF).

## The large VM layout (SAU9)

With `large_vm` an address space maps a segment through its segment
map entry (SMAPS, an MC68030 long-format table descriptor, per ASID
from SMAP_ASID_BASE) that points at the segment's ASTE page map; BST
threads each page map's entries (`mst_internal.ins.pas`).  MST_$TOUCH
links the entry instead of installing pages; MST_$FIND and MST_$WIRE
always touch; MST_$REMOVE_SEG unlinks.  With `large_address_space` the
regions' segment numbers are constants (`mst.ins.pas`).  The MST_WIRED
block is 0xA58 bytes (`mst_wired.pas`).

With `large_address_space` MST_UNWIRED's .DATA block is 0x74D8 bytes
(`mst_unwired.pas`): a 308-longword page bitmap, MST_$SEGS_MAPPED (per
ASID a count of the mapped segments in each 128-segment group),
MST_$BST_PAGES (per ASID the BST pages installed) and RARS_ASID_BASE.
Each address space has a RARS page (MMU_$RARS_PHADDR) copied from ASID
0's and a set of active 128-segment regions (MST_$REGIONS_ACTIVE, the
global ones from the start); the rest of the segment layout is constants
(`mst_internal.ins.pas`).  MST_$INIT sets these up and MST_$ALLOC_ASID
gives a new ASID its RARS page and the global regions instead of a page
of MSTEs.

An address space's private segments are counted per 128-segment group
(MST_$UNMAP_PRIVI counts a freed entry's group down); a private group
whose count reaches zero, and every active private region when the
ASID is freed (MST_$FREE_ASID), goes back through mst_$free_region: the
region leaves MST_$REGIONS_ACTIVE, its RARS entry is made invalid, and
the group's page of segment map entries, its BST page (when the other
group of the page is not active) and its two pages of MSTEs are given
back.  mst_$unwire_page removes a page by its virtual address
(`mmu/mmu.ins.pas`'s large-VM MMU_$REMOVE).

With the large VM layout the protection lives in the segment map
entries: mst_$set_mstes stores it there (made invalid for MST_$TOUCH to
fill), mst_$va_to_pte reads it back, MST_$INVALIDATE and
MST_$GET_PRIVATE_SIZE test it there; the MSTE's flag word keeps only
the active and modified bits and the ASTE index.  mst_$alloc_table_page
also activates the segment's region (its segment map page, its RARS
entry) and installs its BST page; MST_$FORK copies the segment map
entries; MST_$MAP_CANNED_AT's touch arm activates and threads the
canned segment and purges the address translation cache.

With the large address space mst_$alloc_segs puts a private B-space
mapping in the top 8 segments of private B (the SAU2's whole private
B); with the large VM layout mst_$alloc_segs and MST_$GROW_AREA take
area ids up to 2688 (area/area.ins.pas's area_max_entries).

MST_ is done for the SAU9: every routine of the SAU9 map's MST_WIRED,
MST_ASM and MST_UNWIRED segments, and every module-local, has its sau9
address.  Conditional arms:
MST_$TOUCH, MST_$REMOVE_SEG, MST_$FIND, MST_$WIRE, MST_$PRE_INIT,
MST_$INIT, MST_$ALLOC_ASID, MST_$MAP_CANNED_AT, MST_$MAP_INITIAL_AREA,
mst_$alloc_segs, MST_$INVALIDATE, MST_$UNMAP_PRIVI,
MST_$GET_PRIVATE_SIZE, MST_$FORK, MST_$FREE_ASID, mst_$set_mstes,
mst_$alloc_table_page, mst_$va_to_pte and mst_$unwire_page; MST_$GROW_AREA
through area_max_entries; with `pmap_threads' MST_$UNTHREAD_PMAP,
MST_$BST_TO_VA, mst_$va_to_aste, MST_$ASSOC and the IOPPN pair, and with
the large address space MST_$MAP_SPECIAL and mst_$free_region.  The
rest are the SAU2's source: the large address
space's constants, the 68020 forms, or the same code (MST_$SET and
MST_$SET_CLEAR byte for byte).

## The layout chosen at boot (SAU8)

The SAU8 (DN3000 family) has the large VM layout and the regions
(`vm_regions`) without the large address space's constants: its
segment layout is MST_WIRED's words, as on the SAU2, and MST_$PRE_INIT
replaces the default layout's (2048 segments: private A 1600, private
B 64, global A and B 192 each) with the MC68851 PMMU's (8192 segments:
private A 7360, private B 64, global A 256, global B 512) when
MMU_$HAVE_PMMU is set (`run_time_layout`).  With them go the region
words, REGION_$PRIVATE_TN .. REGION_$TN, regions of 64 segments, and
SPECIAL_$SEG, the special segments' first address.  The MST_WIRED block
is 0x6E8 bytes and MST_UNWIRED's .DATA block 0x3670.

Two regions share a page of segment map entries (64 entries of 8
bytes): mst_$alloc_table_page gives a region its partner's page when
the partner is active, the odd one the page's second half, and
mst_$free_region gives the page back with the last of the two.  A BST
page serves four groups, freed when none of them has a segment mapped.
Each ASID's root entries are REGION_$TN longwords in RARS, several
ASIDs to a page; MST_$RAR_PAGES records the pages installed.  ASID 1's
follow ASID 0's in RARS's first page (MST_$INIT); every new ASID gets
its page of MSTEs as on the SAU2, its OS wired entry, and a copy of
ASID 0's spare segment map entry (the one after its global segments)
for that entry; MST_$FORK leaves the child's first entry valid.
MST_$FREE_ASID frees the active regions but the global ones and keeps
the root entries' page.  MST_$TOUCH and mst_$va_to_aste leave a global
segment's map entry with the MC68851's shared-globally bit
(`smap_shared_global`).

MST_ is done for the SAU8: every routine of the SAU8 map's MST_WIRED,
MST_ASM and MST_UNWIRED segments, and every module-local, has its sau8
address.  New arms: MST_$PRE_INIT, MST_$INIT, MST_$ALLOC_ASID,
mst_$alloc_table_page, mst_$free_region, MST_$FREE_ASID, MST_$FORK's
tail; layout arms in mst_$alloc_segs, MST_$INVALIDATE,
MST_$MAP_SPECIAL, MST_$UNMAP_PRIVI and MST_$GET_PRIVATE_SIZE; the
segment map fill of MST_$TOUCH and mst_$va_to_aste.  The rest are the
SAU2's or SAU9's source as it stands.  dpc does not yet compile
`mst_unwired.pas` for the SAU8 (the run-time-range set constructors of
MST_$INIT, MST_$ALLOC_ASID and MST_$FREE_ASID: their TODO(pascal)
blocks).

## The region registers (SAU4)

The SAU4 (DN460, DN660, DSP160) has the large VM layout, the regions
and the page maps' thread (`pmap_threads`) with an MMU of its own
(`region_mmu`): 32 region registers per address space, so a region is
256 of its 8192 segments (`vm_8192_segs`: private A 7424, global A
256, private B 256, global B 256, constants as with the large address
space).  An ASID's 32 registers are longwords in RARS, 8 ASIDs to a
page (MST_$RAR_PAGES); a register and a segment map entry each hold a
valid bit and a 26-bit physical address, the register a global bit and
the entry the MST entry's protection, which MST_$TOUCH,
mst_$va_to_pte, MST_$INVALIDATE and MST_$GET_PRIVATE_SIZE read back.
mst_$alloc_table_page gives each region made active its own page of
entries and loads the register into the MMU (MMU_$INSTALL_REGION) when
the address space is the current one; mst_$free_region clears it the
same way and gives back the group's BST page and four MST words with
the region.  MST_$INIT, MST_$ALLOC_ASID and MST_$FORK's tail follow
the layout chosen at boot's forms with constants; MST_$FREE_ASID keeps
the registers' shared page.  The MST is 7168 words
(`mst_7168_words`); the special segments are the top 9 of private B;
mst_$set_mstes does not clear the cache (`set_mstes_no_cache_clear`).
MST_$FIND and MST_$WIRE are the SAU2's (`find_touches` is the SAU6..9
form), and the map has no MST_$BST_TO_VA or MST_$ASSOC
(`bst_va_lookup`).  The MST_WIRED block is 0x400 bytes and
MST_UNWIRED's .DATA block 0xF78.

Every routine of the SAU4 map's MST_WIRED, MST_ASM and MST_UNWIRED
segments, and every module-local, has its sau4 address.

## Open items

The TODO(pascal) blocks of `alloc_asid.pas`, `alloc_segs.pas`,
`change_rights.pas`, `fork.pas`, `free_asid.pas`, `get_private_size.pas`,
`grow_area.pas`, `init.pas`, `init_table_page.pas`, `lookup_object.pas`,
`map_canned.pas`, `map_canned_at.pas`, `map_initial_area.pas`,
`pre_init.pas`, `priv_set_touch_ahead_cnt.pas`, `remap_privi.pas`,
`set_mstes.pas` and `unmap_privi.pas` (frames and the image's forms dpc
does not reproduce).  The lock stand-ins of `mst_wired.pas` follow RIP's
open question.  The names copy_on_write and
writable for protection bits 2 and 0 are unverified
(`mst_internal.ins.pas`).
