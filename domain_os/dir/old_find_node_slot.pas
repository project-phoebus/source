{ dir_$old_find_node_slot - find the in-use slot of an old-format
  directory whose UID names a node.

  Image addresses:
    sau2  0x00E559D6  dir_$old_find_node_slot (module-local)

  - Page 0's slots, then every overflow block's, for a UID with the node
    in the low 20 bits of its low half; the first is copied into the
    caller's replicated-root entry record.

  Status stored:
    status_$ok: the node's slot was found
    name_$not_found: none matched
}

procedure dir_$old_find_node_slot(dir: dir_$old_dir_ptr_t; node: linteger;
                                  out entry: rem_name_$dir_entry_t;
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
      if (slot_type = 1) and then ((uid.low & 16#FFFFF) = node) then begin
        entry.name := name;
        entry.name_len := name_len;
        entry.uid := uid;
        entry.extra := extra;
        status_ret.all := status_$ok;
        return;
      end;

  { the overflow blocks' slots }
  for k := 1 to dir^.blocks_used do
    if dir^.blocks[k].block_type = 1 then
      for j := 1 to dir^.hdr.block_slots do
        with dir^.blocks[k].slots[j] do
          if (slot_type = 1) and then ((uid.low & 16#FFFFF) = node) then
          begin
            entry.name := name;
            entry.name_len := name_len;
            entry.uid := uid;
            entry.extra := extra;
            status_ret.all := status_$ok;
            return;
          end;

  status_ret.all := name_$not_found;
end;
