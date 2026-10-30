{ dir_$old_find_uid_slot - find the in-use slot of an old-format
  directory that holds a UID.

  Image addresses:
    sau2  0x00E557D4  dir_$old_find_uid_slot (module-local)

  - Page 0's slots, then every overflow block's; the first in-use slot
    with the UID hands back its 32 name bytes and its name length.

  Status stored:
    status_$ok: the UID's slot was found
    name_$not_found: none matched
}

procedure dir_$old_find_uid_slot(dir: dir_$old_dir_ptr_t;
                                 in target_uid: uid_$t;
                                 out name_out: rem_name_$name_t;
                                 out len_out: pinteger;
                                 out status_ret: status_$t);
  internal;
var
  i: pinteger;
  k: pinteger;
  j: pinteger;
begin
  { the slots kept in page 0 }
  for i := 1 to dir^.hdr.inline_slots do
    with dir^.slots[i] do
      if (slot_type = 1) and then (uid = target_uid) then begin
        name_out := name;
        len_out := name_len;
        status_ret.all := status_$ok;
        return;
      end;

  { the overflow blocks' slots }
  for k := 1 to dir^.blocks_used do
    if dir^.blocks[k].block_type = 1 then
      for j := 1 to dir^.hdr.block_slots do
        with dir^.blocks[k].slots[j] do
          if (slot_type = 1) and then (uid = target_uid) then begin
            name_out := name;
            len_out := name_len;
            status_ret.all := status_$ok;
            return;
          end;

  status_ret.all := name_$not_found;
end;
