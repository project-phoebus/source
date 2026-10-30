{ area/area.ins.pas - AREA_ (the anonymous-area manager), for the Domain
  Pascal tree.

  The statuses, types, block symbols and routine headings other units
  use.  No customer insert file declares these.  Include base/base.ins.pas
  before it.
}

const
  { stcode.db.10.2, "OS / Areas": 32000a "internal error".
    pmap_$write_page passes it to CRASH_SYSTEM when an area page's ASTE
    is not remote.  The name follows the other status_$area_ names; the
    text's. }
  status_$area_internal_error = 16#0032000A;

  { The statuses the AREA_ routines store (stcode.db.10.2 "OS / Areas"):
    area_$internal_create's when the table cannot grow;
    AREA_$CREATE_FROM's when the UID chains are exhausted; AREA_$DELETE's
    and area_$resize's for an area not in use. }
  status_$area_none_free = 16#00320001;
  status_$area_no_free_resources = 16#00320005;
  status_$area_not_active = 16#00320006;
  { AREA_$DELETE's when the caller does not own the area. }
  status_$area_not_owner = 16#00320007;
  { area_$resize's when the rounded commit exceeds the rounded virtual
    size (stcode.db.10.2 "OS / Areas" 32000b "bad reserve"). }
  status_$area_bad_reserve = 16#0032000B;

  { The members of an area entry's flags word (bits 0..4 of the word at
    +0x2E): area_$internal_create stores the word whole, [active,
    shared], and adds member 1 through the word's low byte;
    area_$internal_delete and area_$resize test member 0. }
  area_$f_active = 0;
  area_$f_reversed = 1;
  area_$f_touched = 2;
  area_$f_shared = 3;
  area_$f_in_trans = 4;

  { The members of a slot cell's state byte: area_$seg_slot_t below. }
  area_$slot_in_trans = 6;
  area_$slot_has_aste = 7;

  { AREAS' bound (below), the most area entries: 1344, or with the
    large VM layout 2688 (AREAS to OS_LOW_END, 0x1F800 bytes of entries
    of 0x30, in the SAU9 map; mst_$alloc_segs and MST_$GROW_AREA test
    an area id against 2688, and AREA_$INIT sets the table's maximum to
    it, on every large_vm SAU). }
%if large_vm %then
  area_max_entries = 2688;
%else
  area_max_entries = 1344;
%endif

type
  { An area entry's flags, a word set (above). }
  area_$flags_t = set of 0..15;

  { One segment-map slot cell, 4 bytes, for a group of eight segments:
    the segments' allocation bits, the state byte (member 7: aste_index
    names the group's first ASTE; member 6: in transition) and the ASTE
    index; read as a longword, its low 22 bits are the disk address of
    the group's page-map block while member 7 is clear.
    area_$free_slot_segments tests and updates the bytes, stores the bits
    byte and the index word, and reads and stores the address field: so
    a packed record with two views.  The entry holds the first two cells
    (seg_bitmap below), an overflow table's page the others
    (area/area.pas area_$seg_cells_t).  A dpc probe: aste_index 0x2, size
    4, `daddr := 0' compiled as the image's masked store; the sets' bytes
    (0x0, 0x1) follow from those, as dpc does not generate set fields of
    a packed record yet. }
  area_$seg_slot_t = packed record
    case integer of
      1: (bits: set of 0..7;              { 0x00 }
          state: set of 0..7;             { 0x01 }
          aste_index: pinteger);          { 0x02 }
      2: (unused_hi: 0..1023;             { bits 31..22 }
          daddr: 0..16#3FFFFF);           { bits 21..0 }
  end;

  area_$entry_ptr_t = ^area_$entry_t;

  { One area entry, 0x30 bytes.  An area segment's ASTE names its area
    entry where an object's names its AOTE: pmap_$write_page and
    pmap_$fill_write_qblks read area_id and volx through the ASTE's aote
    pointer.  The area's id and its remote volume are read as unsigned
    words, widened with zeros: pinteger; volx a word passed by value
    (integer).  next and prev are the entry's own pointer type: the lists
    are threaded through them (area_$internal_create,
    area_$alloc_resources).  flags is the set above.  A dpc probe gives
    every offset below and the size 0x30.  seg_bitmap is the first two
    slot cells, from 0: area_$free_segments passes cell n, n 0 or 1.
    first_seg_index is pinteger: AREA_$REMOVE_SEG widens it with zeros
    for a longword comparison, and AREA_$COPY's copy of it, seg_page, is
    widened with zeros; its other users (area/transfer.pas,
    area/copy.pas, area/thread_bstes.pas) only copy, store and add to it; no
    site widens it with its sign. }
  area_$entry_t = record
    next: area_$entry_ptr_t;              { 0x00 }
    prev: area_$entry_ptr_t;              { 0x04 }
    virt_size: linteger;                  { 0x08 }
    commit_size: linteger;                { 0x0C }
    caller_id: integer32;                 { 0x10 }
    first_bste: integer;                  { 0x14 }
    first_seg_index: pinteger;            { 0x16 }
    seg_bitmap: array[0..1] of area_$seg_slot_t;
                                          { 0x18 }
    remote_uid: integer32;                { 0x20 }
    volx: integer;                        { 0x24 }
    owner_asid: integer;                  { 0x26 }
    remote_volx: pinteger;                { 0x28 }
    area_id: pinteger;                    { 0x2A }
    generation: integer;                  { 0x2C }
    flags: area_$flags_t;                 { 0x2E }
  end;

  { An entry seen as its 24 words: area_$alloc_resources clears a new
    entry a word at a time through a pointer stepped from the entry's
    start. }
  area_$entry_words_t = array[1..24] of integer;
  area_$entry_words_ptr_t = ^area_$entry_words_t;

  { An area handle, a longword: the entry's generation in the high word,
    its id in the low.  area_$internal_create builds it in its frame and
    passes it whole by value to AREA_$DELETE, which reads the low word.
    The id is an unsigned word (compared unsigned against
    AREA_$N_AREAS). }
  area_$handle_t = record
    generation: integer;                  { 0x00 }
    area_id: pinteger;                    { 0x02 }
  end;

  { AREA_$FORMAT, four words: AREA_$INIT stores max_entries and clears
    the two pool words; area_$alloc_resources compares the table's count
    with max_entries unsigned.  word_00 is never touched by the routines.
    seg_table_next and seg_table_count are integer: area_$alloc_seg_table
    compares the count signed and widens the cursor with its sign;
    area_$free_seg_table compares the cursor signed.  Their only other
    user, AREA_$INIT, stores 0 into both (area/init.pas). }
  area_$format_t = record
    word_00: pinteger;                    { 0x00 }
    max_entries: pinteger;                { 0x02 }
    seg_table_next: integer;              { 0x04 }
    seg_table_count: integer;             { 0x06 }
  end;

var
  { AREAS (map symbol without `$', the first of a VM_TABLES segment of
    0xFC00 bytes): the area entries, indexed from 1 (an area's id is its
    entry's index).  pmap_$write_page reads entry area_id's remote volume
    (the lower bound folded into the displacement).  The bound is
    area_max_entries: the segment holds 0xFC00 bytes = 1344 entries of
    0x30 (0x1F800 bytes = 2688 entries with the large VM layout), and the
    table may grow to AREA_$FORMAT.max_entries, the same number
    (AREA_$INIT; area_$alloc_resources' clamp). }
  areas: extern array[1..area_max_entries] of area_$entry_t;

  { AREA_$PARTNER (map symbol, in the AREA_ block): the node address of
    the diskless partner, 8 bytes, copied whole by pmap_$write_page. }
  area_$partner: extern uid_$t;

  { AREA_$PARTNER_PKT_SIZE (map symbol): a word (pmap_$write_page). }
  area_$partner_pkt_size: extern integer;

  { The other map symbols of AREA_'s block, defined by area/area.pas (its
    comment lays the block out): AREA_$FREE_LIST (+0x5C8), the head of
    the free entries; AREA_$FORMAT (+0x5D4); AREA_$DEL_DUP and _$CR_DUP
    (+0x5DC, +0x5DE), counted by AREA_$DELETE_FROM and AREA_$CREATE_FROM;
    AREA_$N_FREE (+0x5E0), a word counter; AREA_$N_AREAS (+0x5E2), the
    highest id in use, compared unsigned with max_entries and with a
    handle's id: pinteger.  The three eventcounts are declared in
    area/area.pas (they need ec/ec.ins.pas, which this insert's includers
    do not all include). }
  area_$free_list: extern area_$entry_ptr_t;
  area_$format: extern area_$format_t;
  area_$del_dup: extern integer;
  area_$cr_dup: extern integer;
  area_$n_free: extern integer;
  area_$n_areas: extern pinteger;

{ ---- Routine headings, in map order ---- }

{ AREA_$CREATE - create an area in the current address space. }
function area_$create(virt_size: integer32; commit_size: integer32;
                      shared: boolean; out status: status_$t): integer32;
  options(extern, val_param);

{ AREA_$CREATE_FROM - create an area for a remote UID, or find it again. }
function area_$create_from(remote_uid: linteger; virt_size: integer32;
                           commit_size: integer32; caller_id: integer32;
                           out status: status_$t): pinteger;
  options(extern, val_param);

{ AREA_$DELETE - delete an area by its handle. }
procedure area_$delete(handle: area_$handle_t; out status: status_$t);
  options(extern, val_param);

{ AREA_$DELETE_FROM - delete an area on a remote caller's behalf. }
procedure area_$delete_from(area_index: pinteger; remote_uid: linteger;
                            caller_id: integer32; out status: status_$t);
  options(extern, val_param);

{ AREA_$FREE_ASID - delete every area an address space owns. }
procedure area_$free_asid(asid: integer); options(extern, val_param);

{ AREA_$SHUTDOWN - delete every area at shutdown. }
procedure area_$shutdown; extern;

{ AREA_$FREE_FROM - delete every area made for one remote UID. }
procedure area_$free_from(remote_uid: linteger); options(extern, val_param);

{ AREA_$TRANSFER - give an area to another address space. }
function area_$transfer(var handle: univ area_$handle_t; new_asid: integer;
                        new_seg_idx: integer; new_virt_size: linteger;
                        out status: status_$t): integer;
  options(extern, val_param);

{ AREA_$GROW - set an area's sizes, through its handle. }
procedure area_$grow(handle: area_$handle_t; virt_size: linteger;
                     commit_size: linteger; out status: status_$t);
  options(extern, val_param);

{ AREA_$GROW_TO - set an area's sizes, through its index. }
procedure area_$grow_to(area_index: pinteger; virt_size: linteger;
                        commit_size: linteger; out status: status_$t);
  options(extern, val_param);

{ AREA_$INVALIDATE - discard a run of pages of an area. }
procedure area_$invalidate(handle: area_$handle_t; seg_idx: pinteger;
                           page_offset: pinteger; count: linteger;
                           unused_flag: boolean; out status: status_$t);
  options(extern, val_param);

{ AREA_$COPY - copy an area, copy-on-write, into another address space. }
function area_$copy(handle: area_$handle_t; new_asid: integer;
                    pid: integer; stack_limit: linteger;
                    out status: status_$t): integer32;
  options(extern, val_param);

{ AREA_$TOUCH - fault one page of an area in, growing its commitment. }
procedure area_$touch(var handle_ptr: area_$handle_t; bste_idx: pinteger;
                      seg_idx: pinteger; seg_index: pinteger;
                      var ppn_array: univ ast_$ppn_list_t;
                      out status_p: status_$t);
  options(extern, val_param);

{ AREA_$ASSOC - associate one page of an area with a physical page. }
procedure area_$assoc(area_id: pinteger; bste_idx: pinteger; page: pinteger;
                      ppn: integer32; out status_ret: status_$t);
  options(extern, val_param);

{ AREA_$THREAD_BSTES - record an area's first BSTE and segment index. }
procedure area_$thread_bstes(var handle_ptr: area_$handle_t;
                             asid: integer; seg_idx: pinteger;
                             count: integer; area_seg: pinteger;
                             out status_ret: status_$t);
  options(extern, val_param);

{ AREA_$REMOVE_SEG - take one segment out of an area. }
procedure area_$remove_seg(var seg_rec: area_$handle_t; asid: integer;
                           seg_index: pinteger; release: boolean;
                           area_seg: pinteger; out status_ret: status_$t);
  options(extern, val_param);

{ AREA_$DEACTIVATE_ASTE - write back and unchain the ASTE of an area segment. }
procedure area_$deactivate_aste(var aste: ast_$aste_t;
                                out status_ret: status_$t); extern;

{ AREA_$INIT - set up the area manager's block at boot. }
procedure area_$init; extern;

{ The REM_FILE_ headings AREA_ calls (REM_FILE_$CREATE_AREA,
  _$DELETE_AREA, _$GROW_AREA) are in rem_file/rem_file.ins.pas. }

{ MMU_$REMOVE_LIST, which AREA_$REMOVE_SEG calls, is in
  mmu/mmu.ins.pas. }
