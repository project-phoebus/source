{ dbuf/dbuf.ins.pas - DBUF_ (the disk buffer cache) types, variables
  and routine headings, for the Domain Pascal tree.

  The module is dbuf/dbuf.pas.  Include base/base.ins.pas before it
  (dbuf/dbuf.pas includes the rest).
}

const
  { The operations of DBUF_$SET_BUFF's flags word, tested in this order
    (bits 0..3). }
  dbuf_flag_dirty      = 16#01;
  dbuf_flag_writeback  = 16#02;
  dbuf_flag_invalidate = 16#04;
  dbuf_flag_release    = 16#08;

  { DBUF_$GET_BLOCK's flags (bits 4 and 5). }
  dbuf_get_no_read       = 16#10;
  dbuf_get_ok_if_stopped = 16#20;

  { The pool's bounds, which DBUF_$INIT clamps the count to; 64 entries
    of 0x24 bytes fill the block from +0x10 to the spin lock at +0x910. }
  dbuf_min_buffers = 6;
  dbuf_max_buffers = 64;

  { DBUF_$SET_BUFF's crash statuses, constant cells after its code:
    stcode.db.10.2's "bad free" and "bad ptr" (subsystem 16#0C). }
  os_dbuf_bad_free_err = 16#000C0002;
  os_dbuf_bad_ptr_err  = 16#000C0001;

type
  { A buffer's identity, 12 bytes: the object's UID and the caller's hint
    (the first three longwords of the header DISK_$READ and DISK_$WRITE
    take).  Copied field by field and as 12 bytes: a variant record with
    both views. }
  dbuf_$ident_t = record
    case integer of
      1: (uid: uid_$t;                    { 0x00 }
          hint: integer32);               { 0x08 }
      2: (bytes: array[1..12] of char);   { 0x00 }
  end;

  { The entry's flags word, 2 bytes, a packed record (ref 3.10.7; fields
    from the most significant bit): the flags byte
    (busy bit 7, dirty bit 6, the volume in bits 0..3) and the type
    byte:
    - busy, set and cleared as bit 7 of the byte, tested as the sign of
      the word;
    - dirty, set and cleared as bit 6, tested in the loaded word;
    - two bits DBUF_$INIT clears, not otherwise addressed;
    - vol, the volume index, read and stored as the low nibble;
    - block_type, the caller's block type, a whole byte (`type' is a
      Pascal reserved word). }
  { The second arm views the flags byte whole: the volume is passed to
    DISK_$WRITE as a word, and a field of a packed record that is not a
    whole byte cannot be an argument (ref 3.10.3, p. 3-21), so the
    argument is `flags_byte & 16#0F', the same instructions. }
  dbuf_$flags_t = packed record
    case integer of
      1: (busy: boolean;                  { bit 0 (0x0C bit 7) }
          dirty: boolean;                 { bit 1 }
          unused_2: 0..3;                 { bits 2..3 }
          vol: 0..15;                     { bits 4..7 }
          block_type: 0..255);            { bits 8..15 (0x0D) }
      2: (flags_byte: 0..255;             { 0x0C }
          type_byte: 0..255);             { 0x0D }
  end;

  { A buffer entry, 0x24 bytes.  next and prev link the LRU list:
    pointers; data is the buffer's address, compared with DBUF_$SET_BUFF's
    univ_ptr argument and returned by DBUF_$GET_BLOCK.  The fields carry
    the prefix e_ (as netlog/netlog.ins.pas's entry): DBUF_$INVALIDATE
    and DBUF_$UPDATE_VOL reach them inside a `with', where unprefixed
    names would hide their parameters. }
  dbuf_$entry_ptr_t = ^dbuf_$entry_t;
  dbuf_$entry_t = record
    e_next: dbuf_$entry_ptr_t;            { 0x00 }
    e_prev: dbuf_$entry_ptr_t;            { 0x04 }
    e_data: univ_ptr;                     { 0x08 }
    e_flags: dbuf_$flags_t;               { 0x0C }
    e_ref_count: integer;                 { 0x0E }
    e_ppn: integer32;                     { 0x10 }
    e_block: integer32;                   { 0x14 }
    e_ident: dbuf_$ident_t;               { 0x18 }
  end;

  { The eight-longword header the routines hand to DISK_$READ and
    DISK_$WRITE, built in a 0x20-byte frame area: the identity in the
    first 12 bytes, the block type at +0x10 and a zero byte after it.
    The other bytes are never written by DBUF (they are whatever the
    frame held). }
  dbuf_$hdr_t = record
    ident: dbuf_$ident_t;                 { 0x00 }
    unused_0c: integer32;                 { 0x0C }
    block_type: char;                     { 0x10 }
    type_pad: char;                       { 0x11 }
    unused_12: array[16#12..16#1F] of char;  { 0x12 }
  end;

  { A 1K buffer page. }
  dbuf_$block_t = array[1..1024] of char;

var
  { DBUF (map symbol, +0x10 of the module's .DATA block): the entry
    array, from 1.  Defined in dbuf/dbuf.pas. }
  dbuf: extern array[1..dbuf_max_buffers] of dbuf_$entry_t;

  { DBUF_$TROUBLE (map symbol, +0x91C): one member per volume whose
    write-back failed: a word set, `s := s + [v]' and `s := s - [v]'.
    Defined in dbuf/dbuf.pas. }
  dbuf_$trouble: extern set of 0..15;

  { DBUF_BLKS (map symbol of the DISK_BUFFERS region, with no `$': a
    label of that region, not of the DBUF module): the buffer pages,
    from 1. }
  dbuf_blks: extern array[1..dbuf_max_buffers] of dbuf_$block_t;

{ DBUF_$GET_BLOCK - look a disk block up in the buffer cache, reading it
  in. }
function dbuf_$get_block(vol_idx: integer; block: integer32;
                         in uid: uid_$t; block_hint: integer32;
                         block_type: integer; flags: integer;
                         out status: status_$t): univ_ptr;
  options(extern, val_param);

{ DBUF_$SET_BUFF - release and/or write back a buffer. }
procedure dbuf_$set_buff(buffer: univ_ptr; flags: integer;
                         out status: status_$t);
  options(extern, val_param);

{ DBUF_$INVALIDATE - drop one block, or every block, of a volume. }
procedure dbuf_$invalidate(block: integer32; vol_idx: integer);
  options(extern, val_param);

{ DBUF_$UPDATE_VOL - write every idle dirty buffer of a volume back. }
procedure dbuf_$update_vol(vol_idx: integer; in uid: uid_$t);
  options(extern, val_param);

{ DBUF_$INIT - build the buffer pool. }
procedure dbuf_$init; extern;
