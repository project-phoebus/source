{ vtoc/vtoc.ins.pas - VTOC_ (the volume table of contents) types,
  constants, variables and routine headings, for the Domain Pascal tree.

  The module is vtoc/vtoc.pas (`module vtoc_'); FM_$READ and FM_$WRITE
  (fm/) and OS_DISK_PROC (os/disk_proc.pas) are routines of it.  No
  customer insert file of the SR10.2 install declares any of this; the
  layouts are the image's.  Include base/base.ins.pas and fm/fm.ins.pas
  before it.
}

const
  { The statuses VTOC_ stores (stcode.db.10.2, "OS / VTOC manager";
    status_$vtoc_is_bad made from the text "VTOC is bad"): FM_$READ
    stores the first, VTOC_$LOOKUP, VTOC_$GET_UID, VTOC_$ALLOCATE,
    VTOCE_$READ and VTOCE_$LOOKUP_FM the others, and "VTOC is bad" with
    the fail bit VTOC_$MOUNT, VTOC_$ALLOCATE, vtoc_$hash_uid and
    VTOCE_$TRUNCATE: written negative, 16#80020002 is not an integer32
    (bat/bat.ins.pas's bat_$error). }
  status_$vtoc_not_mounted = 16#00020001;
  status_$vtoc_no_file_map = 16#00020003;
  status_$vtoc_no_uid = 16#00020004;
  status_$vtoc_not_found = 16#00020005;
  status_$vtoc_invalid_vtoce = 16#00020006;
  status_$vtoc_duplicate_uid = 16#00020007;
  status_$vtoc_uid_mismatch = 16#00020008;
  status_$vtoc_is_bad = -16#7FFDFFFE;

  { The magic number of a bucket block, which VTOC_$ALLOCATE stores.
    Written negative. }
  vtoc_bkt_block_magic = -16#0123567B;

type
  { One byte of a record, an unsigned 8-bit integer (fm/fm.ins.pas
    fm_$byte_t, ref 3.15.5). }
  vtoc_$byte_t = [byte] 0..255;

  { The first longword of a VTOCE, the same in both formats: a packed
    record (ref 3.10.7, fields from the most significant bit).  The
    converters store and read its fields one by one, and copy and clear
    it whole (variant `all'); VTOCE_$READ sets bit 1 and VTOCE_$WRITE
    clears it; the in-use bit is set, tested and cleared as the boolean
    at bit 15 (VTOC_$ALLOCATE, VTOCE_$TRUNCATE).  Bits 9 and 8 and the
    low byte are the old format's (moved to ext by the converters); bit
    1 is the new entry's read-only bit (VTOCE_$READ sets it from the
    volume's write-protect flag). }
  vtoce_$hdr_t = packed record
    case integer of
      1: (all: integer32);
      2: (type_mode: vtoc_$byte_t;        { byte 0 }
          flags: vtoc_$byte_t;            { byte 1 }
          in_use: boolean;                { bit 15 }
          mode_14_13: 0..3;               { bits 14..13 }
          bit_12: boolean;
          bit_11: boolean;
          bit_10: boolean;
          bit_9: boolean;                 { old format }
          bit_8: boolean;                 { old format }
          low_byte: vtoc_$byte_t);        { byte 3, old format }
      3: (unused_b0: vtoc_$byte_t;
          unused_b1: vtoc_$byte_t;
          unused_b2: vtoc_$byte_t;
          unused_7_2: 0..63;
          read_only: boolean;             { bit 1, new format }
          unused_0: boolean);
  end;

  { The 16 bytes at +0x04 of a VTOCE: the object's UID, which
    VTOCE_$READ compares with the request's, and which the converters
    copy as 16 bytes.  A variant record (a variant part ends a record,
    so its own type). }
  vtoce_$id_t = record
    case integer of
      1: (uid: uid_$t;                    { 0x00 }
          unused_08: array[1..8] of char);   { 0x08 }
      2: (bytes: array[1..16] of char);   { 0x00 }
  end;

  { A UID whose low longword is also a set, and whose high longword's
    low word is read alone.  VTOCE_$OLD_TO_NEW sets member 24 of the
    parent's low longword after copying it; VTOCE_$NEW_TO_OLD sets
    member 27, or removes 24..27 (a longword set's members 24..31 in its
    first byte).  The UID cache hashes the high longword's low word. }
  vtoc_$uid_view_t = record
    case integer of
      1: (uid: uid_$t);
      2: (high_hi: pinteger;              { 0x00 }
          high_lo: pinteger;              { 0x02 }
          low_bits: set of 0..31);        { 0x04 }
  end;

  { The two lengths at +0x3C (new) and +0x2C (old), copied as one 8-byte
    record by the converters. }
  vtoce_$lengths_t = record
    current_length: integer32;            { 0x00 }
    blocks_used: integer32;               { 0x04 }
  end;

  { The word at +0x64 of a new VTOCE: a byte and four booleans and a
    nibble.  VTOCE_$OLD_TO_NEW stores bits 7, 5 and 4 of its second
    byte; VTOCE_$NEW_TO_OLD reads bit 7. }
  vtoce_$ext_t = packed record
    acl_flags: vtoc_$byte_t;              { byte 0x64 }
    ext_7: boolean;                       { 0x65 bit 7: old bit 9 }
    ext_6: boolean;
    ext_5: boolean;                       { 0x65 bit 5: old bit 8 }
    ext_4: boolean;                       { 0x65 bit 4: old bit 8 }
    ext_3_0: 0..15;
  end;

  { A VTOCE as the VTOCE routines hand it to their callers, the new
    format's first 0x90 bytes (VTOCE_$READ, VTOCE_$WRITE and
    VTOC_$ALLOCATE move 36 longwords; FILE_ and AST_ callers pass a
    frame record of that size).  The fields are the ones the image
    addresses (the converters, VTOC_$ALLOCATE):
    - dtm, 8 bytes copied whole from the old entry's +0x1C;
    - dtu, a clock assembled from the old +0x28 longword and +0x34 word
      and copied whole to dtc and dta (6-byte record copies);
    - unused_24, a longword copied from the old +0x24;
    - acl_mode, four bytes set to 16#10, 16#10, 16#10 and 0;
    - unknown_68, 12 bytes copied from a constant in the code;
    - link_count, compared unsigned (VTOCE_$NEW_TO_OLD): pinteger;
    - parent_uid, the UID at +0x88 (FILE_$PRIV_CREATE fills it).
    And as 36 longwords: VTOCE_$OLD_TO_NEW clears the 31 from +0x14 in
    a `for' loop over the variant `longs'. }
  vtoce_$t = record
    case integer of
      1: (hdr: vtoce_$hdr_t;              { 0x00 }
          id: vtoce_$id_t;                { 0x04 }
          dtm: uid_$t;                    { 0x14 }
          dtu: time_$clock_t;             { 0x1C }
          unused_22: pinteger;            { 0x22 }
          unused_24: integer32;           { 0x24 }
          eof_block: integer32;           { 0x28 }
          dtc: time_$clock_t;             { 0x2C }
          unused_32: pinteger;            { 0x32 }
          dta: time_$clock_t;             { 0x34 }
          unused_3a: pinteger;            { 0x3A }
          lengths: vtoce_$lengths_t;      { 0x3C }
          acl_checksum: integer32;        { 0x44 }
          owner_uid: uid_$t;              { 0x48 }
          group_uid: uid_$t;              { 0x50 }
          org_uid: uid_$t;                { 0x58 }
          acl_mode: array[1..4] of vtoc_$byte_t;   { 0x60 }
          ext: vtoce_$ext_t;              { 0x64 }
          reserved_66: pinteger;          { 0x66 }
          unknown_68: array[1..3] of integer32;   { 0x68 }
          link_count: pinteger;           { 0x74 }
          reserved_76: array[1..18] of char;  { 0x76 }
          parent_uid: vtoc_$uid_view_t);  { 0x88 }
      2: (longs: array[0..35] of integer32);   { 0x00 }
  end;

  { The three indirect roots of a VTOCE's file map, and a pointer to
    them: VTOCE_$LOOKUP_FM holds their address (+0xCC new, +0xC4 old)
    and passes one root by address. }
  vtoc_$fm_roots_t = array[1..3] of integer32;
  vtoc_$fm_roots_ptr_t = ^vtoc_$fm_roots_t;

  { An old-format VTOCE, 0xCC bytes, five to a VTOC block (the file-map
    view, vtoce_$old_fm_t): the header and UID as the new one's;
    parent_uid at +0x14 (VTOCE_$NEW_TO_OLD stores the UID or the parent
    there); dtm at +0x1C (to the new dtm); the longword at +0x24 and the
    word at +0x34 and longword at +0x28 (to the new unused_24 and dtu);
    lengths; link_count at +0x36, one less than the new count; dtu at
    +0x38 (to the new acl_checksum); +0x3C cleared by VTOCE_$NEW_TO_OLD.
    From +0x40 the file map: the 32 direct block addresses, then the
    three indirect roots at +0xC0 (FM_$READ, VTOCE_$TRUNCATE), also seen
    as 35 longwords cleared by VTOC_$ALLOCATE.  Names as vtoce_$t's. }
  vtoce_$old_fm_t = record
    hdr: vtoce_$hdr_t;                    { 0x00 }
    id: vtoce_$id_t;                      { 0x04 }
    parent_uid: vtoc_$uid_view_t;         { 0x14 }
    dtm: uid_$t;                          { 0x1C }
    unknown_24: integer32;                { 0x24 }
    unknown_28: time_$clockh_t;           { 0x28 }
    lengths: vtoce_$lengths_t;            { 0x2C }
    unknown_34: pinteger;                 { 0x34 }
    link_count: pinteger;                 { 0x36 }
    dtu: integer32;                       { 0x38 }
    reserved_3c: integer32;               { 0x3C }
    case integer of
      1: (direct: fm_$entry_t;            { 0x40 }
          indirect: vtoc_$fm_roots_t);    { 0xC0 }
      2: (fm_longs: array[1..35] of integer32);  { 0x40 }
  end;

  { A new-format VTOCE as it lies in its block, 0x150 bytes, three to a
    block (the file-map view, vtoce_$new_fm_t): the 0x90 bytes the
    callers see (VTOCE_$READ copies them), then the file map's three
    indirect roots at +0xC4 and the 32 direct addresses at +0xD0
    (FM_$READ, VTOCE_$TRUNCATE).  VTOC_$ALLOCATE clears it from +0x40 to
    its end as longwords: the variant `longs'. }
  vtoce_$new_fm_t = record
    case integer of
      1: (core: vtoce_$t;                 { 0x00 }
          reserved_90: array[1..52] of char;     { 0x90 }
          indirect: vtoc_$fm_roots_t;     { 0xC4 }
          direct: fm_$entry_t);           { 0xD0 }
      2: (longs: array[0..83] of integer32);   { 0x00 }
  end;

  { The two formats of VTOC block, in their file-map views (a 4-byte
    chain word and five old VTOCEs from 0x04, 0x400 bytes; an 8-byte
    header and three new VTOCEs from 0x08, 0x3F8 bytes).  FM_$READ
    reaches entry i's direct addresses at 0x04 + 0x40 (old), at 0x08 +
    0xD0 (new) from the entry's offset: the entries indexed from 0, the
    record's displacement folded in.  VTOC_$ALLOCATE reads the chain
    word and tests the entries' in-use bits; BAT_$ALLOC_VTOCE counts the
    entries (bat/alloc_vtoce.pas). }
  vtoc_$old_block_t = record
    next_block: integer32;                { 0x000 }
    entries: array[0..4] of vtoce_$old_fm_t;   { 0x004 }
  end;
  vtoc_$vtoce_block_t = record
    next_block: integer32;                { 0x000 }
    entry_count: pinteger;                { 0x004 }
    reserved_06: pinteger;                { 0x006 }
    entries: array[0..2] of vtoce_$new_fm_t;   { 0x008 }
  end;

  { A bucket slot, 12 bytes, and a bucket, 0xF8 bytes, of the new
    format's hash table: VTOC_$ALLOCATE tests a slot's location,
    compares its UID, steps by 12 from the bucket's slots, reads the
    bucket's next block and index; a bucket's address is its index times
    0xF8.  The location is the packed block and entry of fm/fm.ins.pas
    (fm_$block_addr_t), stored and tested whole (variant `all'). }
  vtoc_$bucket_slot_t = record
    uid: uid_$t;                          { 0x00 }
    block_info: fm_$block_addr_t;         { 0x08 }
  end;
  vtoc_$bucket_t = record
    next_bucket: integer32;               { 0x00 }
    next_bkt_idx: pinteger;               { 0x04 }
    reserved_06: pinteger;                { 0x06 }
    slots: array[0..19] of vtoc_$bucket_slot_t;   { 0x08 }
  end;

  { A bucket block, 0x400 bytes: four buckets, then the magic number and
    the block's own number in its last two longwords, which
    VTOC_$ALLOCATE stores after clearing 254 longwords. }
  vtoc_$bkt_block_t = record
    buckets: array[0..3] of vtoc_$bucket_t;   { 0x000 }
    reserved_3e0: array[1..24] of char;       { 0x3E0 }
    magic: integer32;                     { 0x3F8 }
    self_block: integer32;                { 0x3FC }
  end;

  { A disk buffer as FM_$READ and FM_$WRITE read it (the 1024 bytes
    DBUF_$GET_BLOCK returns): a file-map block, eight entries from 0
    (FM_$READ zero-extends the entry's index, times 0x80), or a VTOC
    block of either format, or a bucket block (VTOC_), or 256 longwords
    (VTOC_$ALLOCATE's clearing of a new old-format block).  Variants of
    one buffer (ref 3.10.3); eight file-map entries to a block. }
  fm_$buffer_t = record
    case integer of
      1: (fm_block: array[0..7] of fm_$entry_t);
      2: (old_vtoc: vtoc_$old_block_t);
      3: (new_vtoc: vtoc_$vtoce_block_t);
      4: (bkt_block: vtoc_$bkt_block_t);
      5: (longs: array[0..255] of integer32);
  end;
  fm_$buffer_ptr_t = ^fm_$buffer_t;

  { One partition of a volume's VTOC: count blocks from base (6 bytes):
    vtoc_$hash_uid and VTOC_$GET_UID compare the count unsigned and add
    the base to the index, stepping by 6.  Fields word aligned (the
    record 6 bytes). }
  vtoc_$vol_part_t = record
    count: pinteger;                      { 0x00 }
    base: integer32;                      { 0x02 }
  end;

  { A volume's VTOC record, 100 bytes, copied from and to the volume
    label's +0x4C as 25 longwords (VTOC_$MOUNT, VTOC_$DISMOUNT;
    bat/bat.ins.pas bat_$label_t's vtoc_header):
    - hash_type, compared unsigned (vtoc_$hash_uid), and hash_size, the
      divisor: pinteger;
    - blocks_added, counted by VTOC_$ALLOCATE;
    - name_dir1 and name_dir2, current_vtoce: VTOCE locations, tested
      and moved whole (VTOC_$GET_NAME_DIRS), their block and entry read
      as the packed fields (VTOC_$GET_UID): fm_$block_addr_t;
    - parts, ten partitions (VTOC_$GET_UID walks ten on a new-format
      volume, eight on an old one);
    - cur_bkt_block and cur_bkt_idx, the bucket block being filled and
      its next bucket (VTOC_$ALLOCATE). }
  vtoc_$vol_t = record
    hash_type: pinteger;                  { 0x00 }
    hash_size: pinteger;                  { 0x02 }
    blocks_added: integer32;              { 0x04 }
    name_dir1: fm_$block_addr_t;          { 0x08 }
    name_dir2: fm_$block_addr_t;          { 0x0C }
    current_vtoce: fm_$block_addr_t;      { 0x10 }
    reserved_14: integer32;               { 0x14 }
    parts: array[0..9] of vtoc_$vol_part_t;   { 0x18 }
    cur_bkt_block: integer32;             { 0x54 }
    cur_bkt_idx: pinteger;                { 0x58 }
    reserved_5a: array[1..10] of char;    { 0x5A }
  end;

  { VTOC_$MOUNT's mount word, a packed record of 16 bits (fields from
    the most significant bit): VOLX_$MOUNT builds it in its frame from
    the device, bus, controller and logical-volume numbers and pushes it
    as a word.  The names are the values volx/mount.pas puts there.
    VTOC_$MOUNT keeps it per volume and copies it into each request it
    rewrites (below). }
  vtoc_$mount_loc_t = packed record
    dev: 0..31;                           { bits 0..4 }
    bus: 0..7;                            { bits 5..7 }
    ctlr: 0..15;                          { bits 8..11 }
    lv_num: 0..15;                        { bits 12..15 }
  end;

  { The first and last longwords of a VTOCE location request (below),
    packed records with a whole-longword variant.  VTOC_$LOOKUP's (and
    VTOC_$ALLOCATE's, VTOCE_$READ's) rewrite of the request on success
    clears both whole, stores the volume's mount word into hdr's low
    word, the volume index into tail's first byte, sets tail's bit 6
    and both kind nibbles to 1.  file/file.ins.pas file_$obj_loc_t names
    bits 7 and 6 of 0x1D remote and scratch. }
  vtoc_$req_hdr_t = packed record
    case integer of
      1: (all: integer32);
      2: (byte_0: vtoc_$byte_t;           { byte 0 }
          flags_hi: 0..15;                { byte 1 bits 7..4 }
          kind: 0..15;                    { byte 1 bits 3..0 }
          mount_loc: vtoc_$mount_loc_t);  { bytes 2..3 }
  end;
  vtoc_$req_tail_t = packed record
    case integer of
      1: (all: integer32);
      2: (vol_idx: vtoc_$byte_t;          { byte 0x1C }
          remote: boolean;                { 0x1D bit 7 }
          scratch: boolean;               { 0x1D bit 6 }
          bits_5_4: 0..3;
          kind: 0..15;                    { 0x1D bits 3..0 }
          reserved_1e: pinteger);         { 0x1E }
  end;

  { A VTOCE location request, 0x20 bytes: the location, the block number
    and entry index packed as fm/fm.ins.pas's fm_$block_addr_t
    (VTOCE_$LOOKUP_FM reads them, VTOC_$LOOKUP merges them), the UID at
    +0x08, the port and node at +0x10 and +0x14 (ROUTE_$PORT's first
    longword and NODE_$ME), the volume index in the tail.  The same 32
    bytes as file/file.ins.pas's file_$obj_loc_t and fm/fm.ins.pas's
    fm_$file_ref_t (the AOTE's location); the tree keeps the three
    types. }
  vtoc_$lookup_req_t = record
    hdr: vtoc_$req_hdr_t;                 { 0x00 }
    block_hint: fm_$block_addr_t;         { 0x04 }
    uid: uid_$t;                          { 0x08 }
    port: integer32;                      { 0x10 }
    node: integer32;                      { 0x14 }
    reserved_18: integer32;               { 0x18 }
    tail: vtoc_$req_tail_t;               { 0x1C }
  end;

  { The records VTOC_$MOUNT and VTOC_$DISMOUNT pass AUDIT_$LOG_EVENT,
    16#32 bytes and 16#30 (the lengths are constants in their code): the
    volume's name, 32 bytes from the label's +0x04 and four zero bytes,
    the volume's UID from the label's +0x24, then VTOC_$MOUNT's mount
    word, volume index and write-protect flag, VTOC_$DISMOUNT's index
    and force flag. }
  vtoc_$mount_audit_t = record
    name: array[1..36] of char;           { 0x00 }
    uid: uid_$t;                          { 0x24 }
    loc: vtoc_$mount_loc_t;               { 0x2C }
    vol_idx: integer;                     { 0x2E }
    write_prot: boolean;                  { 0x30 }
  end;
  vtoc_$dismount_audit_t = record
    name: array[1..36] of char;           { 0x00 }
    uid: uid_$t;                          { 0x24 }
    vol_idx: integer;                     { 0x2C }
    force: boolean;                       { 0x2E }
  end;

  { An entry and a bucket of VTOC_'s UID cache, VTOC_CACHE (vtoc/vtoc.pas,
    101 buckets of four entries): the UID compared; the location stored
    and returned whole; the volume (0 an invalid entry) tested; the age
    compared unsigned: pinteger.  OS_DISK_PROC clears an entry's volume
    and sets its age to 16#FFFF. }
  vtoc_$uid_cache_entry_t = record
    uid: uid_$t;                          { 0x00 }
    block_info: fm_$block_addr_t;         { 0x08 }
    vol: integer;                         { 0x0C }
    age: pinteger;                        { 0x0E }
  end;
  vtoc_$uid_cache_entry_ptr_t = ^vtoc_$uid_cache_entry_t;
  vtoc_$uid_cache_bucket_t = record
    entries: array[0..3] of vtoc_$uid_cache_entry_t;   { 0x00..0x3F }
  end;

var
  { VTOC_$UID (map symbol, in the map's UID_LIST segment, a table of
    well-known UIDs): the VTOC blocks' UID.  FM_$READ copies it;
    another unit's variable. }
  vtoc_$uid: extern uid_$t;

  { VTOC_BKT_$UID (map symbol, UID_LIST): the bucket blocks' UID,
    passed to DBUF_$GET_BLOCK by its address. }
  vtoc_bkt_$uid: extern uid_$t;

  { VTOC_CACH_HITS and VTOC_CACH_LOOKUPS (map symbols, +0x268 and +0x26C
    of VTOC_'s block, `define'd in vtoc/vtoc.pas): VTOC_$LOOKUP's
    counts.  Global names without `$'. }
  vtoc_cach_hits: extern integer32;
  vtoc_cach_lookups: extern integer32;

{ Routine headings, in map order: VTOCE_$OLD_TO_NEW (the map's VTOC_
  WIRED_PROC segment), then (the .TEXT segment) OS_DISK_PROC
  (os/os.ins.pas), VTOCE_$NEW_TO_OLD .. VTOCE_$TRUNCATE, FM_$READ and
  FM_$WRITE (fm/fm.ins.pas).  Every routine is compiled and global; the
  three UID-cache routines and the two nested ones have no map symbols
  (vtoc/README.md).  The bodies repeat the full heading (ref
  7.3.4, Method 2). }

{ VTOCE_$OLD_TO_NEW - convert an old-format VTOCE into the new format. }
procedure vtoce_$old_to_new(in old_vtoce: univ vtoce_$old_fm_t;
                            out new_vtoce: univ vtoce_$t); extern;

{ VTOCE_$NEW_TO_OLD - convert a new-format VTOCE into the old format. }
procedure vtoce_$new_to_old(in new_vtoce: univ vtoce_$t; in flags: boolean;
                            out old_vtoce: univ vtoce_$old_fm_t); extern;

{ VTOC_$MOUNT - mount a volume's VTOC.
  VTOC_$DISMOUNT - dismount a volume's VTOC. }
procedure vtoc_$mount(vol_idx: integer; loc: vtoc_$mount_loc_t;
                      salvage_ok: boolean; write_prot: boolean;
                      out status: status_$t); options(extern, val_param);
procedure vtoc_$dismount(vol_idx: integer; force: boolean;
                         out status: status_$t); options(extern, val_param);

{ VTOC_$ALLOCATE - allocate a VTOCE for a new object. }
procedure vtoc_$allocate(in out loc: vtoc_$lookup_req_t;
                         in out new_vtoce: vtoce_$t;
                         out status: status_$t); extern;

{ VTOC_$LOOKUP - find the VTOCE of a UID. }
procedure vtoc_$lookup(in out req: vtoc_$lookup_req_t;
                       out status: status_$t); extern;

{ VTOC_$GET_UID - the UID of a VTOCE given by its position.
  VTOC_$GET_NAME_DIRS - the UIDs of a volume's two name directories. }
procedure vtoc_$get_uid(vol_idx: integer; vtoc_idx: pinteger;
                        entry_idx: pinteger; out uid_ret: uid_$t;
                        out status_ret: status_$t); extern;

procedure vtoc_$get_name_dirs(vol_idx: integer; out name_dir_uid: uid_$t;
                              out dir_uid: uid_$t; out status: status_$t);
  options(extern, val_param);

{ VTOC_$SET_NAME_DIRS - look up a volume's two name directories. }
procedure vtoc_$set_name_dirs(vol_idx: integer; in dir1_uid: uid_$t;
                              in dir2_uid: uid_$t; out status: status_$t);
  options(extern, val_param);

{ VTOCE_$READ - read a VTOCE. }
procedure vtoce_$read(in out req: vtoc_$lookup_req_t; out result: vtoce_$t;
                      out status: status_$t); extern;

{ VTOCE_$WRITE - write a VTOCE back. }
procedure vtoce_$write(in req: vtoc_$lookup_req_t; in data: vtoce_$t;
                       flags: boolean; out status: status_$t);
  options(extern, val_param);

{ VTOCE_$LOOKUP_FM - find (or make) the file-map block of a segment. }
procedure vtoce_$lookup_fm(in vtoce_loc: vtoc_$lookup_req_t;
                           segment: pinteger; allocate: boolean;
                           out fm_loc: fm_$block_addr_t;
                           out alloc_count: integer32;
                           out status: status_$t);
  options(extern, val_param);

{ VTOCE_$TRUNCATE - truncate or delete an object's file map. }
procedure vtoce_$truncate(in loc: vtoc_$lookup_req_t; size: integer32;
                          alloc_length: integer32; delete_it: boolean;
                          out blocks_freed: integer32;
                          out status: status_$t);
  options(extern, val_param);
