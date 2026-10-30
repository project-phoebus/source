{ dir_$old_init_buf - lay out page 0 of a new old-format directory.

  Image addresses:
    sau2  0x00E544B0  dir_$old_init_buf (module-local)

  - The header's first ten bytes come from a constant: version 1, 43
    hash buckets, 18 slots in the page, at most 429 overflow blocks, 3
    slots a block; at most 1300 entries.
  - Every hash head, page slot and the info block are cleared.

  Status stored: none.
}

{ TODO(pascal) dir_$old_init_buf's header copied from a constant in the code

  buf.hdr is filled by a block copy from the ten bytes after the
  routine's code (version 1, 16#2B, 16#12, 16#1AD, 3): a 10-byte
  constant of the header record's size assigned to it, FLP_$DINIT's form
  (see the TODO(pascal) in flp/dinit.pas).  The reference has no record
  constants, so the Pascal assigns the five fields: the same values in
  five stores, not one copy. }

procedure dir_$old_init_buf(out buf: dir_$old_dir_t);
  internal;
var
  i: integer;                             { the hash and slot loops }
  k: pinteger;                            { the information block's }
begin
  buf.hdr.version := 1;
  buf.hdr.buckets := 16#2B;
  buf.hdr.inline_slots := 16#12;
  buf.hdr.max_blocks := 16#1AD;
  buf.hdr.block_slots := 3;

  buf.parent_uid := uid_$nil;
  buf.entries_used := 0;
  buf.max_entries := 1300;
  buf.blocks_used := 0;
  buf.free_block := 0;

  for i := 0 to 42 do
    buf.hash[i] := 0;

  for i := 1 to 18 do
    buf.slots[i].slot_type := 0;

  buf.initialized := 1;
  buf.unused_37b := chr(0);
  buf.info_write_len := 0;
  buf.info_read_len := 0;
  buf.unused_380 := 0;

  for k := 1 to 40 do
    buf.info[k] := chr(0);
end;
