{ dir_$old_find_entry - look a name up in an old-format directory.

  Image addresses:
    sau2  0x00E54B9E  dir_$old_find_entry (module-local)

  - Page 0's slots first, compared by NAMEQ, then the name's hash
    chain's overflow blocks, giving up after 1300 blocks.
  - The result is whether the name was found, with the slot's address
    and place; nil when not found.

  Status stored: none.
}

function dir_$old_find_entry(dir: dir_$old_dir_ptr_t;
                             in name: univ name_$long_name_t;
                             name_len: pinteger;
                             out entry_ret: dir_$old_slot_ptr_t;
                             out slot_idx: pinteger;
                             out chain_level: integer): boolean;
  internal;
var
  i: pinteger;
  j: pinteger;
  hops: pinteger;
begin
  dir_$old_find_entry := false;
  entry_ret := nil;
  if dir^.entries_used = 0 then
    return;

  { the slots kept in page 0 }
  for i := 1 to dir^.hdr.inline_slots do
    if dir^.slots[i].slot_type <> 0 then
      if nameq(name, name_len, dir^.slots[i].name,
               dir^.slots[i].name_len) then begin
        chain_level := 0;
        slot_idx := i;
        entry_ret := addr(dir^.slots[slot_idx]);
        dir_$old_find_entry := true;
        return;
      end;

  { the bucket's chain }
  slot_idx := dir^.hash[dir_$old_hash_name(name, name_len,
                                           dir^.hdr.buckets)];
  hops := 0;

  while slot_idx <> 0 do
    with dir^.blocks[slot_idx] do begin
      hops := hops + 1;
      if hops > 16#514 then
        return;

      { the block's slots }
      for j := 1 to dir^.hdr.block_slots do
        if slots[j].slot_type <> 0 then
          if nameq(name, name_len, slots[j].name,
                   slots[j].name_len) then begin
            chain_level := j;
            entry_ret := addr(slots[chain_level]);
            dir_$old_find_entry := true;
            return;
          end;

      slot_idx := next;
    end;
end;
