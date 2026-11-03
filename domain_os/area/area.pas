{ area/area.pas - the AREA_ module, the anonymous-area manager.

  Image addresses:
    sau2  0x00E1E118  AREA_ data (WIRED_DATA, 0x5E8 bytes)
    sau4  0x0F81F510  AREA_ data (WIRED_DATA, 0x5E8 bytes)
    sau8  0x03C1F918  AREA_ data (WIRED_DATA, 0x5E8 bytes)
    sau9  0x3C420D18  AREA_ data (WIRED_DATA, 0x5E8 bytes)

  One compilation unit: the map's AREA_ code segments in WIRED_PROC
  (0x2F20 bytes, the SAU9's 0x3428, AREA_$CREATE ..
  AREA_$DEACTIVATE_ASTE with the module-local routines between them) and
  in OS_INIT_PROC (0x154 bytes, the SAU9's 0x14C, AREA_$INIT), and its
  data segment in WIRED_DATA (0x5E8 bytes on both).

  The area entries (AREAS) and the RPMAP page window
  (AREA_$RPMAP_CACHE) are VM_TABLES symbols, another unit's: externs.
  With the large VM layout AREA_ also keeps MST's forward tables (the
  segment map entries and the BST links of an area's segments): MST's
  inserts are included for them.

  The heading: `module area_, wired_proc, wired_data;'; AREA_$INIT is
  headed `[section(os_init_proc, os_init_data)]' and reaches the block
  by its address.

  The data, 0x5E8 bytes, zero but the three eventcounts' waiter links
  (each pointing at its eventcount) and AREA_$FORMAT's first word:

    +0x000  area_$rpmap_page      3 * 4  the RPMAP pages' page numbers
    +0x00C  (4 bytes, unused_00c: a stand-in, see the TODO)
    +0x010  area_$rpmap_slots  3 * 0xC   the RPMAP cache's slots
    +0x034  (4 bytes, unused_034: a stand-in)
    +0x038  AREA_$RPMAP_IN_TRANS_EC 0xC  defined, self-linked

    +0x044  (4 bytes, unused_044: a stand-in)
    +0x048  AREA_$IN_TRANS_EC      0xC   defined, self-linked
    +0x054  (4 bytes, unused_054: a stand-in)
    +0x058  AREA_$PITE_IN_TRANS_EC 0xC   defined, self-linked
    +0x064  (4 bytes, unused_064: a stand-in)

    +0x068  area_$seg_table_list 58 * 4  the per-address-space overflow
                                         table lists, from 0
    +0x150  area_$seg_table_pool 64 * 0xC  the overflow tables, from 0
    +0x450  area_$uid_hash_free      4   the free hash records
    +0x454  area_$uid_hash      11 * 4   the hash buckets, uid mod 11

    +0x480  area_$uid_hash_pool 11 * 8   the hash records
    +0x4D8  area_$asid_list     58 * 4   the per-address-space area
                                         lists, from 0
    +0x5C0  area_$rpmap_seq          4   the RPMAP cache's clock
    +0x5C4  area_$next_caller_id     4

    +0x5C8  AREA_$FREE_LIST          4   defined
    +0x5CC  AREA_$PARTNER            8   defined
    +0x5D4  AREA_$FORMAT             8   defined
    +0x5DC  AREA_$DEL_DUP            2   defined
    +0x5DE  AREA_$CR_DUP             2   defined

    +0x5E0  AREA_$N_FREE             2   defined
    +0x5E2  AREA_$N_AREAS            2   defined
    +0x5E4  AREA_$PARTNER_PKT_SIZE   2   defined
    +0x5E6  (2 bytes: the block's rounding to 4)

  The routines live in fragment files, included below in image order.

  Build: dpc -I domain_os domain_os/area/area.pas.  Check:
  tools/pascal_check.sh.
}
module area_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'as/as.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'ast/ast_net.ins.pas';
%include 'disk/disk.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'bat/bat.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'cal/cal.ins.pas';
%include 'anon/anon.ins.pas';
%include 'acl/acl.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'area/area.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mst/mst_internal.ins.pas';

%if large_vm %then
const
  { The process type of a network page server (NETWORK_$ADD_PAGE_SERVERS
    creates them with type 8): AREA_$TOUCH makes no segment map entry
    valid for a page server's touch. }
  area_page_server_type = 8;

%endif
type
  { One slot of the RPMAP cache, 0xC bytes.  seq is the LRU key,
    compared unsigned; volx is compared with the entry's unsigned
    remote_volx in a word and widened with zeros for the request:
    pinteger; group is widened with its sign, and set to -1 by
    AREA_$INIT: integer; dirty and in_trans are booleans.  The last word
    is never addressed. }
  area_$rpmap_slot_t = record
    seq: linteger;                        { 0x00 }
    volx: pinteger;                       { 0x04 }
    group: integer;                       { 0x06 }
    dirty: boolean;                       { 0x08 }
    in_trans: boolean;                    { 0x09 }
    reserved_0a: integer;                 { 0x0A }
  end;

  { One overflow segment table, 0xC bytes (area_$alloc_seg_table stores
    its fields). }
  area_$seg_table_ptr_t = ^area_$seg_table_t;
  area_$seg_table_t = record
    area_id: integer;                     { 0x00 }
    table_index: [byte] 0..255;           { 0x02 }
    allocated: boolean;                   { 0x03 }
    next: area_$seg_table_ptr_t;          { 0x04 }
    bitmap: univ_ptr;                     { 0x08 }
  end;

  { One UID hash record, 8 bytes: the chain link and the head of the
    chain's entries (AREA_$CREATE_FROM's search; AREA_$INIT's stride
    8). }
  area_$uid_hash_ptr_t = ^area_$uid_hash_t;
  area_$uid_hash_t = record
    next: area_$uid_hash_ptr_t;           { 0x00 }
    first_entry: area_$entry_ptr_t;       { 0x04 }
  end;

  { An overflow table's page of slot cells, 0x100 cells of 4 bytes, from
    0: area_$free_segments forms the first cell's address from the
    table's page and steps it by one cell.  The page is the record's
    bitmap (univ_ptr), converted at the use. }
  area_$seg_cells_t = array[0..255] of area_$seg_slot_t;
  area_$seg_cells_ptr_t = ^area_$seg_cells_t;

  { The same page as 256 longwords: area_$alloc_seg_table clears a new
    table's page through a stepped pointer. }
  area_$page_longs_t = array[0..255] of integer32;
  area_$page_longs_ptr_t = ^area_$page_longs_t;

var
  { PIT_PAGES (map symbol without `$', in a VM_TABLES segment, before
    MSTE_PAGES: 64 pages of 0x400): the overflow tables' pages, one per
    pool record.  area_$alloc_seg_table forms page i's address,
    area_$free_seg_table the index back from it. }
  pit_pages: extern array[0..63] of area_$page_longs_t;

  { AREA_$RPMAP_CACHE (map symbol in a VM_TABLES segment, after
    AST_PMAPS): the three 1 KB pages of the RPMAP cache, indexed from 1:
    area_$rpmap_get returns a page (the bound folded into the
    displacement); AREA_$INIT maps them. }
  area_$rpmap_cache: extern array[1..3] of ast_$page_t;

  { The AREA_ block's eventcounts (map symbols, defined below): declared
    here, not in area/area.ins.pas, so that the insert needs no
    ec/ec.ins.pas (pmap/pmap.pas includes it before ec in its list, but
    other includers may not). }
  area_$rpmap_in_trans_ec: extern ec_$eventcount_t;
  area_$in_trans_ec: extern ec_$eventcount_t;
  area_$pite_in_trans_ec: extern ec_$eventcount_t;

{ AST_$FETCH_PMAP_PAGE: its heading is ast/ast_net.ins.pas's, included
  above after NETWORK_'s insert }

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  area_$rpmap_page: array[1..3] of integer32;      { +0x000, zero }
  unused_00c: integer32;                           { +0x00C, zero: TODO }
  area_$rpmap_slots: array[1..3] of area_$rpmap_slot_t;
                                                   { +0x010, zero }
  unused_034: integer32;                           { +0x034, zero: TODO }

define
  area_$rpmap_in_trans_ec :=
    [value := 0,
     waiter_list_head := addr(area_$rpmap_in_trans_ec),
     waiter_list_tail := addr(area_$rpmap_in_trans_ec)];
                                                   { +0x038 }

var
  unused_044: integer32;                           { +0x044, zero: TODO }

define
  area_$in_trans_ec := [value := 0,
                        waiter_list_head := addr(area_$in_trans_ec),
                        waiter_list_tail := addr(area_$in_trans_ec)];
                                                   { +0x048 }

var
  unused_054: integer32;                           { +0x054, zero: TODO }

define
  area_$pite_in_trans_ec := [value := 0,
                             waiter_list_head := addr(area_$pite_in_trans_ec),
                             waiter_list_tail := addr(area_$pite_in_trans_ec)];
                                                   { +0x058 }

var
  unused_064: integer32;                           { +0x064, zero: TODO }
  area_$seg_table_list: array[0..57] of area_$seg_table_ptr_t;
                                                   { +0x068, zero }
  area_$seg_table_pool: array[0..63] of area_$seg_table_t;
                                                   { +0x150, zero }
  area_$uid_hash_free: area_$uid_hash_ptr_t;       { +0x450, zero }
  area_$uid_hash: array[0..10] of area_$uid_hash_ptr_t;
                                                   { +0x454, zero }
  area_$uid_hash_pool: array[0..10] of area_$uid_hash_t;
                                                   { +0x480, zero }
  area_$asid_list: array[0..57] of area_$entry_ptr_t;
                                                   { +0x4D8, zero }
  area_$rpmap_seq: linteger;                       { +0x5C0, zero }
  area_$next_caller_id: integer32;                 { +0x5C4, zero }

define
  area_$free_list;                                 { +0x5C8, zero }
  area_$partner;                                   { +0x5CC, zero }
  area_$format := [word_00 := 1];                  { +0x5D4: 0001 0000
                                                     0000 0000 }
  area_$del_dup;                                   { +0x5DC, zero }
  area_$cr_dup;                                    { +0x5DE, zero }
  area_$n_free;                                    { +0x5E0, zero }
  area_$n_areas;                                   { +0x5E2, zero }
  area_$partner_pkt_size;                          { +0x5E4, zero }

{ TODO(pascal) AREA_'s five unaddressed gaps in the block

  +0x00C, +0x034, +0x044, +0x054 and +0x064 (4 bytes each) are never
  addressed; stand-ins hold their places.  An 8-byte alignment of
  objects of 8 bytes or more from the block's start (a lead) explains
  all five: the slot array (36 bytes) at +0x10, the eventcounts (12) at
  +0x38, +0x48 and +0x58, the list array (232) at +0x68.  It does not
  explain the hash buckets (44 bytes) at +0x454, nor AREA_$PARTNER and
  AREA_$FORMAT (8 each) at +0x5CC and +0x5D4, all 4 mod 8: the same open
  point as pmap/pmap.pas's and proc1/proc1.pas's gaps (there, too, the
  map-symbol objects are the misfits). }

{ TODO(pascal) AREA_'s frames against their locals

  Counting a module-local's reserved slot, each register-held local's
  slot and one slot per `with' (a
  lead), these frames leave bytes no object explains:
  area_$rpmap_get, area_$alloc_resources, area_$internal_create,
  AREA_$CREATE_FROM, AREA_$INIT, area_$internal_delete,
  area_$free_segments, area_$free_slot_segments, area_$resize,
  area_$remote_sync, AREA_$INVALIDATE, AREA_$COPY,
  area_$find_entry_by_uid, AREA_$TOUCH; AREA_$REMOVE_SEG adds up but the
  places of its register-held locals' slots are not checked.  Exact:
  area_$wait_in_trans, area_$wait_pite_in_trans, AREA_$CREATE,
  AREA_$DELETE, _$DELETE_FROM, _$FREE_ASID, _$SHUTDOWN, _$FREE_FROM,
  _$TRANSFER, _$GROW, _$GROW_TO, _$ASSOC, _$THREAD_BSTES. }

define
  area_$create;
  area_$create_from;
  area_$delete;
  area_$delete_from;
  area_$free_asid;
  area_$shutdown;
  area_$free_from;
  area_$transfer;
  area_$grow;
  area_$grow_to;
  area_$invalidate;
  area_$copy;
  area_$touch;
  area_$assoc;
  area_$thread_bstes;
  area_$remove_seg;
  area_$deactivate_aste;
  area_$init;

{ Module-local routines called before their bodies. }

{ area_$internal_delete: the entry by address, the id a word (as its
  callers push it), the status by address, the unlink flag a byte.
  area_$internal_create calls it first. }
{ body: area/internal_delete.pas }
procedure area_$internal_delete(var entry: area_$entry_t; area_id: integer;
                                out status: status_$t; unlink: boolean);
  forward; internal;

{ area_$resize: the id a word; the entry by address; the sizes
  longwords, rounded in their slots; the grow word; the status by
  address.  The sizes are linteger: every comparison of them in the body
  is unsigned.  Its callers before it (internal_create, internal_delete,
  TRANSFER) pass integer32 and linteger values.  The forward stays: those
  callers come before the body. }
{ body: area/resize.pas }
procedure area_$resize(area_id: integer; var entry: area_$entry_t;
                       virt_size: linteger; commit_size: linteger;
                       is_grow: integer; out status: status_$t);
  forward; internal;

{ area_$alloc_seg_table: three words by value; a pointer result
  (area_$resize tests it).  The names: asid for owner_asid, table_index
  for the table's number. }
{ body: area/alloc_seg_table.pas }
function area_$alloc_seg_table(asid: integer; area_id: integer;
                               table_index: integer): area_$seg_table_ptr_t;
  forward; internal;

{ area_$get_aste: a word, the slot cell by address, a word and two bytes
  by value, the status by address (cleared first); a pointer result.
  area_id is pinteger: the body widens it with zeros to index AREAS.  The
  callers' pushes are words either way (free_slot_segments, COPY,
  find_entry_by_uid). }
{ body: area/get_aste.pas }
function area_$get_aste(area_id: pinteger; var slot: area_$seg_slot_t;
                        seg_idx: integer; in_trans_held: boolean;
                        create: boolean;
                        out status: status_$t): ast_$aste_ptr_t;
  forward; internal;

{ area_$free_seg_table: two pointers and a word by value
  (area_$free_segments passes its table pointer and prev, a frame local,
  by value).  The names: tbl for its entry. }
{ body: area/free_seg_table.pas }
procedure area_$free_seg_table(tbl: area_$seg_table_ptr_t;
                               prev: area_$seg_table_ptr_t; asid: integer);
  forward; internal;

{ ---- WIRED_PROC ---- }
%include 'area/rpmap_get.pas';              { area_$rpmap_get }
%include 'area/alloc_resources.pas';        { area_$alloc_resources }
%include 'area/wait_in_trans.pas';          { area_$wait_in_trans }
%include 'area/wait_pite_in_trans.pas';     { area_$wait_pite_in_trans }
%include 'area/internal_create.pas';        { area_$internal_create }
%include 'area/create.pas';                 { AREA_$CREATE }
%include 'area/create_from.pas';            { AREA_$CREATE_FROM }
%include 'area/internal_delete.pas';        { area_$internal_delete }
%include 'area/delete.pas';                 { AREA_$DELETE }
%include 'area/delete_from.pas';            { AREA_$DELETE_FROM }
%include 'area/free_asid.pas';              { AREA_$FREE_ASID }
%include 'area/shutdown.pas';               { AREA_$SHUTDOWN }
%include 'area/free_from.pas';              { AREA_$FREE_FROM }
%include 'area/transfer.pas';               { AREA_$TRANSFER }
%include 'area/free_segments.pas';          { area_$free_segments, its
                                              nested
                                              area_$free_slot_segments }
%include 'area/resize.pas';                 { area_$resize, its nested
                                              area_$remote_sync }
%include 'area/grow.pas';                   { AREA_$GROW }
%include 'area/grow_to.pas';                { AREA_$GROW_TO }
%include 'area/invalidate.pas';             { AREA_$INVALIDATE }
%include 'area/copy.pas';                   { AREA_$COPY }
%include 'area/find_entry_by_uid.pas';      { area_$find_entry_by_uid }
%include 'area/touch.pas';                  { AREA_$TOUCH }
%include 'area/assoc.pas';                  { AREA_$ASSOC }
%include 'area/thread_bstes.pas';           { AREA_$THREAD_BSTES }
%include 'area/remove_seg.pas';             { AREA_$REMOVE_SEG }
%include 'area/get_aste.pas';               { area_$get_aste }
%include 'area/alloc_seg_table.pas';        { area_$alloc_seg_table }
%include 'area/free_seg_table.pas';         { area_$free_seg_table }
%include 'area/deactivate_aste.pas';        { AREA_$DEACTIVATE_ASTE }

{ ---- OS_INIT_PROC ---- }
%include 'area/init.pas';                   { AREA_$INIT }
