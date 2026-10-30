{ dir_$old_delete_entry - clear an entry slot of an old-format directory.

  Image addresses:
    sau2  0x00E555DC  dir_$old_delete_entry (module-local)

  - A page-0 slot (chain_level 0, slot_idx its number) or an overflow
    block's (slot_idx the block, chain_level the slot); a block's used
    count goes down, and an empty block back on the free list.
  - A soft link's slot (type 3) gives its text blocks back too.

  Status stored: none.
}

procedure dir_$old_delete_entry(dir: dir_$old_dir_ptr_t; slot_idx: pinteger;
                                chain_level: pinteger; hash: pinteger);
  internal;
var
  refs: dir_$old_link_refs_t;
  entry_type: integer;
begin
  if chain_level = 0 then begin
    with dir^.slots[slot_idx] do begin
      entry_type := slot_type;
      refs.uid := uid;
      slot_type := 0;
      flags := flags - [15];
    end;
  end
  else begin
    with dir^.blocks[slot_idx] do begin
      with slots[chain_level] do begin
        entry_type := slot_type;
        refs.uid := uid;
        slot_type := 0;
        flags := flags - [15];
      end;
      used := used - 1;
    end;
    dir_$old_free_slot(dir, hash, slot_idx);
  end;

  dir^.entries_used := dir^.entries_used - 1;

  { a soft link's text blocks }
  if entry_type = 3 then begin
    dir_$old_free_slot(dir, 0, refs.block1);
    if refs.block2 <> 0 then
      dir_$old_free_slot(dir, 0, refs.block2);
  end;
end;
