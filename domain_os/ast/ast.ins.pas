{ ast/ast.ins.pas - AST_ (active segment table), for the Domain Pascal
  tree.

  Only what the Pascal files use.  No customer insert file declares
  these.  Include base/base.ins.pas and file/file.ins.pas before it.
}

type
  { The 24-byte common attributes.  The byte fields are char where their
    bits are not used by the Pascal files.  attr_flags_lo is a byte set;
    refcount is pinteger (compared unsigned).  The word at 0x16 is also
    a set of 0..15, the third variant. }
  ast_$attr_flags_t = [byte] set of 0..7;
  { The views AST_$GET_COMMON_ATTRIBUTES writes the record through: its
    first four bytes as one longword from the AOTE's attribute record;
    the twelve bytes at 0x08 copied as a char array; two packed booleans
    at bits 7 and 6 of the byte 0x16, and two at bits 1 and 0 of the byte
    0x02.  The two packed
    records are 16 bits each (a 1-byte packed record takes a word), over
    0x02..0x03 and over 0x16..0x17. }
  ast_$char12_t = array[1..12] of char;
  ast_$cattr_hi_t = packed record
    unused_15_10: 0..63;                  { bits 15..10 }
    mode_5: boolean;                      { bit 9: byte 0x02's bit 1 }
    mode_4: boolean;                      { bit 8: byte 0x02's bit 0 }
    unused_7_0: 0..255;                   { bits 7..0: byte 0x03 }
  end;
  ast_$cattr_acc_t = packed record
    os_only: boolean;                     { bit 15: byte 0x16's bit 7 }
    mode_6: boolean;                      { bit 14: byte 0x16's bit 6 }
    unused_13_0: 0..16383;                { bits 13..0 }
  end;
  ast_$common_attr_t = record
    case integer of
      1: (obj_type: char;                 { 0x00 }
          sub_type: char;                 { 0x01 }
          attr_flags_hi: char;            { 0x02 }
          attr_flags_lo: ast_$attr_flags_t;
                                          { 0x03 }
          length: integer32;              { 0x04 }
          dirptr: uid_$t;                 { 0x08 }
          blocks: integer32;              { 0x10 }
          refcount: pinteger;             { 0x14 }
          case integer of
            1: (access_flags: char;       { 0x16 }
                pad_17: char);            { 0x17 }
            2: (access_word: integer);    { 0x16 }
            3: (access_set: set of 0..15));
                                          { 0x16 }
      2: (hdr: integer32;                 { 0x00 }
          unused_04: integer32;           { 0x04 }
          id12: ast_$char12_t;            { 0x08 }
          unused_14: integer;             { 0x14 }
          acc: ast_$cattr_acc_t);         { 0x16 }
      3: (unused_00: integer;             { 0x00 }
          hi: ast_$cattr_hi_t);           { 0x02 }
  end;

{ AST_$GET_COMMON_ATTRIBUTES - the common subset of an object's
  attributes. }
procedure ast_$get_common_attributes(var loc_rec: file_$obj_loc_t;
                                     flags: integer;
                                     out attrs: ast_$common_attr_t;
                                     out status: status_$t);
  options(extern, val_param);

{ AST_$REMOVE_CORRUPTED_PAGE - drop a page frame whose contents are
  suspect. }
function ast_$remove_corrupted_page(ppn: linteger): boolean;
  options(extern, val_param);

{ The active segment and object tables as OSINFO reads them. }
type
  { An active object table entry, 0xC0 bytes, as far as the Pascal files
    read it (every offset the image's, checked with a dpc probe).  The
    fields from 0x9C to 0xB8 are the object's location (file_$obj_loc_t's
    bytes).  loc_flags is the signed byte ast_$sbyte_t (a `set of 0..7'
    would take a word).  The reference count (0xBE) and the flags (0xBF)
    are one word set, flags. }
  { A byte read as an unsigned 8-bit integer (ref 3.15.5;
    mmap/mmap.ins.pas's mmap_$byte_t, which this file cannot name: it
    comes after). }
  ast_$byte_t = [byte] 0..255;

  { The AOTE's location flag byte at 0xB9 (bit 7 remote, bit 6 the
    scratch bit; file/file.ins.pas file_$obj_loc_t's flags, members 7 and
    6): a signed byte, its bit 7 tested as the byte's sign and its low
    four bits read as a number.  Neither a set nor a record can hold the
    byte: either takes a word at least (ref 3.9.3 p. 3-16). }
  ast_$sbyte_t = [byte] -128..127;

  { The AOTE's bytes 0xB8..0xB9 as one 2-byte packed record (the
    `owner_op' form): the volume index, then the location flag byte's
    fields from its top bit (ref 3.10.7, Table 3-3).  The second view of
    the AOTE (below); the first view's vol_index and loc_flags stay for
    their users. }
  ast_$aote_loc_t = packed record
    vol: 0..255;                          { bits 15..8, byte 0xB8 }
    remote: boolean;                      { bit 7 of byte 0xB9 }
    scratch: boolean;                     { bit 6 }
    unused_5_4: 0..3;                     { bits 5..4 }
    pkt_shift: 0..15;                     { bits 3..0 }
  end;

  { The fields below are the record's first view, `case integer of 1:
    (..)'; the second view puts ast_$aote_loc_t over 0xB8..0xB9. }
  ast_$aote_t = record
    case integer of
    1: (
    hash_next: univ_ptr;                  { 0x00 }
    aste_list: univ_ptr;                  { 0x04 }
    location_hi: integer;                 { 0x08 }
    location_lo: pinteger;                { 0x0A }
    obj_type: char;                       { 0x0C }
    sub_type: char;                       { 0x0D }
    attr_flags: pinteger;                 { 0x0E }
    uid: uid_$t;                          { 0x10 }
    dtc: uid_$t;                          { 0x18 }
    length: linteger;                     { 0x20 }
    unknown_24: integer32;                { 0x24 }
    dtm: time_$clock_t;                   { 0x28 }
    unknown_2e: pinteger;                 { 0x2E }
    dtu: time_$clock_t;                   { 0x30 }
    unknown_36: pinteger;                 { 0x36 }
    dtv: time_$clock_t;                   { 0x38 }
    unknown_3e: pinteger;                 { 0x3E }
    dta: time_$clock_t;                   { 0x40 }
    unknown_46: pinteger;                 { 0x46 }
    unused_48: array[16#48..16#9B] of char;
                                          { 0x48..0x9B: not read here }
    unknown_9c: char;                     { 0x9C }
    unknown_9d: ast_$byte_t;              { 0x9D }
    unknown_9e: array[16#9E..16#A3] of char;
                                          { 0x9E..0xA3 }
    obj_loc_uid: uid_$t;                  { 0xA4 }
    obj_loc_addr: uid_$t;                 { 0xAC }
    obj_loc_res_18: integer32;            { 0xB4 }
    vol_index: ast_$byte_t;               { 0xB8 }
    loc_flags: ast_$sbyte_t;              { 0xB9 }
    unknown_ba: pinteger;                 { 0xBA }
    status_flags: pinteger;               { 0xBC }
    flags: set of 0..15);                 { 0xBE }
    2: (unused_00_b7: array[16#00..16#B7] of char;
                                          { 0x00..0xB7 }
        loc: ast_$aote_loc_t);            { 0xB8 }
  end;
  ast_$aote_ptr_t = ^ast_$aote_t;

  { An ASTE's flag word (15 in transition, 14 locked, 13 dirty, 12 area,
    11 remote, 6 busy): a word set.  PMAP_ loads it and tests a member,
    and sets member 13 through an indexed address with the bit number
    unreduced (pmap_$write_complete: the bit number as the addressing
    mode decides). }
  ast_$aste_flags_t = set of 0..15;

  { An active segment table entry, 20 bytes.  The flags word is a word
    set (ast_$aste_flags_t, above), with a second view, flag_bits
    (ast_$aste_flag_bits_t, below), as the record's last part.  fm_block
    is the packed record ast_$fm_block_t (below); wire_count a byte
    number.  A dpc probe: fm_block 0x08, flags and flag_bits 0x12,
    wire_count 0x11. }
  { The flags word seen as its fields, a 2-byte packed record (from bit
    15 down; ref 3.10.7: a packed record's fields run from the most
    significant bit, a boolean takes one bit, Table 3-3): area_$get_aste
    stores a computed boolean into bit 11 with the form of a packed
    boolean field's store, not a set member's (which branches or sets and
    clears the bit).  The constant stores beside it are the same bytes as
    the set's members.  A dpc probe: size 2, `in_trans :=
    false; locked := true' compiled as a bit clear and a bit set on the
    word's high byte. }
  ast_$aste_flag_bits_t = packed record
    in_trans: boolean;                    { bit 15 }
    locked: boolean;                      { bit 14 }
    dirty: boolean;                       { bit 13 }
    area: boolean;                        { bit 12 }
    remote: boolean;                      { bit 11 }
    unused_10_0: 0..2047;                 { bits 10..0 }
  end;

  { An ASTE's file-map block word, a 4-byte packed record (the group's
    page-map block in bits 31..4, the segment's place in its group in
    bits 3..0).  area_$get_aste and AREA_$DEACTIVATE_ASTE store the block
    with the field's masked merge (block := 1 among them), and the group
    with the byte's; the block is read with a shift.  A dpc probe gives
    each of these forms exactly, and the size 4.  all is the whole
    longword (integer32: a 32-bit packed field; linteger would be 31
    bits). }
  ast_$fm_block_t = packed record
    case integer of
      1: (all: integer32);                { bits 31..0 }
      2: (block: 0..16#0FFFFFFF;          { bits 31..4 }
          group: 0..15);                  { bits 3..0 }
  end;

  ast_$aste_ptr_t = ^ast_$aste_t;
%if large_vm %then
  { The 28-byte ASTE: the fields of the 20-byte one, and at 0x0C the
    physical address of the segment's page map (AST_$ADD_ASTES: its
    page's frame times 1024 plus its offset in the page), which the
    MMU's tables point at. }
  { The first link of the thread of MST entries that point at a page map
    (MST_$UNTHREAD_PMAP follows it and ends it): the entry's address
    space and segment, 16#FFFF in the first word for none. }
  ast_$pmap_link_t = record
    asid: integer;                        { 0x00 }
    seg: pinteger;                        { 0x02 }
  end;

  ast_$aste_t = record
    next: ast_$aste_ptr_t;                { 0x00 }
    aote: ast_$aote_ptr_t;                { 0x04 }
    fm_block: ast_$fm_block_t;            { 0x08 }
    pmap_pa: integer32;                   { 0x0C }
    pmap_link: ast_$pmap_link_t;          { 0x10 }
    segment: pinteger;                    { 0x14 }
    seg_index: pinteger;                  { 0x16 }
    page_count: char;                     { 0x18 }
    wire_count: [byte] 0..255;            { 0x19 }
    case integer of
      1: (flags: ast_$aste_flags_t);      { 0x1A }
      2: (flag_bits: ast_$aste_flag_bits_t);
                                          { 0x1A }
  end;
%else
  ast_$aste_t = record
    next: ast_$aste_ptr_t;                { 0x00 }
    aote: ast_$aote_ptr_t;                { 0x04 }
    fm_block: ast_$fm_block_t;            { 0x08 }
    segment: pinteger;                    { 0x0C }
    seg_index: pinteger;                  { 0x0E }
    page_count: char;                     { 0x10 }
    wire_count: [byte] 0..255;            { 0x11 }
    case integer of
      1: (flags: ast_$aste_flags_t);      { 0x12 }
      2: (flag_bits: ast_$aste_flag_bits_t);
                                          { 0x12 }
  end;
%endif

  { One segment's page map in AST_PMAPS, 0x80 bytes: OSINFO_$GET_SEG_TABLE
    copies entries whole, 32 longwords, indexed from 0 by the page's
    offset in its segment: mmap_$trim_wsl and MMAP_$WS_SCAN form
    `AST_PMAPS + segment * 0x80 + seg_offset * 4' and read at -0x80, the
    segment's 1-based bias and no bias for the offset.  Each entry's
    first word is a set (the flags byte and its neighbor), loaded and
    tested, and updated in place (member 13, installed); the second word the
    page number. }
  { The entry as one longword too, the second variant.  The earlier
    fields keep their names and offsets. }
  { The record ast_$pmap_dentry_t (its note is below, beside the row
    types) is declared here, before the entry, whose third view it is:
    ast_$update_aste reads an entry's disk address as the packed
    field.  Outside the page descriptor layout the low 23 bits are a
    field too (ast_$pmap_fentry_t, the fourth view): the SAU6 image
    reads and stores them as one field (AST_$TOUCH, AST_$TRUNCATE and
    the others), and a page's disk address goes back into them as a
    field store.  The value is the MMAP entry's longword taken as a
    linteger: the 68010 images clear the field and OR the longword in
    unmasked, the form of a non-negative value. }
%if pmmu_page_maps %then
  { The entry as an MC68030 page descriptor: an installed page's frame in
    bits 31..10 (the descriptor's page address), a page not installed
    has its disk address in bits 30..10; the low word's flags (below,
    ast_$pmap_in_trans and the others) and the descriptor's own bits
    (resident, used, modified, cache inhibit).  A packed record, so that
    the frame is the field vpn as in the other layout. }
  ast_$pmap_dentry_t = packed record
    bit_31: boolean;                      { bit 31 }
    daddr: 0..16#1FFFFF;                  { bits 30..10 }
    unused_lo: 0..1023;                   { bits 9..0 }
  end;
  ast_$pmap_entry_t = packed record
    case integer of
      1: (frame_hi: pinteger;             { 0x00 }
          flags: set of 0..15);           { 0x02 }
      2: (all: integer32);                { 0x00 }
      3: (dentry: ast_$pmap_dentry_t);    { 0x00 }
      4: (vpn: 0..16#3FFFFF;              { bits 31..10 }
          unused_9_0: 0..1023);           { bits 9..0 }
      5: (unused_00: pinteger;            { 0x00 }
          low: integer);                  { 0x02: odd while the
                                            descriptor is resident }
      7: (hi_flags: set of 0..15);        { 0x00: member 15, no disk
                                            copy (the file map's top
                                            bit) }
      6: (unused_31: boolean;             { bit 31 }
          fm_daddr: 0..16#7FFFFFFF);      { bits 30..0: the disk
                                            address as FM_$READ
                                            leaves it }
  end;
%else
  ast_$pmap_dentry_t = packed record
    unused_hi: 0..1023;                   { bits 31..22 }
    daddr: 0..16#3FFFFF;                  { bits 21..0 }
  end;
  ast_$pmap_fentry_t = packed record
    unused_hi: 0..511;                    { bits 31..23 }
    fm_daddr: 0..16#7FFFFF;               { bits 22..0: the disk address
                                            with bit 22, the flags'
                                            member 6 }
  end;
  ast_$pmap_entry_t = record
    case integer of
      1: (flags: set of 0..15;            { 0x00 }
          vpn: pinteger);                 { 0x02 }
      2: (all: integer32);                { 0x00 }
      3: (dentry: ast_$pmap_dentry_t);    { 0x00 }
      4: (fentry: ast_$pmap_fentry_t);    { 0x00 }
  end;
%endif
  ast_$pmap_t = array[0..31] of ast_$pmap_entry_t;

const
  { A page-map entry's flags (its `flags' set): the page in transition,
    installed (its frame in the entry), and resident (mapped in the MMU;
    in a page descriptor, its type's low bit); a page descriptor's used,
    modified and cache-inhibit bits. }
%if pmmu_page_maps %then
  ast_$pmap_in_trans = 9;
  ast_$pmap_installed = 8;
  ast_$pmap_resident = 0;
  ast_$pmap_used = 3;
  ast_$pmap_modified = 4;
  ast_$pmap_cache_inhibit = 6;
%elseif region_mmu %then
  { With the region registers the first word's bits: resident 15, used
    14, modified 13, in transition 10, installed 9. }
  ast_$pmap_in_trans = 10;
  ast_$pmap_installed = 9;
  ast_$pmap_resident = 15;
  ast_$pmap_used = 14;
  ast_$pmap_modified = 13;
%else
  ast_$pmap_in_trans = 15;
  ast_$pmap_installed = 14;
  ast_$pmap_resident = 13;
%endif

  { The tables' sizes: ASTEs (AST, AST_PMAPS) and AOTEs (AOT). }
%if vm_5760_astes %then
  ast_$max_astes = 5760;
  ast_$max_aotes = 1280;
%elseif vm_1536_astes %then
  ast_$max_astes = 1536;
  ast_$max_aotes = 640;
%elseif vm_2432_astes %then
  ast_$max_astes = 2432;
  ast_$max_aotes = 1280;
%else
  ast_$max_astes = 504;
  ast_$max_aotes = 280;
%endif

type

  { A pointer to a page-map entry: pmap_$fill_write_qblks holds the exact
    address of its page's entry in a frame local, and steps a copy of it
    by one entry. }
  ast_$pmap_entry_ptr_t = ^ast_$pmap_entry_t;

  { A segment map's entry seen as the disk address it holds when the page
    is not installed, the low 22 bits: AREA_$DEACTIVATE_ASTE's hint
    search reads it as the packed field (a dpc probe gives it exactly),
    and a row of 32 of them.  The same row as 32 longwords, as
    area_$get_aste and AREA_$DEACTIVATE_ASTE copy and clear it, and a
    group's page-map block of eight such rows (0x400 bytes, the DBUF page
    they copy a row from and into at the group's place times 0x80).
    (ast_$pmap_dentry_t itself is declared above, before
    ast_$pmap_entry_t.) }
  ast_$pmap_drow_t = array[0..31] of ast_$pmap_dentry_t;
  ast_$pmap_drow_ptr_t = ^ast_$pmap_drow_t;
  ast_$pmap_lrow_t = array[0..31] of integer32;
  ast_$pmap_lrow_ptr_t = ^ast_$pmap_lrow_t;
  ast_$pmap_lblock_t = array[0..7] of ast_$pmap_lrow_t;
  ast_$pmap_lblock_ptr_t = ^ast_$pmap_lblock_t;

var
  { AST (map symbol without `$', in the VM_TABLES data segment): the
    ASTEs, indexed from 1 at the symbol (ASTE `seg' at AST + (seg - 1) *
    0x14; OSINFO_$GET_SEG_TABLE reads entry i at -0x14 from AST + i *
    0x14).  ast_$max_astes entries: the map's AOT follows them (504 of
    20 bytes, 0x2760 bytes, on the SAU2; 5760 of 28 bytes on the
    SAU9). }
  ast: extern array[1..ast_$max_astes] of ast_$aste_t;

  { AOT (map symbol without `$', in the same VM_TABLES segment, after
    AST): the AOTEs, 0xC0 bytes each, ast_$max_aotes of them to the
    segment's end (280 on the SAU2, 1280 on the SAU9)
    (0xD200 bytes).  AST_'s block holds its address in three cells
    (aote_scan_pos, aote_limit, update_scan).  The index base is the
    users' (ast/ast.pas's fragments); 1, as AST's. }
  aot: extern array[1..ast_$max_aotes] of ast_$aote_t;

  { AST_PMAPS (map symbol without `$', the VM_TABLES segment of the
    VM_TABLES section): a page map per ASTE, 0x80 bytes each, indexed
    from 1 (OSINFO_$GET_SEG_TABLE).  ast_$max_astes entries to
    AST_PMAPS_END (on the SAU2 504, 0xFC00
    bytes), one per ASTE. }
  ast_pmaps: extern array[1..ast_$max_astes] of ast_$pmap_t;

  { The AST_ counters OSINFO_$GET_MMAP copies (map symbols of AST_'s
    data segment), longwords read by their absolute addresses:
    integer32.  AST_$SIZE_AST, the number of ASTEs in use, a word
    compared signed with a caller's count (OSINFO_$GET_SEG_TABLE):
    integer. }
  ast_$ws_flt_cnt: extern integer32;
  ast_$page_flt_cnt: extern integer32;
  ast_$alloc_too_few_cnt: extern integer32;
  ast_$alloc_cnt: extern integer32;
  ast_$size_ast: extern integer;

{ AST_$DISMOUNT - deactivate every object on a volume and dismount its
  VTOC. }
procedure ast_$dismount(vol_index: integer; force: boolean;
                        out status: status_$t); options(extern, val_param);


type
  { One 1 KB page as longwords (the conformance unit ast_page_zero.pas's
    type): the zero window's extent, which the AST_ module-local
    ZERO_PAGE clears as 256 longwords (misc/zero_page.pas). }
  ast_$page_t = array[0..255] of integer32;

var
  { AST_$ZERO_BUFF (map symbol, an absolute address in the I/O region, a
    1 KB window): another unit's variable by its address. }
  ast_$zero_buff: extern ast_$page_t;


{ AST_$TRUNCATE - cut an object back to a new length, or delete it. }
procedure ast_$truncate(uid: uid_$t; new_size: integer32; flags: integer;
                        out result: boolean; out status: status_$t);
  options(extern, val_param);


type
  { The location word AST_$GET_LOCATION hands back (the AOTE's location
    at 0x08), as two words, aote_t's location_hi and location_lo
    (above): name_$map_dir tests the high word's sign (bit 31,
    remote). }
  ast_$location_t = record
    location_hi: integer;                 { 0x00 }
    location_lo: pinteger;                { 0x02 }
  end;

{ AST_$GET_LOCATION - an object's location record and its location word. }
procedure ast_$get_location(var loc_rec: file_$obj_loc_t; flags: integer;
                            var unused: integer32;
                            out location: ast_$location_t;
                            out status: status_$t);
  options(extern, val_param);


{ AST_$PURIFY - write an object's modified pages back. }
type
  { AST_$PURIFY's page list: longwords segment << 5 ! page, indexed from
    1, compared unsigned after the shift, linteger (an unsigned 4-byte
    subrange).  The bound is 16,
    dir_$purify_split_pages' page_list[1..16]
    (dir/purify_split_pages.pas); the others pass one entry or the
    literal 0. }
  ast_$purify_list_t = array[1..16] of linteger;

{ The heading checked against the body (ast/purify.pas): page_list is
  `univ ast_$purify_list_t', the list the body indexes; its callers pass
  by address. }
procedure ast_$purify(uid: uid_$t; flags: integer; segment: integer;
                      in page_list: univ ast_$purify_list_t;
                      list_count: integer; out status: status_$t);
  options(extern, val_param);

{ AST_$INVALIDATE_PAGE - drop one installed page from a segment's page
  map. }
procedure ast_$invalidate_page(var aste: ast_$aste_t;
                               var entry: ast_$pmap_entry_t;
                               vpn: integer32);
  options(extern, val_param);

{ AST_$UPDATE - the periodic write-back of dirty segments and attributes. }
procedure ast_$update; extern;


const
  { stcode.db.10.2 "OS / AST manager": 30001 "attempted reference to
    out-of-bounds address", 30005 "write concurrency violation"; 3000C
    "last page partially written" (SR10.4 text, absent from the 10.2
    table).  pmap_$write_page compares the first two and stores the
    third. }
  status_$ast_eof = 16#00030001;
  status_$ast_write_concurrency_violation = 16#00030005;
  status_$ast_last_page_partially_written = 16#0003000C;

{ AST_$SAVE_CLOBBERED_UID - remember a clobbered object and queue its
  trouble mark. }
procedure ast_$save_clobbered_uid(uid: uid_$t); extern;


const
  { stcode.db.10.2 "OS / AST manager" 30004.
    area_$free_slot_segments compares area_$get_aste's status with it:
    no ASTE is active for the segment and none was to be made. }
  status_$ast_segment_not_deactivatable = 16#00030004;

{ AST_$FREE_PAGES - drop a run of pages from a segment. }
procedure ast_$free_pages(var aste: ast_$aste_t; start_page: pinteger;
                          end_page: pinteger; vol_idx: integer);
  options(extern, val_param);

{ AST_$FREE_ASTE - return an ASTE to the free list. }
procedure ast_$free_aste(var aste: ast_$aste_t); extern;


{ AST_$COPY_AREA - copy a segment's pages into another segment of an area. }
procedure ast_$copy_area(partner_index: pinteger; pid: integer;
                         var src_aste: ast_$aste_t;
                         var dst_aste: ast_$aste_t; start_seg: pinteger;
                         buffer: integer32; out status: status_$t);
  options(extern, val_param);


type
  { A list of 32 physical page numbers (one segment's pages), longwords:
    MST_$TOUCH passes AREA_$TOUCH the address of its 128-byte frame list,
    which AREA_$TOUCH hands on to AST_$TOUCH_AREA (below);
    AREA_$REMOVE_SEG builds one in its frame (element k at 4k, 1-based),
    for MMU_$REMOVE_LIST (area/area.ins.pas). }
  ast_$ppn_list_t = array[1..32] of integer32;
  { The same list read as unsigned page numbers: AST_$TOUCH compares its
    first element unsigned (linteger elements, as
    AST_$REMOVE_CORRUPTED_PAGE's ppn). }
  ast_$ppn_ulist_t = array[1..32] of linteger;

{ AST_$TOUCH_AREA - make a page of an area's segment resident. }
procedure ast_$touch_area(area_id: pinteger; seg_index: pinteger;
                          page: pinteger; area_page: linteger;
                          var ppn_array: univ ast_$ppn_list_t;
                          out status: status_$t);
  options(extern, val_param);

{ AST_$ASSOC_AREA - associate a physical page with a page of an area's
  segment. }
procedure ast_$assoc_area(seg_index: pinteger; page: integer; ppn: linteger;
                          out status: status_$t);
  options(extern, val_param);


var
  { AST_$ASTE_AREA_CNT (map symbol, in AST_'s data segment): the number
    of area ASTEs, counted in place by area_$get_aste: a word. }
  ast_$aste_area_cnt: extern integer;

{ AST_$WAIT_FOR_AST_INTRANS - wait for an ASTE in transition. }
procedure ast_$wait_for_ast_intrans; extern;

{ AST_$ALLOCATE_ASTE - take an ASTE: from the free list, else by
  deactivating a segment. }
function ast_$allocate_aste: ast_$aste_ptr_t; extern;


{ AST_$SET_ATTRIBUTE - set one attribute of an object, now. }
procedure ast_$set_attribute(uid: uid_$t; attr_id: integer;
                             in value: file_$attr_value_t;
                             out status: status_$t);
  options(extern, val_param);

{ AST_$SET_ATTR - set one attribute of an object, with the caller's time
  and wait flag. }
procedure ast_$set_attr(uid: uid_$t; attr_id: integer;
                        in value: file_$attr_value_t; flags: boolean;
                        in clock: time_$clock_t; out status: status_$t);
  options(extern, val_param);

{ AST_$GET_ATTRIBUTES - an object's attribute record and location. }
procedure ast_$get_attributes(var loc_rec: file_$obj_loc_t; flags: integer;
                              out attrs: file_$attributes_t;
                              out status: status_$t);
  options(extern, val_param);

{ AST_$LOAD_AOTE - refresh or enter an object's AOTE from a fetched
  attribute record. }
procedure ast_$load_aote(in attrs: file_$attributes_t;
                         in loc: file_$obj_loc_t);
  extern;


const
  { 16#00030006, "incompatible request" (stcode.db.10.2, OS / AST
    manager): FILE_$SET_PROT_INT maps it to FILE_'s
    after AST_$SET_ATTRIBUTE. }
  status_$ast_incompatible_request = 16#00030006;

{ AST_$GET_DISM_SEQN - the dismount sequence number. }
function ast_$get_dism_seqn: integer32; extern;


const
  { 16#00030007, "reference count says unused" (stcode.db.10.2, OS / AST
    manager): file_$delete_int takes it for ok after
    FILE_$SET_ATTRIBUTE. }
  status_$ast_refcount_says_unused = 16#00030007;

{ AST_$COND_FLUSH - deactivate an object whose DTV has changed. }
procedure ast_$cond_flush(uid: uid_$t; in dtm: time_$clock_t;
                          out status: status_$t);
  extern;

{ AST_$GET_DTV - an object's date-time verified clock. }
procedure ast_$get_dtv(uid: uid_$t; location: integer32;
                       out dtv: time_$clock_t; out status: status_$t);
  options(extern, val_param);

{ AST_$SET_DTS - set an object's clocks. }
function ast_$set_dts(flags: integer; uid: uid_$t; in dtv: time_$clock_t;
                      in access_time: time_$clock_t;
                      out status: status_$t): boolean;
  options(extern, val_param);

{ AST_$ACTIVATE_AOTE_CANNED - activate an AOTE from a VTOCE already in
  memory. }
procedure ast_$activate_aote_canned(in vtoce: univ file_$attributes_t;
                                    in loc: univ file_$obj_loc_t);
  extern;

{ AST_$INIT - size and build the AOTE and ASTE pools. }
procedure ast_$init; extern;

{ AST_$ACTIVATE_ASTE_CANNED - activate one segment of an object at boot. }
function ast_$activate_aste_canned(in uid: uid_$t; seg: pinteger):
  ast_$aste_ptr_t;
  options(extern, val_param);

{ AST_$PMAP_ASSOC - associate a physical page with a page of a segment. }
procedure ast_$pmap_assoc(aste: ast_$aste_ptr_t; page: integer;
                          ppn: linteger; flags1: boolean;
                          allow_no_disk: boolean; out status: status_$t);
  options(extern, val_param);

type
  { AST_$GET_SEG_MAP's output, eight longwords of segment bits: the
    callee clears them; FILE_$GET_SEG_MAP tests the first as a set. }
  ast_$seg_map_t = array[0..7] of set of 0..31;
  { AST_$GET_SEG_MAP's flags word, a set: the body tests member 0 in
    place (a word set's member).  Its callers pass
    [] or [0] (FILE_$GET_SEG_MAP; REM_FILE_$SERVER's seg_map_flag
    likewise) or [1] (dir_$open_dir and dir_$alloc_split_page, the word
    2; member 1 is never tested). }
  ast_$seg_map_flags_t = set of 0..15;

const
  { AST_$GET_SEG_MAP's flags member 0: every page counts, installed or
    not: the body skips the MMAP and PFT tests and the not-installed
    page's bit-22 test; REM_FILE_$GET_SEG_MAP's type flag is this
    member. }
  ast_$seg_map_all_pages = 0;

{ AST_$GET_SEG_MAP - build the bitmap of the pages an object has. }
procedure ast_$get_seg_map(in uid: uid_$t; start_offset: linteger;
                           location: integer32; seg_count: linteger;
                           map_size: linteger;
                           flags: ast_$seg_map_flags_t;
                           out output: ast_$seg_map_t;
                           out status: status_$t);
  options(extern, val_param);

{ AST_$INVALIDATE - invalidate a run of an object's pages. }
procedure ast_$invalidate(in uid: uid_$t; start_page: linteger;
                          page_count: integer32; flags: boolean;
                          out status: status_$t);
  options(extern, val_param);

{ AST_$RESERVE - make sure a run of an object's pages has disk blocks. }
procedure ast_$reserve(in uid: uid_$t; start_page: integer32;
                       page_count: integer32; out status: status_$t);
  options(extern, val_param);


{ 16#0003000A, "only local access allowed" (stcode.db.10.2):
  dir_$validate_handle stores it, then its fail bit. }
const
  status_$ast_only_local_access_allowed = 16#0003000A;

{ ---- The two AST_ routines MST_$REMOVE_SEG calls. ---- }

type
  { The segment request AST_$LOCATE_ASTE reads: the object's UID at
    +0x00, compared with an ASTE's object's; the segment number at +0x08,
    compared and pushed; the hint word at +0x0A, whose low bits are
    an ASTE index.  MST_$UNMAP_PRIVI passes an MSTE (16 bytes, the same
    three fields first) through MST_$REMOVE_SEG.  With 28-byte ASTEs
    the hint is the word's low 14 bits, read as a packed field. }
%if large_vm %then
  ast_$hint_t = packed record
    unused_15_14: 0..3;                   { bits 15..14 }
    index: 0..16#3FFF;                    { bits 13..0 }
  end;
  ast_$locate_request_t = record
    uid: uid_$t;                          { 0x00 }
    segment: pinteger;                    { 0x08 }
    hint: ast_$hint_t;                    { 0x0A }
  end;
%else
  ast_$locate_request_t = record
    uid: uid_$t;                          { 0x00 }
    segment: pinteger;                    { 0x08 }
    hint: pinteger;                       { 0x0A }
  end;
%endif

{ AST_$LOCATE_ASTE - find the ASTE of a (uid, segment, hint) request. }
function ast_$locate_aste(in request: ast_$locate_request_t):
  ast_$aste_ptr_t; extern;

{ AST_$RELEASE_PAGES - unwire a segment's pages. }
procedure ast_$release_pages(aste: ast_$aste_ptr_t;
                             return_to_pool: boolean);
  options(extern, val_param);

{ ---- The AST_ routine MST_$TOUCH activates through. ---- }

type
  { An MSTE as AST_ reads it, 16 bytes (hint is
    ast_$locate_request_t's): AST_$MSTE_ACTIVATE_AND_WIRE passes the
    whole on to ast_$lookup_aote_by_uid, and reads the segment word and
    the location longword (ast_$force_activate_segment's location
    argument).  MST's own view of the entry is
    mst/mst_internal.ins.pas mst_entry_t, whose `as_ast' arm is this
    record. }
  ast_$mste_t = record
    uid: uid_$t;                          { 0x00 }
    segment: pinteger;                    { 0x08 }
    hint: pinteger;                       { 0x0A }
    location: integer32;                  { 0x0C }
  end;

{ AST_$MSTE_ACTIVATE_AND_WIRE - activate an MSTE's segment and wire it. }
function ast_$mste_activate_and_wire(in mste: ast_$mste_t;
                                     out status: status_$t):
  ast_$aste_ptr_t; extern;


var
  { AST_$COPY_BUFF (map symbol, beside AST_$ZERO_BUFF: a 1 KB window in
    the I/O region): network_$phys_copy maps its source page there, the
    destination at AST_$ZERO_BUFF; another unit's variable by its address,
    as AST_$ZERO_BUFF. }
  ast_$copy_buff: extern ast_$page_t;

{ AST_$PAGE_ZERO - zero a physical page under the PMAP lock.
  AST_$ACTIVATE_AND_WIRE - activate an object's segment and wire it.
  AST_$ASSOC - associate a physical page with a page of an object.
  AST_$TOUCH - make a run of a segment's pages resident and wire them.
  The page lists are ast_$ppn_list_t; AST_$TOUCH's is ast_$ppn_ulist_t
  (`univ', so its callers' lists pass). }
procedure ast_$page_zero(ppn: integer32); options(extern, val_param);
function ast_$activate_and_wire(in uid: uid_$t; seg: pinteger;
                                out status: status_$t): ast_$aste_ptr_t;
  options(extern, val_param);
procedure ast_$assoc(in uid: uid_$t; seg: pinteger; mode: integer32;
                     page: pinteger; flags: pinteger; ppn: integer32;
                     out status: status_$t);
  options(extern, val_param);
function ast_$touch(var aste: ast_$aste_t; mode: integer32; page: pinteger;
                    count: pinteger; var ppn_array: univ ast_$ppn_ulist_t;
                    out status: status_$t; flags: pinteger): pinteger;
  options(extern, val_param);

{ AST_$ADD_AOTES - grow the AOTE pool.
  AST_$ADD_ASTES - grow the ASTE pool. }
function ast_$add_aotes(in count: integer; out status_ret: status_$t):
  integer; extern;
function ast_$add_astes(in count: integer; out status_ret: status_$t):
  integer; extern;

{ AST_$CACHE_INHIBIT_PPN, AST_$CACHE_ENABLE_PPN (map symbols of the SAU7
  and SAU9 AST_ code): stop and resume caching a physical page.  The page
  number by value (`val_param'); the SAU9's SCSI driver calls them. }
procedure ast_$cache_inhibit_ppn(ppn: integer32);
  options(extern, val_param);
procedure ast_$cache_enable_ppn(ppn: integer32);
  options(extern, val_param);

%if pmmu_page_maps %then
{ The page-descriptor layout's AST_ routines (map symbols of the SAU7..SAU9
  AST_ code).  All take their arguments by value (`val_param'), records
  and out parameters by address.
  AST_$ALLOC_CONTIG - allocate a run of contiguous physical pages.
  AST_$REMOVE_PAGE - take a page out of its segment's page map.
  AST_$ASSOC_IOPPN - map an I/O page at a page of a segment.
  AST_$REMOVE_IOPPN - unmap a segment's I/O page.
  AST_$PTOV - the virtual address that maps a physical page.
  AST_$ALLOC_CONTIG's pages go to a list by address (the SAU9's RING_8025
  passes six longwords), handed on to MMAP_$ALLOC_CONTIG: `univ', as
  ast_$ppn_list_t (this file comes before mmap/mmap.ins.pas, whose
  mmap_$vpn_list_t MMAP_$ALLOC_CONTIG takes). }
procedure ast_$alloc_contig(n: integer; out ppns: univ ast_$ppn_list_t;
                            out status: status_$t);
  options(extern, val_param);
procedure ast_$remove_page(ppn: integer32); options(extern, val_param);
%endif
%if pmmu_page_maps or pmap_threads %then
{ AST_$ASSOC_IOPPN and AST_$REMOVE_IOPPN are also map symbols of the
  SAU4 and SAU6 AST_ code, with the page maps' thread. }
procedure ast_$assoc_ioppn(var aste: ast_$aste_t; page: integer;
                           ppn: integer32);
  options(extern, val_param);
procedure ast_$remove_ioppn(var aste: ast_$aste_t; page: integer);
  options(extern, val_param);
%endif
%if pmmu_page_maps %then
function ast_$ptov(ppn: integer32; out asid: integer; out va: integer32):
  boolean; options(extern, val_param);
%endif
