{ mst/mst_unwired.pas - the MST_UNWIRED module, the unwired half of the
  segment tables: address-space setup, mapping, unmapping and the ASIDs.

  Image addresses:
    sau2  0x00E7CF0C  MST_UNWIRED data (.DATA, 0x48 bytes)
    sau2  0x00E85710  MST_UNWIRED data (DATA$, 4 bytes)
    sau8  0x03C923CC  MST_UNWIRED data (.DATA, 0x3670 bytes)
    sau8  0x03C9E3B8  MST_UNWIRED data (DATA$, 4 bytes)
    sau9  0x3C48E1D0  MST_UNWIRED data (.DATA, 0x74D8 bytes)
    sau9  0x3C49E080  MST_UNWIRED data (DATA$, 4 bytes)

  One compilation unit: the map's MST_UNWIRED code segments in
  OS_INIT_PROC (0x6A8 bytes, MST_$PRE_INIT .. MST_$MAP_CANNED_AT), .TEXT
  (0x1F50 bytes, MST_$ALLOC_ASID .. MST_$WIRE_AREA), PROC2_CREATE_PRO
  (0x1C0 bytes, MST_$FORK) and PROC2_DELETE_PRO (0x1B0 bytes,
  MST_$FREE_ASID), and its data segments in .DATA (0x48 bytes) and DATA$
  (4 bytes, zero).

  The heading: `module mst_unwired;'.  The OS_INIT_PROC routines are
  headed `[section(os_init_proc, os_init_data)]', MST_$FORK
  `[section(proc2_create_pro, data$)]' and the PROC2_DELETE_PRO ones
  `[section(proc2_delete_pro, data$)]'.

  The data, .DATA, 0x48 bytes:

    +0x00  page_avail_bitmap      0x30  all ones
    +0x30  page_alloc_hint        2     zero
    +0x32  mst_$mst_pages_limit   2     zero
    +0x34  mst_$mst_pages_wired   2     zero
    +0x36  unused_36              2     zero (read by nothing)
    +0x38  prot_rights            0x10  mst_$lookup_object's static

  With the large address space (`large_address_space'), 0x74D8 bytes:

    +0x0000  page_avail_bitmap      0x4D0   all ones
    +0x04D0  mst_$segs_mapped       0x6BD8  zero, 238 words per ASID
    +0x70A8  mst_$bst_pages         0x3A0   zero, 16 bytes per ASID
    +0x7448  rars_asid_base         0x74    zero (MST_$PRE_INIT)
    +0x74BC  page_alloc_hint        2       zero
    +0x74BE  mst_$mst_pages_limit   2       zero
    +0x74C0  mst_$mst_pages_wired   2       zero
    +0x74C2  mst_$rar_pages         6       zero (read by nothing)
    +0x74C8  prot_rights            0x10    mst_$lookup_object's static

  With the layout chosen at boot (`run_time_layout'), 0x3670 bytes:

    +0x0000  page_avail_bitmap      0x68    all ones
    +0x0068  mst_$segs_mapped       0x3490  zero, 116 words per ASID
    +0x34F8  mst_$bst_pages         0xE8    zero, a longword per ASID
    +0x35E0  rars_asid_base         0x74    zero (MST_$PRE_INIT)
    +0x3654  mst_$rar_pages         4       zero
    +0x3658  page_alloc_hint        2       zero
    +0x365A  mst_$mst_pages_limit   2       zero
    +0x365C  mst_$mst_pages_wired   2       zero
    +0x365E  unused_365e            2       zero (read by nothing)
    +0x3660  prot_rights            0x10    mst_$lookup_object's static

  Build: dpc -I domain_os domain_os/mst/mst_unwired.pas.  Check:
  tools/pascal_check.sh.
}
module mst_unwired;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'anon/anon.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'wp/wp.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'area/area.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'cache/cache.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mst/mst_internal.ins.pas';

{ The .DATA block's unnamed objects.  Of the four without a map symbol
  (rules, "Module data"):
  - page_avail_bitmap (+0x00) is read and written by MST_$INIT (by its
    address), mst_$alloc_table_page (through A5) and
    mst_$unwire_asid_pages (by its address): a module variable;
  - page_alloc_hint (+0x30) by mst_$alloc_table_page and
    mst_$unwire_asid_pages: a module variable;
  - unused_36 (+0x36) by none: a stand-in;
  - prot_rights (+0x38) by mst_$lookup_object only: its static
    (mst/lookup_object.pas).
  The map symbols MST_$MST_PAGES_LIMIT and _$MST_PAGES_WIRED are defined
  here as module variables, and with the large address space
  MST_$SEGS_MAPPED, MST_$BST_PAGES and RARS_ASID_BASE.  There the
  stand-in's place is taken by 6 bytes no instruction reaches, named
  after the SAU4 map's MST_$RAR_PAGES at the same place (6 bytes after
  MST_$MST_PAGES_WIRED); the SAU9 map has no symbol for them, so a plain
  module variable. }

type
  { One longword of the page bitmap, a set of its 32 pages (member 0 the
    longword's low bit): MST_$INIT removes page 0 and run-time members,
    tests the longword empty and empties whole longwords: set operations
    (mst/init.pas). }
  mst_page_set_t = set of 0..31;

  { A page of memory as the routines that clear one step through it, a
    longword at a time (MST_$INIT's mst_init_page;
    mst_$init_table_page). }
  mst_mem_page_t = array[0..255] of integer32;
  mst_mem_page_ptr_t = ^mst_mem_page_t;

const
  { The share of memory MST_$INIT lets the MSTE pages take, in percent,
    and the most pages, that share of the pageable pages: 358 of 3584
    (10%) on the SAU2, 9830 of 65536 (15%) with the large address space
    (MST_$INIT's bound; the SAU7's 4915 is 15% of 32768).  The bitmap's
    last longword holds page mst_pages_max + 1: 11 on the SAU2, 307 with
    the large address space (MST_$INIT's last index). }
%if large_address_space %then
  mst_pages_percent = 15;
%elseif run_time_layout %then
  mst_pages_percent = 10;
%else
  mst_pages_percent = 10;
%endif
  mst_pages_max = (mmap_$last_ppn - mmap_$first_ppn + 1) *
                  mst_pages_percent div 100;
  mst_bitmap_last = (mst_pages_max + 1) div 32;

%if run_time_layout %then
var
  page_avail_bitmap: array[0..mst_bitmap_last] of mst_page_set_t :=
    [* of [0..31]];                       { +0x0000: ffff x 52 }

define
  mst_$segs_mapped;                       { +0x0068 }
  mst_$bst_pages;                         { +0x34F8 }
  rars_asid_base;                         { +0x35E0 }
  mst_$rar_pages;                         { +0x3654 }

var
  page_alloc_hint: pinteger;              { +0x3658 }

define
  mst_$mst_pages_limit;                   { +0x365A }
  mst_$mst_pages_wired;                   { +0x365C }

var
  unused_365e: integer;                   { +0x365E: 0000, stand-in }
  { +0x3660: prot_rights, mst_$lookup_object's static. }
%elseif large_address_space %then
var
  page_avail_bitmap: array[0..mst_bitmap_last] of mst_page_set_t :=
    [* of [0..31]];                       { +0x0000: ffff x 616 }

define
  mst_$segs_mapped;                       { +0x04D0 }
  mst_$bst_pages;                         { +0x70A8 }
  rars_asid_base;                         { +0x7448 }

var
  page_alloc_hint: pinteger;              { +0x74BC }

define
  mst_$mst_pages_limit;                   { +0x74BE }
  mst_$mst_pages_wired;                   { +0x74C0 }

var
  mst_$rar_pages: array[0..2] of integer; { +0x74C2: zero, read by
                                            nothing }
  { +0x74C8: prot_rights, mst_$lookup_object's static. }
%else
var
  page_avail_bitmap: array[0..mst_bitmap_last] of mst_page_set_t := [
    [0..31], [0..31], [0..31], [0..31],
    [0..31], [0..31], [0..31], [0..31],
    [0..31], [0..31], [0..31], [0..31]];
                                          { +0x00: ffff ffff x 12 }
  page_alloc_hint: pinteger;              { +0x30 }

define
  mst_$mst_pages_limit;                   { +0x32 }
  mst_$mst_pages_wired;                   { +0x34 }

var
  unused_36: integer;                     { +0x36: 0000, stand-in }
  { +0x38: prot_rights, mst_$lookup_object's static (mst/
    lookup_object.pas), placed here after the module's variables. }
%endif

define
  mst_$pre_init;
  mst_$init;
  mst_$diskless_init;
  mst_$map_canned;
  mst_$map_canned_at;
  mst_$alloc_asid;
  mst_$deallocate_asid;
  mst_$maps_at;
  mst_$map_initial_area;
  mst_$map_at;
  mst_$change_rights;
  mst_$grow_area;
  mst_$map;
  mst_$map_top;
  mst_$map_global;
  mst_$maps;
  mst_$remap;
  mst_$remap_privi;
  mst_$map_area;
  mst_$map_area_at;
  mst_$get_uid;
  mst_$get_uid_asid;
  mst_$get_va_info;
  mst_$invalidate;
%if vm_regions %then
  mst_$map_special;
%endif
  mst_$priv_set_touch_ahead_cnt;
  mst_$set_touch_ahead_cnt;
  mst_$unmap;
  mst_$unmap_global;
  mst_$unmaps;
  mst_$unmap_and_free_area;
  mst_$unmaps_and_free_area;
  mst_$unmap_all;
  mst_$set_guard;
  mst_$unmap_privi;
  mst_$get_private_size;
  mst_$wire_area;
  mst_$fork;
  mst_$free_asid;

{ mst_$lookup_object's views and its constant (mst/lookup_object.pas). }
const
  { The object sub-type whose rights mst_$lookup_object does not check,
    on the common attributes' sub_type. }
  mst_lookup_no_check_type = 3;

type
  { The location longword as mst_$lookup_object writes it (its caller's
    mst_location_t, mst/mst_internal.ins.pas, passed as a univ):
    - all, cleared;
    - local, a local object's: the low 31 bits stored in place with bit 31
      kept, a 31-bit packed field's store;
    - net_addr, NETWORK_$INSTALL_NET's `in out' address
      (network/network.ins.pas);
    - bits, bit 31 set;
    - net, a remote object's: the low 20 bits merged, as
      network_$net_addr_t's bits_19_0 (the AST_ callers').
    By ref 3.10.7 (Table 3-3: a subrange field takes the bits its extreme
    values need; one crossing a single 16-bit boundary starts in the next
    free bit) local_t's low31 is bits 30..0 and the record 4 bytes; dpc
    lays a 31-bit field word aligned. }
  mst_lookup_local_t = packed record
    remote: boolean;                      { bit 31 }
    low31: 0..16#7FFFFFFF;                { bits 30..0 }
  end;
  mst_lookup_net_t = packed record
    remote: boolean;                      { bit 31 }
    bits_30_20: 0..16#7FF;                { bits 30..20 }
    low20: 0..16#FFFFF;                   { bits 19..0 }
  end;
  mst_lookup_location_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (bits: set of 0..31);            { 0x00 }
      3: (local: mst_lookup_local_t);     { 0x00 }
      4: (net_addr: network_$net_addr_t); { 0x00 }
      5: (net: mst_lookup_net_t);         { 0x00 }
  end;

  { mst_$set_mstes's protection: an MSTE's 5-bit field
    (mst/mst_internal.ins.pas mst_flags_t's prot), stored unmasked: dpc
    stores a field so from a subrange that fits it and masks the source
    of an integer (a probe). }
  mst_prot_t = 0..31;

  { The protection's bits as mst_$set_mstes tests them with the large
    address space, a word set through a type transfer: member k, bit k
    of the protection, tested in memory. }
  mst_prot_bits_t = set of 0..15;

  { The object-location record (file/file.ins.pas file_$obj_loc_t, 0x20
    bytes) with its byte at +0x1C as a number: mst_$lookup_object reads
    it zero-extended (the rights bits); file/file.ins.pas declares the
    word at +0x1C as a set (its members 8..15).  A view through a type
    transfer. }
  mst_obj_loc_view_t = record
    unused_00: array[0..27] of char;      { 0x00 }
    rights_byte: [byte] 0..255;           { 0x1C }
    flags_byte: [byte] 0..255;            { 0x1D }
    unused_1e: integer;                   { 0x1E }
  end;

{ Two module-local routines of .TEXT that the OS_INIT_PROC routines call
  before their bodies (each called by its absolute address, another
  section).  The headings are their callers' pushes; the bodies (their
  `body:' lines) settle the types. }

{ mst_$set_mstes (module-local, no map symbol): fill the MSTEs of
  segments first .. last of an ASID.  Its callers push nine slots: the
  UID's address (its caller's own `in' UID slot passed on: `in'), then by
  value the object segment, the location longword, the first and last
  segments, the touch count, the ASID, the protection and the wired byte.
  An internal routine: value parameters by value.  The body
  (mst/set_mstes.pas) reads them as the callers push them; start_seg and
  end_seg for the start and end (`end' is reserved), compared unsigned:
  pinteger; prot stored unmasked into the MSTE's 5-bit field (mst_prot_t,
  above). }
{ body: mst/set_mstes.pas }
procedure mst_$set_mstes(in uid: uid_$t; obj_seg: pinteger;
                         location: integer32; start_seg: pinteger;
                         end_seg: pinteger; touch_count: integer;
                         asid: integer; prot: mst_prot_t;
                         wired: boolean);
  forward; internal;

{ mst_$alloc_table_page (module-local, no map symbol): back an MST word
  with a page of MSTEs.  MST_$MAP_CANNED pushes the MST word's address
  and two words and stores the result longword as its status; the body
  reads the ASID and the segment by value, the MST word by address, a
  status result.  The names asid and entry.  The body settles it as it
  stands (mst/alloc_table_page.pas): the ASID tested, the MST word tested
  and written through; the segment word is read only with the large
  address space (its region and BST page). }
{ body: mst/alloc_table_page.pas }
function mst_$alloc_table_page(asid: integer; seg: pinteger;
                               var entry: pinteger): status_$t;
  forward; internal;

{ mst_$alloc_segs (module-local, no map symbol): find room for a mapping
  and fill its MSTEs; the MST_$MAP* wrappers before its body call it.
  Its prologue loads the slots, tests two bytes in place, and writes
  through two slots, the map info and the status: twelve slots, the UID
  by address (`in'), ten values (an internal routine: value parameters by
  value), the map info and the status by address (`out').  The result is
  the mapping's virtual address, a pointer in A0.  Every caller pushes
  the pad and the twelve arguments.  start_va is compared unsigned:
  linteger.  map_info integer32, as MST_$MAP_AT's `out' formal it is
  passed on to.  The body settles the types as they stand
  (mst/alloc_segs.pas, its header). }
{ body: mst/alloc_segs.pas }
function mst_$alloc_segs(addr_hint: integer32; in uid: uid_$t;
                         start_va: linteger; length: integer32;
                         area_size: integer32; asid: integer;
                         prot: integer; touch_count: pinteger;
                         wired: boolean; b_space: boolean;
                         out map_info: integer32;
                         out status: status_$t): univ_ptr;
  forward; internal;

{ mst_$lookup_object (module-local, no map symbol): locate a named
  object for mapping and check its rights.  mst_$alloc_segs pushes the
  status's, the length's and the location's addresses, the area size,
  the protection word and the UID's address.  The prologue copies the
  UID into its frame: an 8-byte value parameter, passed by address and
  copied at entry (an internal routine); it reads the word, and holds
  the slots of the location and the status.  The object length is
  compared unsigned by the caller: linteger.  The body settles the
  modes: the location written through and passed on to
  NETWORK_$INSTALL_NET's `in out' address: `out', univ
  mst_lookup_location_t (above; the caller passes its mst_location_t's
  longword); obj_len stored: `out'. }
{ body: mst/lookup_object.pas }
procedure mst_$lookup_object(uid: uid_$t; prot: integer;
                             area_size: integer32;
                             out location: univ mst_lookup_location_t;
                             out obj_len: linteger;
                             out status: status_$t);
  forward; internal;

{ mst_$va_to_pte (module-local, no map symbol): the MSTE of an address in
  an ASID.  MST_$CHANGE_RIGHTS pushes the ASID and the address by value
  (an internal routine), the protection word, the entry pointer and the
  status by address; the body writes through the last three: `out'.  The
  body settles the types as they stand (mst/va_to_pte.pas): the
  protection stored as a word, the entry as a pointer; the ASID passed on
  to MST_$VA_TO_SEGNO's word, the address to its longword. }
{ body: mst/va_to_pte.pas }
procedure mst_$va_to_pte(asid: integer; va: integer32;
                         out prot: pinteger;
                         out entry: mst_entry_ptr_t;
                         out status: status_$t);
  forward; internal;

%if vm_regions %then
{ mst_$free_region (module-local, no map symbol, PROC2_DELETE_PRO):
  free an active region of an ASID's private segments.  MST_$UNMAP_PRIVI
  calls it before its body; the region, the MST segment group and the
  ASID, words by value (an internal routine). }
{ body: mst/free_region.pas }
procedure mst_$free_region(region: mst_region_t; group: pinteger;
                           asid: integer);
  forward; internal;
%endif

{ The routines, in image order (mst/README.md, the fragment
  table). }

{ ---- OS_INIT_PROC ---- }
%include 'mst/pre_init.pas';              { MST_$PRE_INIT }
%include 'mst/init.pas';                  { MST_$INIT (its nested
                                            mst_init_page,
                                            mst_init_global_page,
                                            first) }
%include 'mst/diskless_init.pas';         { MST_$DISKLESS_INIT }
%include 'mst/map_canned.pas';            { MST_$MAP_CANNED }
%include 'mst/map_canned_at.pas';         { MST_$MAP_CANNED_AT }

{ ---- .TEXT ---- }
%include 'mst/init_table_page.pas';       { mst_$init_table_page }
%include 'mst/alloc_asid.pas';            { MST_$ALLOC_ASID }
%include 'mst/deallocate_asid.pas';       { MST_$DEALLOCATE_ASID }
%include 'mst/maps_at.pas';               { MST_$MAPS_AT }
%include 'mst/map_initial_area.pas';      { MST_$MAP_INITIAL_AREA }
%include 'mst/map_at.pas';                { MST_$MAP_AT }
%include 'mst/change_rights.pas';         { MST_$CHANGE_RIGHTS }
%include 'mst/alloc_segs.pas';            { mst_$alloc_segs (its nested
                                            mst_$audit_map first) }
%include 'mst/grow_area.pas';             { MST_$GROW_AREA }
%include 'mst/map.pas';                   { MST_$MAP }
%include 'mst/map_top.pas';               { MST_$MAP_TOP }
%include 'mst/map_global.pas';            { MST_$MAP_GLOBAL }
%include 'mst/maps.pas';                  { MST_$MAPS }
%include 'mst/remap.pas';                 { MST_$REMAP }
%include 'mst/remap_privi.pas';           { MST_$REMAP_PRIVI }
%include 'mst/map_area.pas';              { MST_$MAP_AREA }
%include 'mst/map_area_at.pas';           { MST_$MAP_AREA_AT }
%include 'mst/lookup_object.pas';         { mst_$lookup_object }
%include 'mst/set_mstes.pas';             { mst_$set_mstes }
%include 'mst/alloc_table_page.pas';      { mst_$alloc_table_page }
%include 'mst/get_uid.pas';               { MST_$GET_UID }
%include 'mst/get_uid_asid.pas';          { MST_$GET_UID_ASID }
%include 'mst/get_va_info.pas';           { MST_$GET_VA_INFO }
%include 'mst/va_to_pte.pas';             { mst_$va_to_pte }
%include 'mst/invalidate.pas';            { MST_$INVALIDATE }
%if vm_regions %then
%include 'mst/map_special.pas';           { MST_$MAP_SPECIAL }
%endif
%include 'mst/priv_set_touch_ahead_cnt.pas';
                                          { MST_$PRIV_SET_TOUCH_AHEAD_CNT }
%include 'mst/set_touch_ahead_cnt.pas';   { MST_$SET_TOUCH_AHEAD_CNT }
%include 'mst/unmap.pas';                 { MST_$UNMAP }
%include 'mst/unmap_global.pas';          { MST_$UNMAP_GLOBAL }
%include 'mst/unmaps.pas';                { MST_$UNMAPS }
%include 'mst/unmap_and_free_area.pas';   { MST_$UNMAP_AND_FREE_AREA }
%include 'mst/unmaps_and_free_area.pas';  { MST_$UNMAPS_AND_FREE_AREA }
%include 'mst/unmap_all.pas';             { MST_$UNMAP_ALL }
%include 'mst/set_guard.pas';             { MST_$SET_GUARD }
%include 'mst/unmap_privi.pas';           { MST_$UNMAP_PRIVI }
%include 'mst/get_private_size.pas';      { MST_$GET_PRIVATE_SIZE }
%include 'mst/wire_area.pas';             { MST_$WIRE_AREA }
{ ---- PROC2_CREATE_PRO ---- }
%include 'mst/fork.pas';                  { MST_$FORK }
{ ---- PROC2_DELETE_PRO ---- }
%include 'mst/unwire_page.pas';           { mst_$unwire_page }
%include 'mst/unwire_asid_pages.pas';     { mst_$unwire_asid_pages }
%if vm_regions %then
%include 'mst/free_region.pas';           { mst_$free_region }
%endif
%include 'mst/free_asid.pas';             { MST_$FREE_ASID }
