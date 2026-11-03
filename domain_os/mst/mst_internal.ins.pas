{ mst/mst_internal.ins.pas - the MST modules' data, locks and the
  headings only MST calls, for the Domain Pascal tree.

  The objects of MST_WIRED's block that mst/mst.ins.pas does not
  declare, with the map's names.  AREA_ (area/area.pas) includes it as
  well, for the forward tables of the large VM layout.  Include
  base/base.ins.pas,
  file/file.ins.pas, ml/ml.ins.pas, ast/ast.ins.pas, area/area.ins.pas
  and mst/mst.ins.pas before it.
}

const
  { The last ASID: MST_ASID_BASE holds 58 words (the map's sizes); ASIDs
    are compared unsigned with 57 (MST_$GET_PRIVATE_SIZE,
    MST_$GET_VA_INFO). }
  mst_max_asid = 57;

  { No ASID: one past the last.  MST_$VA_TO_SEGNO returns it
    for the gap between global A and global B, and its callers pass it as
    the default ASID (OS_$INSTALL_DISPLAY_ASTE). }
  mst_asid_none = mst_max_asid + 1;

  { Private B's size in segments, and with the constant regions
    (mst/mst.ins.pas) the segment numbers' end. }
%if large_address_space %then
  mst_private_b_count = 128;
  mst_$seg_mem_top = 32768;
  { An address space's private segments, private A and private B. }
  mst_$seg_tn = 30464;
%elseif run_time_layout %then
  mst_private_b_count = 64;
%else
  mst_private_b_count = 8;
%endif

type
  { MST_ASID_BASE's entries, indexed by ASID from 0: MST_$TOUCH reads the
    current ASID's, the base of the ASID's run of MST words. }
  mst_asid_base_t = array[0..mst_max_asid] of pinteger;

  { A region of an address space, and a set of them
    (MST_$REGIONS_ACTIVE): 256 regions, or with the layout chosen at
    boot 128 (the PMMU layout's).  The image tests a region's member
    unguarded, so the region's type is the set's base type. }
%if run_time_layout %then
  mst_region_t = 0..127;
%else
  mst_region_t = 0..255;
%endif
  mst_region_set_t = set of mst_region_t;

  { An ASID's BST pages (MST_$BST_PAGES, 16 bytes, or with the layout
    chosen at boot a longword). }
%if run_time_layout %then
  mst_bst_page_set_t = set of 0..31;
%else
  mst_bst_page_set_t = set of 0..127;
%endif

%if vm_regions %then
const
  { The segments of a region, the members of MST_$REGIONS_ACTIVE's sets
    (MST_$SET's and MST_$SET_CLEAR's size), and the groups of an ASID's
    MST segments MST_$SEGS_MAPPED counts: 238 words per ASID, or with
    the layout chosen at boot 116, the PMMU layout's 7424 segments. }
%if run_time_layout %then
  mst_region_segs = 64;
  mst_region_members = 128;
  mst_seg_groups = 116;
%else
  mst_region_segs = 128;
  mst_region_members = 256;
  mst_seg_groups = mst_$seg_tn div mst_region_segs;
%endif

  { The special segments (MST_$MAP_SPECIAL): the top 16 of private B,
    segments mst_$seg_global_b - 16 .. mst_$seg_global_b - 1. }
  mst_special_segs = 16;

  { mst_$alloc_segs's window for a private B-space mapping: the top 8
    segments of private B, MST segments mst_$seg_tn - 8 .. mst_$seg_tn
    - 1 (on the SAU2 the whole of private B, from private A's size).
    The window's first segment is this many into private B. }
  mst_b_space_segs = 8;
  mst_b_space_first = mst_private_b_count - mst_b_space_segs;

  { NETLOG_$LOG_IT's kind for a region made active (its fifth argument
    1) or freed (-1), with the region or the group as the sixth. }
  mst_region_netlog_kind = 16#0E;

  { status_$mst_invalid_segment_count, 16#00040010 ("invalid segment
    count", stcode.db.10.2): MST_$UNMAP_PRIVI's crash when a group's
    count of mapped segments is already zero. }
  status_$mst_invalid_segment_count = 16#00040010;
%endif

%if large_address_space %then
const

  { The regions every address space has active: global A (237, 238)
    and global B (240..255), the constant set MST_$INIT and
    MST_$ALLOC_ASID read from their code. }
  mst_global_regions = [mst_$seg_global_a div mst_region_segs ..
                        (mst_$seg_global_a + mst_$global_a_size)
                          div mst_region_segs - 1,
                        mst_$seg_global_b div mst_region_segs ..
                        mst_$seg_mem_top div mst_region_segs - 1];

  { The private regions, private A (0..236) and private B (239): an
    ASID's MST segment groups 0..236 are regions 0..236, group 237
    region 239 (MST_$FREE_ASID's constant set). }
  mst_private_a_regions = mst_$private_a_size div mst_region_segs;
  mst_private_regions = [0 .. mst_private_a_regions - 1,
                         mst_$seg_private_b div mst_region_segs ..
                         (mst_$seg_private_b + mst_private_b_count)
                           div mst_region_segs - 1];

  { The regions between private A's and private B's, global A's: a
    group from mst_private_a_regions on is the region this many above. }
  mst_global_a_regions = mst_$global_a_size div mst_region_segs;

  { MST_$UNMAP_PRIVI's first segment refused without
    mst_unmap_any_seg, and MST_$INVALIDATE's bound: the last 8 below
    global B (private B's 8 segments on the SAU2; with the large
    address space only the top 8 of its 128). }
  mst_unmap_privi_first_refused = mst_$seg_global_b - 8;
%endif

var
  { The objects of MST_WIRED's block that mst/mst.ins.pas does not
    declare, in block order (mst/mst_wired.pas gives the layout and the
    initial values).  The names are the map's (MST_ASID_BASE has no `$'
    and is still a map symbol, so a global).  The types are the ones the
    routines show.  mst_$got_color is a boolean: its one reference is
    MST_$DISKLESS_INIT's byte store of its boolean parameter. }
  mst_$diskless_msg: extern array[1..128] of char;
  mst_$asid_list: extern set of 0..63;
  mst_$map_alter_lock: extern ml_$exclusion_t;
  mst_$asid_allocate_lock: extern ml_$exclusion_t;
  mst_$asid_lock: extern ml_$exclusion_t;
  mst_asid_base: extern mst_asid_base_t;
  mst_$touch_count: extern pinteger;
%if not large_address_space %then
  mst_$seg_mem_top: extern pinteger;
%endif
%if not large_address_space %then
  mst_$seg_tn: extern pinteger;
%endif
%if not large_address_space %then
  mst_$seg_high: extern pinteger;
  mst_$seg_global_b_offset: extern pinteger;
  mst_$seg_private_b_offset: extern pinteger;
  mst_$seg_private_b_end: extern pinteger;
  mst_$seg_private_a_end: extern pinteger;
  mst_$seg_global_a_end: extern pinteger;
%endif
  mst_$got_color: extern boolean;
%if run_time_layout %then
  { The layout's other words in MST_WIRED's block (map symbols), set by
    MST_$PRE_INIT with the segment words: SPECIAL_$SEG, the special
    segments' first address (the top 16 of private B), and the regions
    of 64 segments, the REGION_$ words: an address space's private
    regions (private A's, then private B's one), private A's, global A's
    first and count, global B's first and count, private B's, and all
    of them.  An ASID's private region k is region k up to private A's
    count, region k + (REGION_$PRIVATE_B - REGION_$PRIVATE_A_SIZE)
    after. }
  special_$seg: extern integer32;
  region_$private_tn: extern pinteger;
  region_$private_a_size: extern pinteger;
  region_$global_a: extern pinteger;
  region_$global_a_size: extern pinteger;
  region_$global_b: extern pinteger;
  region_$global_b_size: extern pinteger;
  region_$private_b: extern pinteger;
  region_$tn: extern pinteger;
%endif

%if large_address_space %then
const
  { The rest of the segment layout, constants with the large address
    space (the map has no MST_$SEG_* variables).  MST_$MAP_CANNED and
    mst_$alloc_segs compile them as immediates: global B's offset in the
    MST words 30464 (global B less global A's size), the canned
    mappings' top 32744 (2280 above that offset), private B's offset 256
    (global A's size), the last segments of private A 30335 and of
    global A 30591.  Private B's last, 30719, no routine reads. }
  mst_$seg_global_b_offset = 30464;
  mst_$seg_high = 32744;
  mst_$seg_private_b_offset = 256;
  mst_$seg_private_b_end = 30719;
  mst_$seg_private_a_end = 30335;
  mst_$seg_global_a_end = 30591;
%endif

%if large_vm %then
type
  { The forward tables of the large VM layout.  An address space's
    segment map entry (SMAPS, 8 bytes, per ASID from SMAP_ASID_BASE), an
    MC68030 long-format table descriptor that points at the segment's
    page map: the limit (31, 32 entries) in the first word, a word set
    of flags (members 15..10 all set, 9 cleared, 2 write protect) whose
    low two bits are the descriptor type (2 valid, 0 invalid), and the
    page map's physical address with the low four bits kept (member 0
    of the second longword's set tested by MST_$TOUCH). }
  mst_smap_lim_t = packed record
    lu: boolean;                          { bit 15 }
    limit: 0..16#7FFF;                    { bits 14..0 }
  end;
  mst_smap_ctl_t = packed record
    bits_15_2: 0..16#3FFF;                { bits 15..2 }
    dt: 0..3;                             { bits 1..0 }
  end;
  mst_smap_t = record
    case integer of
      1: (lim: mst_smap_lim_t;            { 0x00 }
          flags: set of 0..15;            { 0x02 }
          table: integer32);              { 0x04 }
      2: (unused_00: integer;             { 0x00 }
          ctl: mst_smap_ctl_t;            { 0x02 }
          table_bits: set of 0..31);      { 0x04 }
  end;

  { A root entry of RARS, an MC68030 short-format table descriptor that
    points at a region's page of segment map entries: stored whole (the
    page's address plus the type, mst_rars_valid), and the type cleared
    in place (the low word's two low bits). }
  mst_rars_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (unused_00: integer;             { 0x00 }
          ctl: mst_smap_ctl_t);           { 0x02 }
  end;

const
  { The descriptor types MST_ stores: in the segment map entries, and in
    the root entries (valid: 8-byte descriptors follow). }
  mst_smap_invalid = 0;
  mst_smap_valid = 2;
  mst_rars_valid = 3;

var
  { SMAPS and BST (map symbols without `$', OS_PMAPS and VM_TABLES):
    the segment map entries, and for each the next link of its page
    map's thread (ast/ast.ins.pas ast_$pmap_link_t), 1767936 of each,
    indexed by an ASID's base plus the segment.  With the layout chosen
    at boot the maps give 96512 entries and 103936 links, 58 ASIDs of
    the default layout's 1664 segments rounded up to a page. }
%if run_time_layout %then
  smaps: extern array[0..96511] of mst_smap_t;
  bst: extern array[0..103935] of mst_$pmap_link_t;
%else
  smaps: extern array[0..1767935] of mst_smap_t;
  bst: extern array[0..1767935] of mst_$pmap_link_t;
%endif
  { BST_ASID_BASE and SMAP_ASID_BASE (map symbols of MST_WIRED's
    block): each ASID's first index into BST and SMAPS. }
  bst_asid_base: extern array[0..mst_max_asid] of integer32;
  smap_asid_base: extern array[0..mst_max_asid] of integer32;
  { MST_$REGIONS_ACTIVE (map symbol of MST_WIRED's block): 32 bytes per
    ASID (16 with the layout chosen at boot), a set of the address
    space's regions (member k segments k*128 .. k*128+127, or of 64).
    MST_$INIT fills ASID 0's with the global regions and copies it to
    ASID 1's; MST_$ALLOC_ASID adds the global regions; set operations. }
  mst_$regions_active: extern array[0..mst_max_asid] of mst_region_set_t;
%endif
%if vm_regions %then
  { RARS_ASID_BASE (map symbol of MST_UNWIRED's .DATA block;
    mst/mst_unwired.pas defines it): each ASID's first index into RARS,
    256 apart (REGION_$TN with the layout chosen at boot; MST_$PRE_INIT),
    words read zero-extended. }
  rars_asid_base: extern array[0..mst_max_asid] of pinteger;
  { MST_$SEGS_MAPPED (map symbol): for each ASID a count of the mapped
    segments in each region-sized group of its MST segments (private A
    then private B), words (MST_$INIT clears them, MST_$UNMAP_PRIVI
    counts down and crashes on zero). }
  mst_$segs_mapped: extern array[0..mst_max_asid] of
                      array[0..mst_seg_groups - 1] of pinteger;
  { MST_$BST_PAGES (map symbol): for each ASID the set of its BST pages
    installed (MST_$INIT installs ASID 0's first ones). }
  mst_$bst_pages: extern array[0..mst_max_asid] of mst_bst_page_set_t;
  { RARS (map symbol without `$' at SMAPS_END, VM_TABLES): each ASID's
    root entries from its RARS_ASID_BASE, one per region; MST_$INIT
    and MST_$ALLOC_ASID copy ASID 0's to a new ASID's. }
  rars: extern array[0..(mst_max_asid + 1) * mst_region_members - 1] of
          mst_rars_t;
%endif
%if run_time_layout %then
  { MST_$RAR_PAGES (map symbol of MST_UNWIRED's .DATA block): the pages
    of RARS installed, member k the page k pages from RARS's start
    (MST_$INIT sets page 0 alone, MST_$ALLOC_ASID adds a new ASID's). }
  mst_$rar_pages: extern set of 0..31;
%endif

  { MST_$MST_PAGES_WIRED (map symbol in MST_UNWIRED's .DATA block, +0x34;
    mst/mst_unwired.pas defines it): a word. }
  mst_$mst_pages_wired: extern pinteger;

{ MST_$REMOVE_SEG - release an object segment's pages from the AST. }
procedure mst_$remove_seg(in request: univ ast_$locate_request_t;
                          va: integer32; seg: pinteger; segno: pinteger;
                          return_to_pool: boolean);
  options(extern, val_param);

{ ---- The segment table entry, the tables that hold the entries, and
  what MST_$TOUCH needs. ---- }

const
  { NETLOG_$LOG_IT's kind for a touch (MST_$TOUCH). }
  mst_touch_netlog_kind = 16#16;

  { The flag word MST_$TOUCH builds for AST_$TOUCH: 16#20 for a global
    segment (asid 0), 16#1 for an active entry with protection bit 2, 16#8
    when protection bit 0 is clear. }
  mst_touch_ast_cow = 16#01;
  mst_touch_ast_read_only = 16#08;
  mst_touch_ast_global = 16#20;

type
  { The first byte of an entry's UID, zero-extended to test it
    (MST_$TOUCH): a [byte] subrange (proc2's proc2_uid_byte_t form; a dpc
    probe gives the image's code for `first_byte <> 0'). }
  mst_byte_t = [byte] 0..255;

  { An entry's flag word at +0x0A: bit 15 active, 14 modified (the guard
    bit MST_$TOUCH clears), 13..9 the protection, 8..0 the index of the
    cached ASTE.  The image reaches it three ways, each view's own code (a
    dpc probe):
    - the set, `bits': a member tested in a register, cleared in memory;
      member 15 tested in memory;
    - the fields, `active' .. `aste_idx': the index read and stored with
      the unmasked merge, the protection read;
    - the bits of the protection as booleans, tested in memory.
    A packed record's fields run from the top bit (ref 3.10.7).
    copy_on_write and writable name protection bits 2 and 0 (not
    verified). }
%if large_vm %then
  { With the large VM layout the protection is the segment map entry's
    (mst_$set_mstes stores it there, mst_$va_to_pte reads it back), and
    the cached ASTE's index takes bits 13..0. }
  mst_flags_t = packed record
    case integer of
      1: (bits: set of 0..15);
      2: (active: boolean;                { bit 15 }
          modified: boolean;              { bit 14 }
          aste_idx: 0..16#3FFF);          { bits 13..0 }
  end;
%else
  mst_flags_t = packed record
    case integer of
      1: (bits: set of 0..15);
      2: (active: boolean;                { bit 15 }
          modified: boolean;              { bit 14 }
          prot: 0..31;                    { bits 13..9 }
          aste_idx: 0..511);              { bits 8..0 }
      3: (bit_15: boolean;
          bit_14: boolean;
          prot_bit_4: boolean;            { bit 13 }
          prot_bit_3: boolean;            { bit 12 }
          copy_on_write: boolean;         { bit 11 }
          prot_bit_1: boolean;            { bit 10 }
          writable: boolean;              { bit 9 }
          bits_8_0: 0..511);
  end;
%endif

  { An entry's byte at +0x0C: bits 6..2 are one less than the number of
    pages MST_$TOUCH asks for, the read of a 5-bit packed field (a dpc
    probe).  A one-byte packed record takes two bytes in an unpacked one:
    +0x0C..+0x0D. }
  mst_page_info_t = packed record
    bit_7: boolean;
    n_pages_m1: 0..31;                    { bits 6..2 }
    bits_1_0: 0..3;
  end;

  { A segment table entry, 16 bytes: the object's UID, its segment (area)
    number, the flag word, the page byte.  Other views of the same bytes:
    - first_byte, the UID's first byte (mst_byte_t, above);
    - handle, the UID's second longword as an area handle: an anonymous
      segment's entry keeps AREA_'s handle there, and MST_$TOUCH passes
      its address to AREA_$TOUCH's `var';
    - as_ast, the entry as AST_ reads it (ast/ast.ins.pas ast_$mste_t):
      MST_$TOUCH passes the entry to AST_$MSTE_ACTIVATE_AND_WIRE;
    - location, the longword at +0x0C (the page byte and the word after
      it): mst_$set_mstes stores it whole, before the page byte's field.
    A dpc probe: flags 0x0A, page_info 0x0C, size 0x10. }
  mst_entry_t = record
    case integer of
      1: (uid: uid_$t;
          area_id: pinteger;
          flags: mst_flags_t;
          page_info: mst_page_info_t;
          unused_0e: integer);
      2: (first_byte: mst_byte_t);
      3: (uid_high: integer32;
          handle: area_$handle_t);
      4: (as_ast: ast_$mste_t);
      5: (unused_00: array[0..11] of char;
          location: integer32);
  end;

  { A page of entries, 64 of them (0x400 bytes): an MST word names the
    page, the segment's low six bits its entry. }
  mst_page_t = array[0..63] of mst_entry_t;

var
  { MST (map symbol without `$', in VM_TABLES): the MST words, 3072
    bytes, indexed from 0: each a page number of MSTE_PAGES, 0 for none
    (MST_$TOUCH). }
%if mst_7168_words %then
  mst: extern array[0..7167] of pinteger;
%elseif large_vm %then
  mst: extern array[0..27647] of pinteger;
%else
  mst: extern array[0..1535] of pinteger;
%endif

  { MSTE_PAGES (map symbol without `$', in VM_TABLES): the pages of
    entries, numbered from 1 (page 0 is the one below the base): MST_$TOUCH
    forms the page's address and reaches the entry's fields 0x400 below
    it, the 1-based element's bias.  358 pages, to the end of
    VM_TABLES. }
%if large_vm %then
  mste_pages: extern array[1..9600] of mst_page_t;
%else
  mste_pages: extern array[1..358] of mst_page_t;
%endif

{ AST_$TOUCH's heading is ast/ast.ins.pas's; this insert's includers
  include that one. }

{ ---- For MST_UNWIRED's OS_INIT_PROC routines.  MST_$GOT_COLOR is a
  boolean (above); the byte after it in MST_WIRED's block is a stand-in
  (mst/mst_wired.pas). ---- }

{ (status_$mst_no_space_available, 16#40003, is mst/mst.ins.pas's.) }

type
  { A set of up to 64 members as MST_$SET takes it (MST_$ASID_LIST's
    size; member N in bit N & 7 of byte ((size - 1) | 15 - N) div 8). }
  mst_set64_t = set of 0..63;

{ MST_$SET (hand assembly: map segment MST_ASM, no frame;
  mst/m68k/set.s): add a member to a set given its address and its
  declared member count, reading three slots off SP.  MST_$ALLOC_ASID
  pushes the set by address (written) and the two words by value:
  `val_param'. }
procedure mst_$set(var bitmap: univ mst_set64_t; size: pinteger;
                   bit_index: pinteger);
  options(extern, val_param);

{ ---- For MST_$CHANGE_RIGHTS. ---- }

type
  { A pointer to an entry, as mst_$va_to_pte returns it through its
    fourth slot (MST_$CHANGE_RIGHTS reads it back). }
  mst_entry_ptr_t = ^mst_entry_t;

{ ---- For mst_$alloc_segs. ---- }

type
  { A mapping's location longword, as mst_$alloc_segs holds it in its
    frame: mst_$lookup_object writes it through its fourth slot,
    mst_$set_mstes takes it by value, and an anonymous area's path clears
    its bit 31 alone, which dpc compiles from the set view's `bits - [31]'
    (a probe). }
  mst_location_t = record
    case integer of
      1: (all: integer32);
      2: (bits: set of 0..31);
  end;

  { An anonymous object's UID as mst_$alloc_segs reads it: the high
    longword compared with ANON_$UID's, the low longword copied whole as
    the area handle, whose words are then read as the area id and the
    generation: a view of uid_$t (8 bytes), read through a type
    transfer. }
  mst_anon_uid_t = record
    high: integer32;
    handle: area_$handle_t;
  end;

{ ---- For MST_$REMAP_PRIVI and the MST_$MAP_AREA routines. ---- }

const
  { MST_$REMAP_PRIVI's flags word, member 0 (privileged): tested in
    memory, the form dpc gives for `in' on a word set in memory (a
    probe).  DIR_$MAP_PAGE passes 1 (dir/map_page.pas), MST_$REMAP 0 (a
    constant cell). }
  mst_remap_privileged = 0;

type
  { The flags word as MST_$REMAP_PRIVI reads it: a word set, reached from
    the heading's `in integer' through a type transfer
    (mst/remap_privi.pas). }
  mst_remap_flags_t = set of 0..15;

{ ---- For MST_$FREE_ASID. ---- }

{ MST_$SET_CLEAR (hand assembly: map segment MST_ASM, no frame;
  mst/m68k/set.s): MST_$SET's twin, a bit cleared for its set, the same
  three slots read off SP.  MST_$FREE_ASID pushes MST_$ASID_LIST by
  address and the two words by value: `val_param', as MST_$SET. }
procedure mst_$set_clear(var bitmap: univ mst_set64_t; size: pinteger;
                         bit_index: pinteger);
  options(extern, val_param);
