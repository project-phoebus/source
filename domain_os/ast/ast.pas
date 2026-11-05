{ ast/ast.pas - the AST_ module, the active segment and active object
  tables: the AOTE and ASTE pools, their hash, activation, page-in and
  write-back, attributes, truncation and invalidation.

  Image addresses:
    sau2  0x00E1DC80  AST_ data (WIRED_DATA, 0x498 bytes)
    sau2  0x00E35000  AST_ data (OS_INIT_DATA, 4 bytes)
    sau4  0x0F81F080  AST_ data (WIRED_DATA, 0x490 bytes)
    sau4  0x0F838400  AST_ data (OS_INIT_DATA, 4 bytes)
    sau6  0x78020080  AST_ data (WIRED_DATA, 0x490 bytes)
    sau6  0x7803F000  AST_ data (OS_INIT_DATA, 4 bytes)
    sau7  0x3C422080  AST_ data (WIRED_DATA, 0x498 bytes)
    sau7  0x3C440400  AST_ data (OS_INIT_DATA, 4 bytes)
    sau8  0x03C1F480  AST_ data (WIRED_DATA, 0x498 bytes)
    sau8  0x03C39400  AST_ data (OS_INIT_DATA, 4 bytes)
    sau9  0x3C420880  AST_ data (WIRED_DATA, 0x498 bytes)
    sau9  0x3C43BC00  AST_ data (OS_INIT_DATA, 4 bytes)

  One compilation unit: the map's AST_ code segments in WIRED_PROC
  (0x6788 bytes, AST_$WAIT_FOR_AST_INTRANS ..
  AST_$REMOVE_CORRUPTED_PAGE) and OS_INIT_PROC (0x3A8 bytes, AST_$INIT,
  AST_$ACTIVATE_AOTE_CANNED, AST_$ACTIVATE_ASTE_CANNED), and its data
  segments in WIRED_DATA (0x498 bytes) and OS_INIT_DATA (4 bytes).

  The tables AST (the ASTEs), AOT (the AOTEs) and AST_PMAPS (a page map
  per ASTE) are the VM_TABLES module's objects, not AST_'s:
  ast/ast.ins.pas declares them `extern'.

  The heading names the code and data sections of the bulk, `module
  ast_, wired_proc, wired_data;' (log/log.pas's form); the block's
  objects are module variables.  The three OS_INIT_PROC routines are
  headed `[section(os_init_proc, os_init_data)]'.

  The 4-byte OS_INIT_DATA block: zero, no map symbol inside, A5 at its
  end in the two _CANNED routines; see the TODO(pascal) below.

  The WIRED_DATA block, 0x498 bytes (zero except the values given; the
  map's names for its symbols):

    +0x000  AOTH (defined)              251 AOTE chain heads
    +0x3EC  ast_$free_aote_head
    +0x3F0  ast_$aote_scan_pos          addr(AOT)
    +0x3F4  ast_$aote_limit             addr(AOT)
    +0x3F8  ast_$free_aste_head
    +0x3FC  ast_$aste_scan_pos          addr(AST)

    +0x400  ast_$aste_limit             addr(AST)
    +0x404  ast_$dism_seqn
    +0x408  ast_$dism_ec                eventcount, its waiter list at
                                        itself
    +0x414  ast_$vol_indices            6 words, volumes 1..6

    +0x420  ast_$vol_info_count         a set of 0..15, the dismounting
                                        volumes (vtoc/search_volumes.pas)
    +0x422  unused_422, a stand-in      6 bytes
    +0x428  AST_$AST_IN_TRANS_EC (def.) eventcount at itself
    +0x434  ast_$aote_seqn

    +0x438  AST_$DISMOUNT_FAILED_PTR .. AST_$ALLOC_TOTAL_AST (defined)
    +0x44C  AST_$PMAP_IN_TRANS_EC (def.) eventcount at itself
    +0x458  AST_$WS_FLT_CNT .. AST_$ASTE_L_CNT (defined)
            (+0x46C AST_$GROW_AHEAD_CNT 8)
    +0x478  AST_$NOT_FOUND (defined)    12 bytes

    +0x484  ast_$update_scan            addr(AOT)
    +0x488  ast_$update_timestamp       16#FFFF
    +0x48A  unused_48a, a stand-in      2 bytes
    +0x48C  ast_$attr_timestamp_mask    [2..4, 12, 13, 19..22, 25]
    +0x490  ast_$clobbered_uid          8 bytes

  Without `memory_parity' the block ends at +0x490 (0x490 bytes): there
  is no ast_$clobbered_uid.

  The routines live in one fragment file each (ast/<name>.pas), in
  image order; ast/README.md has the table.  ZERO_PAGE
  (misc/zero_page.pas), VTOC_$SEARCH_VOLUMES (vtoc/search_volumes.pas)
  and WP_$CALLOC, _CALLOC_LIST, _UNWIRE, _WIRE (wp/*.pas) are WIRED_PROC
  routines of this module with fragments elsewhere.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/ast/ast.pas.  Check: tools/pascal_check.sh.
}
module ast_, wired_proc, wired_data;

{ TODO(pascal) the 4-byte OS_INIT_DATA block and the A5 load into it

  The 4-byte OS_INIT_DATA block is zero, no object of the source that
  this module can name; the two OS_INIT_PROC routines that load A5,
  AST_$ACTIVATE_AOTE_CANNED and AST_$ACTIVATE_ASTE_CANNED (not
  AST_$INIT, which loads none), load its end.  The same open point as
  file/file.pas's and dir/dir.pas's.  Until it is settled the module
  declares nothing for it. }

{ TODO(pascal) the stand-ins of the WIRED_DATA block

  unused_422 (6 bytes, +0x422..+0x427) and unused_48a (2 bytes, +0x48A)
  hold bytes no instruction addresses.  The first is what 8-byte
  alignment of AST_$AST_IN_TRANS_EC (+0x428, 0 mod 8 in the image)
  would leave, a lead which AST_$PMAP_IN_TRANS_EC (+0x44C, 4 mod 8)
  contradicts; the second what longword alignment of the mask
  after a word leaves.  Not settled. }

{ TODO(pascal) AST_'s frames against their locals

  The SAU2 image's frames hold bytes no declared object explains in
  these routines (each fragment's TODO has the offsets):
  ast_$validate_uid 4; ast_$allocate_pages 20 (the register-held count,
  i, seg and p if each keeps a slot), its nested
  ast_$allocate_pages_log 8; AST_$INVALIDATE_PAGE 4 (the `with''s
  register); AST_$ADD_AOTES 20 (add_count, new_size, aote, i, j);
  AST_$ADD_ASTES 24 (add_count, new_size, aste, row_va, i, j);
  ast_$purify_aote 4 (above the 8-aligned attrs); ast_$update_aste 16
  (aote, i; the compiler's three spilled element pointers below), its
  nested ast_$update_aste_log 16 (marked, i); AST_$UPDATE 12
  (aote_count, aste_count, aote, aste); ast_$deactivate_segment 14 (p
  and the held row), its nested ast_$deactivate_segment_log 20 (marked,
  i, the static link); ast_$process_aote 12 (aste, i, prev);
  ast_$lookup_with_hints 16 (tried_local, hint_count, i, the element
  pointer); ast_$allocate_aote 20 (aote, k, sf); AST_$ALLOCATE_ASTE 16
  (aste, k); ast_$lookup_aote_by_uid 12 (i, aote);
  ast_$force_activate_segment 20 (seqn_before, i, aote, existing,
  prev); AST_$MSTE_ACTIVATE_AND_WIRE 12 (aote, aste);
  AST_$ACTIVATE_AND_WIRE 12 (aote, aste, the result);
  ast_$count_valid_pages 12 (p, i, the static link); AST_$TOUCH 46
  (concurrency, avail, entry, ent, out, touched, run, page_no, in_file,
  ppn, p, i); AST_$TOUCH_AREA 44 (besides the compiler's temporaries);
  AST_$COPY_AREA 45 (besides its temporaries).  dpc's frames
  (`--dump-locals'): purify_aote 0x98, update_aste 0x8A,
  deactivate_segment 0xC, deactivate_segment_log 0x10; AST_$UPDATE and
  process_aote 0x10, the image's. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'hint/hint.ins.pas';
%include 'as/as.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'disk/disk.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'bat/bat.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'cal/cal.ins.pas';
%include 'anon/anon.ins.pas';
%include 'acl/acl.ins.pas';
%include 'ast/ast_acl.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'area/area.ins.pas';
%include 'mst/mst.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'pmap/pmap_flush.ins.pas';
%include 'os/os.ins.pas';
%include 'dxm/dxm.ins.pas';                  { DXM_'s insert, for
                                               AST_$SAVE_CLOBBERED_UID's
                                               DXM_$ADD_CALLBACK on
                                               DXM_$UNWIRED_Q }

const
  { The attribute numbers ast_$set_attribute_internal's nested
    ast_$set_attr_dispatch takes, the labels of its `case' (a jump table
    of 28 entries).  FILE_ passes them to
    AST_$SET_ATTRIBUTE and AST_$SET_ATTR (file/set_dirptr.pas's 5,
    file/set_prot_int.pas's 16#14). }
  ast_attr_readonly = 16#00;
  ast_attr_copy_on_write = 16#01;
  ast_attr_dirty = 16#02;
  ast_attr_acl_uid = 16#03;
  ast_attr_creation_time = 16#04;
  ast_attr_dirptr = 16#05;
  ast_attr_add_refcount = 16#06;
  ast_attr_sub_refcount = 16#07;
  ast_attr_set_refcount = 16#08;
  ast_attr_dtm = 16#09;
  ast_attr_dtu = 16#0A;
  ast_attr_blocks = 16#0B;
  ast_attr_os_only = 16#0C;
  ast_attr_access_mode = 16#0D;
  ast_attr_uid_84 = 16#0E;
  ast_attr_uid_8c = 16#0F;
  ast_attr_owner1 = 16#10;
  ast_attr_owner2 = 16#11;
  ast_attr_owner3 = 16#12;
  ast_attr_set_acl_image = 16#13;
  ast_attr_merge_acl = 16#14;
  ast_attr_set_rights = 16#15;
  ast_attr_linkcount = 16#16;
  ast_attr_dtm_rounded = 16#17;
  ast_attr_dtu_rounded = 16#18;
  ast_attr_special_flag = 16#19;
  ast_attr_dtm_from_clock = 16#1A;
  ast_attr_dtu_from_clock = 16#1B;

  { (AST_$GET_SEG_MAP's flags type and member 0, ast_$seg_map_all_pages,
    are ast/ast.ins.pas's.) }

type
  { A pointer to a page number in a caller's list: ast_$allocate_pages
    walks the list with one. }
  ast_$ppn_ptr_t = ^integer32;

  { A clock as its three words: ast_$allocate_pages_log reads the AOTE's
    DTM's second word (the DTM at +0x28; base/base.ins.pas time_$clock_t
    names no word at +2). }
  ast_$clock_words_t = array[1..3] of pinteger;

  { An object cleared as words: AST_$ADD_AOTES and AST_$ADD_ASTES clear
    each new AOTE (0x60 words), ASTE (10 words) and page-map row (0x40
    words) from the first word: a `for' from 1 over words through a
    pointer.  The bound is the largest object's (0x200 words, one
    page). }
  ast_$words_t = array[1..512] of integer;
  ast_$words_ptr_t = ^ast_$words_t;

  { AST_$NOT_FOUND's record, 0xC bytes. }
  ast_$not_found_t = record
    uid: uid_$t;                          { 0x00 }
    flags: integer32;                     { 0x08 }
  end;

  { The AOTE's attribute record as ast_$set_attribute_internal's nested
    ast_$set_attr_dispatch writes it (offsets from the record, the
    AOTE's +0x0C):
    - the two flag bytes at 0x02..0x03 as one 16-bit packed record:
      packed booleans at byte 0x02's bits 4, 3, 2 and byte 0x03's bits
      2, 1, 0 (stored and tested as packed booleans; AST_$GET_ATTRIBUTES
      tests bit 0);
    - the protection block at 0x48 (the AOTE's +0x54, 0x2C bytes), as
      ACL_'s record (copied whole), as its fields (the owners at
      0x00/0x08/0x10, the rights bytes at 0x18..0x1C as byte sets, the
      byte at 0x1D's packed booleans, bits 7..4, the owner extensions at
      0x20), and with the rights 0x18..0x1B as one longword;
    - the clocks at 0x1C (DTM), 0x24 (DTU), 0x2C (DTV), 0x34 (DTA), each
      a longword and a word.
    The byte 0x1C and the packed byte 0x1D form one 16-bit packed record
    (the rights byte a set, `- [4, 5]'), the unpacked rights bytes being
    [byte] sets. }
  ast_$aflags_t = packed record
    unused_15_13: 0..7;                   { bits 15..13 }
    readonly: boolean;                    { bit 12: byte 0x02's bit 4 }
    copy_on_write: boolean;               { bit 11: bit 3 }
    dirty: boolean;                       { bit 10: bit 2 }
    unused_9_8: 0..3;                     { bits 9..8 }
    unused_7_3: 0..31;                    { bits 7..3: byte 0x03 }
    special_flag: boolean;                { bit 2 }
    special: boolean;                     { bit 1 }
    exec: boolean;                        { bit 0 }
  end;
  ast_$rights_tail_t = packed record
    r5: set of 0..7;                      { byte 0x1C }
    os_only: boolean;                     { byte 0x1D's bit 7 }
    mode_6: boolean;                      { bit 6 }
    mode_5: boolean;                      { bit 5 }
    mode_4: boolean;                      { bit 4 }
    unused_3_0: 0..15;                    { bits 3..0 }
  end;
  ast_$prot_view_t = record
    case integer of
      1: (prot: acl_$prot_data_t);        { 0x00 }
      2: (owner1: uid_$t;                 { 0x00 }
          owner2: uid_$t;                 { 0x08 }
          owner3: uid_$t;                 { 0x10 }
          r1: [byte] set of 0..7;         { 0x18 }
          r2: [byte] set of 0..7;         { 0x19 }
          r3: [byte] set of 0..7;         { 0x1A }
          r4: [byte] set of 0..7;         { 0x1B }
          tail: ast_$rights_tail_t;       { 0x1C }
          unused_1e: integer;             { 0x1E }
          owner_ext: array[1..3] of integer32);
                                          { 0x20 }
      3: (unused_00_17: array[16#00..16#17] of char;
                                          { 0x00 }
          rights_w: integer32);           { 0x18 }
  end;
  ast_$set_attr_t = record
    obj_type: ast_$byte_t;                { 0x00 }
    sub_type: ast_$byte_t;                { 0x01 }
    aflags: ast_$aflags_t;                { 0x02 }
    uid: uid_$t;                          { 0x04 }
    dtc: uid_$t;                          { 0x0C }
    length: linteger;                     { 0x14 }
    unused_18: integer32;                 { 0x18 }
    dtm: time_$clock_t;                   { 0x1C }
    unused_22: integer;                   { 0x22 }
    dtu: time_$clock_t;                   { 0x24 }
    unused_2a: integer;                   { 0x2A }
    dtv: time_$clock_t;                   { 0x2C }
    unused_32: integer;                   { 0x32 }
    dta: time_$clock_t;                   { 0x34 }
    unused_3a: integer;                   { 0x3A }
    dirptr: uid_$t;                       { 0x3C }
    blocks: integer32;                    { 0x44 }
    pv: ast_$prot_view_t;                 { 0x48 }
    refcount: pinteger;                   { 0x74 }
    linkcount: integer;                   { 0x76 }
    uid_84: uid_$t;                       { 0x78 }
    uid_8c: uid_$t;                       { 0x80 }
    acl_uid: uid_$t;                      { 0x88 }
  end;

  { The AOTE's attribute record at +0x0C, 0x90 bytes (the first 0x90
    bytes of a VTOCE), seen as each callee that takes it:
    ast_$purify_aote copies it whole (a record assignment), and hands the
    copy to NETWORK_$AST_GET_INFO's `out attrs: network_$attr_rec_t' and
    VTOCE_$WRITE's `in data: vtoce_$t', and reads its clock at +0x24
    (file/file.ins.pas file_$attributes_t's clock_24); ast_$purify_aote
    and ast_$process_aote test bits of its byte +0x03
    (ast_$common_attr_t's attr_flags_lo); AST_$UPDATE tests member 12 of
    its word at +0x02 (attr_set, a word set).
    ast/ast.ins.pas's AOTE cannot hold these views: its includers lack
    network/network.ins.pas and vtoc/vtoc.ins.pas.  fattr is so named
    because `file' is a reserved word. }
  ast_$attr_rec_t = record
    case integer of
      1: (common: ast_$common_attr_t);    { 0x00 }
      2: (fattr: file_$attributes_t);     { 0x00 }
      3: (net: network_$attr_rec_t);      { 0x00 }
      4: (vtoce: vtoce_$t);               { 0x00 }
      5: (unused_00: integer;             { 0x00 }
          attr_set: set of 0..15);        { 0x02 }
      { The twelve bytes at 0x3C as one char array,
        AST_$GET_COMMON_ATTRIBUTES' copy (ast/ast.ins.pas
        ast_$common_attr_t's id12), and the dispatch's view (above). }
      6: (unused_00_3b: array[16#00..16#3B] of char;
                                          { 0x00 }
          id12: ast_$char12_t);           { 0x3C }
      7: (sa: ast_$set_attr_t);           { 0x00 }
  end;
  { AST_$GET_ATTRIBUTES hands its `out attrs' slot to
    NETWORK_$AST_GET_INFO's network_$attr_rec_t through this view. }
  ast_$attr_rec_ptr_t = ^ast_$attr_rec_t;

  { The AOTE's object location at +0x9C, 0x20 bytes, as each callee takes
    it: NETWORK_$AST_GET_INFO's `in out loc: network_$obj_loc_t',
    VTOCE_$WRITE's `in req: vtoc_$lookup_req_t', FM_$WRITE's `in
    file_ref: fm_$file_ref_t'; file/file.ins.pas's file_$obj_loc_t too. }
  ast_$obj_loc_view_t = record
    case integer of
      1: (floc: file_$obj_loc_t);         { 0x00 }
      2: (net: network_$obj_loc_t);       { 0x00 }
      3: (vtoc: vtoc_$lookup_req_t);      { 0x00 }
      4: (fm: fm_$file_ref_t);            { 0x00 }
  end;

  { An object's location longword (bit 31 remote, the volume index or the
    node in the low bits; the AOTE's +0x08), as ast_$lookup_with_hints
    updates the caller's: its bit 31 set with a constant boolean field's
    store, handed to
    NETWORK_$INSTALL_NET's `in out addr: network_$net_addr_t', and the
    hint's node merged unmasked into its low 20 bits (a 20-bit packed
    field stored from a linteger);
    ast_$force_activate_segment reads the longword whole and its high
    word's sign. }
  ast_$loc_word_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (addr: network_$net_addr_t);     { 0x00 }
      3: (bits: packed record
            remote: boolean;              { bit 31 }
            unused_30_20: 0..2047;        { bits 30..20 }
            node: 0..16#FFFFF;            { bits 19..0 }
          end);
      4: (hi: integer;                    { 0x00 }
          lo: pinteger);                  { 0x02 }
  end;

  { An AOTE, 0xC0 bytes, with the two views above in place (hash_next,
    aste_list, location, then the attribute record at +0x0C, the
    location record at +0x9C, the ASTE count at +0xBC, the reference
    count byte at +0xBE and the flag byte at +0xBF): the first view is
    ast/ast.ins.pas's record, the second puts the attribute and location
    views at their offsets and names the reference count byte, which
    AST_$UPDATE and ast_$process_aote test as a number, where
    ast/ast.ins.pas has one word set for the two bytes (its flags, whose
    member 7 is the flag byte's sign).  A third view: the location
    longword at +0x08 whole (the first view's location_hi and
    location_lo), which ast_$force_activate_segment stores whole. }
  ast_$aote_view_t = record
    case integer of
      1: (aote: ast_$aote_t);             { 0x00 }
      2: (unused_00_0b: array[16#00..16#0B] of char;
                                          { 0x00 }
          attrs: ast_$attr_rec_t;         { 0x0C }
          obj_loc: ast_$obj_loc_view_t;   { 0x9C }
          unused_bc: integer;             { 0xBC }
          ref_count: ast_$byte_t);        { 0xBE }
      3: (unused_00_07: array[16#00..16#07] of char;
                                          { 0x00 }
          location: ast_$loc_word_t);     { 0x08 }
      { The location word as AST_$GET_LOCATION hands it back,
        ast/ast.ins.pas ast_$location_t: one longword, a record
        assignment. }
      4: (unused_00_07l: array[16#00..16#07] of char;
                                          { 0x00 }
          loc: ast_$location_t);          { 0x08 }
  end;
  ast_$aote_view_ptr_t = ^ast_$aote_view_t;

  { What ast_$set_attribute_internal takes by value: the attribute
    value's address (AST_$SET_ATTRIBUTE's own slot; the recursion's
    frame record), read through by the dispatch (each arm) as
    file/file.ins.pas file_$attr_value_t's views or as a protection block
    with its ACL UID at 0x2C; and the subject's SID record's address (the
    recursion's nil). }
  ast_$value_view_t = record
    case integer of
      1: (val: file_$attr_value_t);       { 0x00 }
      2: (pv: ast_$prot_view_t;           { 0x00 }
          acl_uid: uid_$t);               { 0x2C }
  end;
  ast_$value_view_ptr_t = ^ast_$value_view_t;
  ast_$exsid_ptr_t = ^acl_$exsid_t;
  { The AOTE's 8 bytes at +0xAC as REM_FILE_$SET_ATTRIBUTE's address
    argument takes them (copied into the frame, then passed), and a
    UID's first byte (tested as a number). }
  ast_$net_info_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (addr: integer32;                { 0x00 }
          node: integer32);               { 0x04 }
  end;
  ast_$uid_byte_view_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (b0: ast_$byte_t);               { 0x00 }
  end;

  { A word seen as a set: ast_$deactivate_segment_log tests member 13 of
    a PFT entry's second word, where mmu/mmu.ins.pas's mmu_$pft_entry_t
    has the word as a pinteger (w_02): a type transfer of the word (ref
    p. 4-197, equal sizes). }
  ast_$word_set_t = set of 0..15;

  { A segment's file-map image as ast_$update_aste builds it in its
    frame, 32 longwords, FM_$WRITE's `in entry_in: fm_$entry_t', and as
    its nested ast_$update_aste_log counts the entries whose bit 31 is
    set, an unsigned compare (linteger elements, an unsigned 4-byte
    subrange). }
  ast_$disk_image_t = record
    case integer of
      1: (fm: fm_$entry_t);               { 0x00 }
      2: (u: array[0..31] of linteger);   { 0x00 }
  end;

  { ast_$lookup_with_hints's hint list, 0x28 bytes: HINT_$GET_HINTS's
    `out addresses: hint_$addr_list_t', and each hint as an 8-byte record
    copied whole into the location record's node address (a record
    assignment, network/network.ins.pas network_$obj_loc_t's node_addr,
    a uid_$t). }
  ast_$hint_list_t = record
    case integer of
      1: (list: hint_$addr_list_t);       { 0x00 }
      2: (addrs: array[1..5] of uid_$t);  { 0x00 }
  end;

  { A run of segment map entries from any entry of a row, indexed from 1
    (ast/ast.ins.pas ast_$pmap_t's elements): ast_$clear_transition_bits
    walks count of them from the address its callers push, a `for' from
    1 whose zero-trip test is the count's own.  The bound is a row's 32. }
  ast_$pmap_run_t = array[1..32] of ast_$pmap_entry_t;

  { An ASTE with its file-map block word seen as FM_'s (fm/fm.ins.pas
    fm_$block_addr_t, the same 4-byte packed record as ast/ast.ins.pas
    ast_$fm_block_t, which that insert's includers cannot name as FM_'s):
    ast_$lookup_or_create_aste passes it to VTOCE_$LOOKUP_FM's `out
    fm_loc', and to FM_$READ by value.  A pointer's view: a type transfer
    of the ASTE variable itself cannot be a `var' actual (dpc's open
    question 46). }
  ast_$aste_view_t = record
    case integer of
      1: (aste: ast_$aste_t);             { 0x00 }
      2: (unused_00_07: array[16#00..16#07] of char;
                                          { 0x00 }
          fm_loc: fm_$block_addr_t);      { 0x08 }
  end;
  ast_$aste_view_ptr_t = ^ast_$aste_view_t;

  { A segment's page-map row (ast/ast.ins.pas ast_pmaps' element, 0x80
    bytes) seen as FM_$READ's `out entry_out: fm_$entry_t' too:
    ast_$lookup_or_create_aste reads the segment's file-map entries
    straight into the row, then rewrites each as a page-map entry. }
  ast_$segmap_view_t = record
    case integer of
      1: (pmap: ast_$pmap_t);             { 0x00 }
      2: (fm: fm_$entry_t);               { 0x00 }
  end;
  ast_$segmap_view_ptr_t = ^ast_$segmap_view_t;

  { A pointer to a page of the I/O window: AST_$COPY_AREA keeps
    AST_$ZERO_BUFF's address in a frame local, and hands it to
    MMU_$INSTALL and OS_$DATA_COPY. }
  ast_$page_ptr_t = ^ast_$page_t;

  { The first 12 bytes of a page request, an object's UID and page
    number, as AST_$COPY_AREA copies them into a disk queue block's
    header byte by byte: a char array assignment. }
  ast_$id12_t = array[1..12] of char;
  ast_$id12_ptr_t = ^ast_$id12_t;


  { A pointer to a UID: AST_$SET_TROUBLE's argument, the slot of a
    pointer to the DXM entry's copy of the UID. }
  ast_uid_ptr_t = ^uid_$t;

  { The AOTE's location longword (+0x08) seen as the fields
    AST_$ACTIVATE_AOTE_CANNED stores for a remote object, each with its
    own instruction: bit 31 set on its byte, bits 25..20 cleared on the
    high word, the node merged into bits 19..0 unmasked.  ast/ast.pas's
    ast_$loc_word_t has bits 30..20 as one field, so the 6-bit field needs
    this view, through a pointer type transfer of the AOTE pointer (ref p.
    4-197). }
  ast_loc_fields_t = packed record
    remote: boolean;                      { bit 31 }
    bits_30_26: 0..31;                    { bits 30..26 }
    bits_25_20: 0..63;                    { bits 25..20 }
    node: 0..16#FFFFF;                    { bits 19..0 }
  end;
  ast_aote_loc_view_t = record
    case integer of
      1: (aote: ast_$aote_t);             { 0x00 }
      2: (unused_00_07: array[16#00..16#07] of char;
                                          { 0x00 }
          loc: ast_loc_fields_t);         { 0x08 }
  end;
  ast_aote_loc_view_ptr_t = ^ast_aote_loc_view_t;

  { A segment-map entry seen as the fields AST_$ACTIVATE_ASTE_CANNED
    stores in each of a fresh ASTE's 32 entries, after clearing members
    13, 15 and 14 of the flags view: bits 28..23 cleared on the high
    word, bit 22 set on the same word, bits 21..0 set.  Bit 22's store is
    the masking form of a constant into a non-boolean field (a boolean's
    `true' would be a bit set on its byte), so it is
    a 0..1 subrange.  A row of 32, as ast_$pmap_t, reached through a
    pointer type transfer of the row's address (ref p. 4-197).  daddr is
    named as in ast/ast.ins.pas's ast_$pmap_dentry_t.  With the region
    registers the flags reach down to bit 25 (member 9): the field
    cleared is bits 24..23. }
%if region_mmu %then
  ast_pmap_entry_bits_t = packed record
    bits_31_25: 0..127;                   { bits 31..25 }
    bits_24_23: 0..3;                     { bits 24..23 }
    bit_22: 0..1;                         { bit 22 }
    daddr: 0..16#3FFFFF;                  { bits 21..0 }
  end;
%else
  ast_pmap_entry_bits_t = packed record
    bits_31_29: 0..7;                     { bits 31..29 }
    bits_28_23: 0..63;                    { bits 28..23 }
    bit_22: 0..1;                         { bit 22 }
    daddr: 0..16#3FFFFF;                  { bits 21..0 }
  end;
%endif
  ast_pmap_row_bits_t = array[0..31] of ast_pmap_entry_bits_t;
  ast_pmap_row_bits_ptr_t = ^ast_pmap_row_bits_t;

  { A UID seen as its first byte: AST_$DISMOUNT tests the AOTE's UID's
    first byte, a byte number widened (ref p. 4-197, a type transfer of
    equal size, 8 bytes). }
  ast_uid_bytes_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (first: ast_$byte_t);            { 0x00 }
  end;

  { The AOTE's remote address pair at +0xAC (ast/ast.ins.pas
    obj_loc_addr, a uid_$t) as AST_$RESERVE and AST_$INVALIDATE copy it
    into the frame and pass the copy to REM_FILE_$RESERVE's and
    _$INVALIDATE's `var addr_info: integer32': an unpacked record whose
    first longword can be passed (uid_$t is packed, and ref 3.10.3
    forbids a packed record's field as a `var' argument). }
  ast_node_addr_t = record
    net: integer32;                       { 0x00 }
    node: integer32;                      { 0x04 }
  end;

  { The AOTE with the pair above at +0xAC (ast/ast.ins.pas's AOTE is not
    edited here): AST_$RESERVE and AST_$INVALIDATE read it through a
    pointer of this type, a type transfer of the AOTE pointer (ref p.
    4-197, equal sizes). }
  ast_aote_addr_view_t = record
    case integer of
      1: (aote: ast_$aote_t);             { 0x00 }
      2: (unused_00_ab: array[16#00..16#AB] of char;
                                          { 0x00 }
          node_addr: ast_node_addr_t);    { 0xAC }
  end;
  ast_aote_addr_view_ptr_t = ^ast_aote_addr_view_t;

{ The globals this module defines in its WIRED_DATA block (map symbols),
  beside the ones ast/ast.ins.pas declares for other modules
  (AST_$WS_FLT_CNT, _PAGE_FLT_CNT, _ALLOC_TOO_FEW_CNT, _ALLOC_CNT,
  _SIZE_AST, _ASTE_AREA_CNT). }
var
  aoth: extern array[0..250] of ast_$aote_ptr_t;
  ast_$ast_in_trans_ec: extern ec_$eventcount_t;
  ast_$dismount_failed_ptr: extern ast_$aote_ptr_t;
  ast_$alloc_worst_aot: extern integer32;
  ast_$alloc_total_aot: extern integer32;
  ast_$alloc_worst_ast: extern integer32;
  ast_$alloc_total_ast: extern integer32;
  ast_$pmap_in_trans_ec: extern ec_$eventcount_t;
  ast_$free_astes: extern integer;
  ast_$free_aotes: extern integer;
  ast_$grow_ahead_cnt: extern integer;
  ast_$size_aot: extern integer;
  ast_$aste_r_cnt: extern integer;
  ast_$aste_l_cnt: extern integer;
  ast_$not_found: extern ast_$not_found_t;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
define
  aoth;                                              { +0x000, zero }

var
  ast_$free_aote_head: ast_$aote_ptr_t;              { +0x3EC, zero }
  ast_$aote_scan_pos: ast_$aote_ptr_t := addr(aot);  { +0x3F0 }
  ast_$aote_limit: ast_$aote_ptr_t := addr(aot);     { +0x3F4 }
  ast_$free_aste_head: ast_$aste_ptr_t;              { +0x3F8, zero }
  ast_$aste_scan_pos: ast_$aste_ptr_t := addr(ast);  { +0x3FC }
  ast_$aste_limit: ast_$aste_ptr_t := addr(ast);     { +0x400 }
  ast_$dism_seqn: integer32;                         { +0x404, zero }
  ast_$dism_ec: ec_$eventcount_t := [
    value := 0,
    waiter_list_head := addr(ast_$dism_ec),
    waiter_list_tail := addr(ast_$dism_ec)];         { +0x408 }
  ast_$vol_indices: array[1..6] of integer;          { +0x414, zero }
  ast_$vol_info_count: set of 0..15;                 { +0x420, zero }
  unused_422: array[1..3] of integer;                { +0x422, zero:
                                                       above }

define
  ast_$ast_in_trans_ec := [
    value := 0,
    waiter_list_head := addr(ast_$ast_in_trans_ec),
    waiter_list_tail := addr(ast_$ast_in_trans_ec)]; { +0x428 }

var
  ast_$aote_seqn: integer32;                         { +0x434, zero }

define
  ast_$dismount_failed_ptr;                          { +0x438, zero }
  ast_$alloc_worst_aot;                              { +0x43C, zero }
  ast_$alloc_total_aot;                              { +0x440, zero }
  ast_$alloc_worst_ast;                              { +0x444, zero }
  ast_$alloc_total_ast;                              { +0x448, zero }
  ast_$pmap_in_trans_ec := [
    value := 0,
    waiter_list_head := addr(ast_$pmap_in_trans_ec),
    waiter_list_tail := addr(ast_$pmap_in_trans_ec)];
                                                     { +0x44C }
  ast_$ws_flt_cnt;                                   { +0x458, zero }
  ast_$page_flt_cnt;                                 { +0x45C, zero }
  ast_$alloc_too_few_cnt;                            { +0x460, zero }
  ast_$alloc_cnt;                                    { +0x464, zero }
  ast_$free_astes;                                   { +0x468, zero }
  ast_$free_aotes;                                   { +0x46A, zero }
  ast_$grow_ahead_cnt := 8;                          { +0x46C }
  ast_$size_aot;                                     { +0x46E, zero }
  ast_$size_ast;                                     { +0x470, zero }
  ast_$aste_area_cnt;                                { +0x472, zero }
  ast_$aste_r_cnt;                                   { +0x474, zero }
  ast_$aste_l_cnt;                                   { +0x476, zero }
  ast_$not_found;                                    { +0x478, zero }

var
  ast_$update_scan: ast_$aote_ptr_t := addr(aot);    { +0x484 }
  ast_$update_timestamp: pinteger := 16#FFFF;        { +0x488 }
  unused_48a: integer;                               { +0x48A, zero:
                                                       above }
  ast_$attr_timestamp_mask: set of 0..31 := [2..4, 12, 13, 19..22, 25];
                                                     { +0x48C }
%if memory_parity %then
  ast_$clobbered_uid: uid_$t;                        { +0x490, zero }
%endif

{ PMAP_$FLUSH's heading and its flags type are pmap/pmap_flush.ins.pas's
  (included above). }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order: every map symbol of AST_'s two code segments, the WP_ routines
  (wp/'s fragments) among them. }
define
  ast_$wait_for_ast_intrans;
  ast_$page_zero;
  ast_$invalidate_page;
  ast_$free_aste;
  ast_$add_aotes;
  ast_$add_astes;
  ast_$get_dism_seqn;
  ast_$update;
  ast_$allocate_aste;
  ast_$load_aote;
  ast_$mste_activate_and_wire;
  ast_$activate_and_wire;
  ast_$touch;
  ast_$touch_area;
  ast_$copy_area;
  ast_$free_pages;
  ast_$fetch_pmap_page;
  ast_$pmap_assoc;
  ast_$assoc;
  ast_$assoc_area;
  ast_$get_location;
  ast_$get_attributes;
  ast_$get_common_attributes;
  ast_$get_acl_attributes;
  ast_$set_attribute;
  ast_$set_attr;
  ast_$get_dtv;
  ast_$set_dts;
  ast_$purify;
  ast_$cond_flush;
  ast_$truncate;
  ast_$invalidate;
  ast_$reserve;
  ast_$dismount;
  ast_$get_seg_map;
  ast_$release_pages;
  ast_$locate_aste;
  wp_$calloc;
  wp_$calloc_list;
  wp_$unwire;
  wp_$wire;
%if pmmu_page_maps %then
  ast_$alloc_contig;
  ast_$remove_page;
%endif
%if pmmu_page_maps or pmap_threads %then
  ast_$assoc_ioppn;
  ast_$remove_ioppn;
%endif
%if memory_parity %then
  ast_$set_trouble;
  ast_$save_clobbered_uid;
%endif
%if pmmu_page_maps %then
  ast_$ptov;
%endif
%if memory_parity %then
  ast_$remove_corrupted_page;
%endif
%if pmap_cache_inhibit %then
  ast_$cache_inhibit_ppn;
  ast_$cache_enable_ppn;
%endif
  ast_$init;
  ast_$activate_aote_canned;
  ast_$activate_aste_canned;

{ ---- WIRED_PROC ---- }
%include 'ast/validate_uid.pas';             { ast_$validate_uid }
%include 'ast/wait_for_page_transition.pas'; { ast_$wait_for_page_transition }
%include 'ast/wait_for_ast_intrans.pas';     { AST_$WAIT_FOR_AST_INTRANS }
%include 'ast/allocate_pages.pas';           { ast_$allocate_pages_log,
                                               ast_$allocate_pages }
%include 'misc/zero_page.pas';               { zero_page }
%include 'ast/page_zero.pas';                { AST_$PAGE_ZERO }
%include 'ast/invalidate_page.pas';          { AST_$INVALIDATE_PAGE }
%include 'ast/release_aote.pas';             { ast_$release_aote }
%include 'ast/free_aste.pas';                { AST_$FREE_ASTE }
%include 'ast/add_aotes.pas';                { AST_$ADD_AOTES }
%include 'ast/add_astes.pas';                { AST_$ADD_ASTES }
%include 'ast/get_dism_seqn.pas';            { AST_$GET_DISM_SEQN }
%include 'ast/purify_aote.pas';              { ast_$purify_aote }
%include 'ast/update_aste.pas';              { ast_$update_aste_log,
                                               ast_$update_aste }
%include 'ast/update.pas';                   { AST_$UPDATE }
%include 'ast/deactivate_segment.pas';       { ast_$deactivate_segment_log,
                                               ast_$deactivate_segment }
%include 'ast/process_aote.pas';             { ast_$process_aote }
%include 'vtoc/search_volumes.pas';          { vtoc_$search_volumes }
%include 'ast/lookup_with_hints.pas';        { ast_$lookup_with_hints }
%include 'ast/allocate_aote.pas';            { ast_$allocate_aote }
%include 'ast/allocate_aste.pas';            { AST_$ALLOCATE_ASTE }
%include 'ast/lookup_aote_by_uid.pas';       { ast_$lookup_aote_by_uid }
%include 'ast/force_activate_segment.pas';   { ast_$force_activate_segment }
%include 'ast/load_aote.pas';                { AST_$LOAD_AOTE }
%include 'ast/lookup_aste.pas';              { ast_$lookup_aste }
%include 'ast/lookup_or_create_aste.pas';    { ast_$lookup_or_create_aste }
%include 'ast/clear_transition_bits.pas';    { ast_$clear_transition_bits }
%include 'ast/setup_page_read.pas';          { ast_$setup_page_read }
%include 'ast/read_area_pages.pas';          { ast_$read_area_pages }
%include 'ast/read_area_pages_network.pas';  { ast_$read_area_pages_net_log,
                                               ast_$read_area_pages_network }
%include 'ast/mste_activate_and_wire.pas';   { AST_$MSTE_ACTIVATE_AND_WIRE }
%include 'ast/activate_and_wire.pas';        { AST_$ACTIVATE_AND_WIRE }
{ (ast_$count_valid_pages is nested in AST_$TOUCH: ast/touch.pas
  includes ast/count_valid_pages.pas.) }
%include 'ast/touch.pas';                    { AST_$TOUCH }
%include 'ast/touch_area.pas';               { AST_$TOUCH_AREA }
%include 'ast/copy_area.pas';                { AST_$COPY_AREA }
{ (ast_$flush_installed_pages is nested in AST_$FREE_PAGES:
  ast/free_pages.pas includes ast/flush_installed_pages.pas.) }
%include 'ast/free_pages.pas';               { AST_$FREE_PAGES }
%include 'ast/fetch_pmap_page.pas';          { AST_$FETCH_PMAP_PAGE }
%include 'ast/pmap_assoc.pas';               { AST_$PMAP_ASSOC }
%include 'ast/assoc.pas';                    { AST_$ASSOC }
%include 'ast/assoc_area.pas';               { AST_$ASSOC_AREA }
%include 'ast/get_location.pas';             { AST_$GET_LOCATION }
%include 'ast/get_attributes.pas';           { AST_$GET_ATTRIBUTES }
%include 'ast/get_common_attributes.pas';    { AST_$GET_COMMON_ATTRIBUTES }
%include 'ast/get_acl_attributes.pas';       { AST_$GET_ACL_ATTRIBUTES }
%include 'ast/set_attribute_internal.pas';   { ast_$set_attr_dispatch,
                                               ast_$set_attribute_internal }
%include 'ast/set_attribute.pas';            { AST_$SET_ATTRIBUTE }
%include 'ast/set_attr.pas';                 { AST_$SET_ATTR }
%include 'ast/get_dtv.pas';                  { AST_$GET_DTV }
%include 'ast/set_dts.pas';                  { AST_$SET_DTS }
%include 'ast/purify.pas';                   { AST_$PURIFY }
%include 'ast/cond_flush.pas';               { AST_$COND_FLUSH }
%include 'ast/truncate.pas';                 { AST_$TRUNCATE }
%include 'ast/invalidate.pas';               { AST_$INVALIDATE }
%include 'ast/reserve.pas';                  { AST_$RESERVE }
%include 'ast/dismount.pas';                 { AST_$DISMOUNT }
%include 'ast/get_seg_map.pas';              { AST_$GET_SEG_MAP }
%include 'ast/release_pages.pas';            { AST_$RELEASE_PAGES }
%include 'ast/locate_aste.pas';              { AST_$LOCATE_ASTE }
%include 'wp/calloc.pas';                    { WP_$CALLOC }
%include 'wp/calloc_list.pas';               { WP_$CALLOC_LIST }
%include 'wp/unwire.pas';                    { WP_$UNWIRE }
%include 'wp/wire.pas';                      { WP_$WIRE }
%if pmmu_page_maps %then
%include 'ast/alloc_contig.pas';             { AST_$ALLOC_CONTIG }
%include 'ast/remove_page.pas';              { AST_$REMOVE_PAGE }
%endif
%if pmmu_page_maps or pmap_threads %then
%include 'ast/assoc_ioppn.pas';              { AST_$ASSOC_IOPPN }
%include 'ast/remove_ioppn.pas';             { AST_$REMOVE_IOPPN }
%endif
%if memory_parity %then
%include 'ast/set_trouble.pas';              { AST_$SET_TROUBLE }
%include 'ast/save_clobbered_uid.pas';       { AST_$SAVE_CLOBBERED_UID }
%endif
%if pmmu_page_maps %then
%include 'ast/ptov.pas';                     { AST_$PTOV }
%endif
%if memory_parity %then
%include 'ast/remove_corrupted_page.pas';    { AST_$REMOVE_CORRUPTED_PAGE }
%endif
%if pmap_cache_inhibit %then
%include 'ast/cache_inhibit_ppn.pas';        { AST_$CACHE_INHIBIT_PPN }
%include 'ast/cache_enable_ppn.pas';         { AST_$CACHE_ENABLE_PPN }
%endif

{ ---- OS_INIT_PROC ---- }
%include 'ast/init.pas';                     { AST_$INIT }
%include 'ast/activate_aote_canned.pas';     { AST_$ACTIVATE_AOTE_CANNED }
%include 'ast/activate_aste_canned.pas';     { AST_$ACTIVATE_ASTE_CANNED }
