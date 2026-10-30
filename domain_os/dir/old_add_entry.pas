{ dir_$old_add_entry - add an entry to an old-format directory.

  Image addresses:
    sau2  0x00E55220  dir_$old_add_entry (module-local)

  - A free slot of page 0's eighteen first, else one in an overflow
    block of the name's hash chain (dir_$old_find_overflow_slot, which
    may reclaim one in the replace mode).
  - The slot gets the type, the UID and the name padded with blanks to
    32 characters; the slot's address is handed back.

  Status stored:
    status_$ok: the entry was added
    name_$already_exists: the name is in the directory
    name_$directory_full: no slot, or (not replacing) the entry count is
      at its maximum
}

procedure dir_$old_add_entry(in dir_uid: uid_$t; dir: dir_$old_dir_ptr_t;
                             in new_name: univ name_$long_name_t;
                             new_name_len: pinteger; entry_type: integer;
                             in uid_data: uid_$t; replace_flag: boolean;
                             out entry_ret: dir_$old_slot_ptr_t;
                             out status_ret: status_$t);
  internal;
label
  10;
var
  hash: pinteger;
  i: pinteger;
  slot_idx: pinteger;
  chain_level: integer;
  found: boolean;
begin
  entry_ret := nil;
  if dir_$old_find_entry(dir, new_name, new_name_len, entry_ret, slot_idx,
                         chain_level) then begin
    status_ret.all := name_$already_exists;
    return;
  end;

  if not replace_flag and then
     (dir^.entries_used = dir^.max_entries) then
    goto 10;

  { a slot in the page }
  if dir_$old_find_free_inline_slot(dir, dir^.hdr.inline_slots,
                                    slot_idx) then begin
    with dir^.slots[slot_idx] do begin
      slot_type := entry_type;
      uid := uid_data;
      for i := 1 to new_name_len do
        name[i] := new_name[i];
      for i := new_name_len + 1 to 32 do
        name[i] := ' ';
      name_len := new_name_len;
    end;
    status_ret.all := status_$ok;
    dir^.entries_used := dir^.entries_used + 1;
    entry_ret := addr(dir^.slots[slot_idx]);
    return;
  end;

  { a slot in an overflow block }
  hash := dir_$old_hash_name(new_name, new_name_len, dir^.hdr.buckets);
  found := dir_$old_find_overflow_slot(dir, hash, replace_flag, slot_idx,
                                       chain_level);
  if found then begin
    with dir^.blocks[slot_idx] do
      with slots[chain_level] do begin
        slot_type := entry_type;
        used := used + 1;
        uid := uid_data;
        for i := 1 to new_name_len do
          name[i] := new_name[i];
        for i := new_name_len + 1 to 32 do
          name[i] := ' ';
        name_len := new_name_len;
        status_ret.all := status_$ok;
        dir^.entries_used := dir^.entries_used + 1;
        entry_ret := addr(slots[chain_level]);
      end;
    return;
  end;

10:
  status_ret.all := name_$directory_full;
end;
