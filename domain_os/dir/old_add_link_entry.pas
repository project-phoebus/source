{ dir_$old_add_link_entry - add a soft link to an old-format directory.

  Image addresses:
    sau2  0x00E5545C  dir_$old_add_link_entry (module-local)

  - The text goes into one 144-byte overflow block, two when longer,
    from the free list or reclaimed in the replace mode; the type-3 slot
    holds the text's length and the block numbers.

  Status stored:
    dir_$old_add_entry's status: the blocks were found
    name_$directory_full: no block could be had
}

procedure dir_$old_add_link_entry(in dir_uid: uid_$t;
                                  dir: dir_$old_dir_ptr_t;
                                  in new_name: univ name_$long_name_t;
                                  new_name_len: pinteger;
                                  in target: univ name_$long_pname_t;
                                  target_len: pinteger;
                                  replace_flag: boolean;
                                  out entry_ret: dir_$old_slot_ptr_t;
                                  out status_ret: status_$t);
  internal;
var
  rec: dir_$old_link_refs_t;
  hint: pinteger;
  i: pinteger;
  block2: pinteger;
  block1: pinteger;
begin
  { the first block }
  block2 := 0;
  block1 := dir_$old_alloc_block(dir);
  if block1 = 0 then begin
    if replace_flag then begin
      hint := target_len mod dir^.hdr.buckets;
      block1 := dir_$old_reclaim_block(dir, hint);
    end;
    if block1 = 0 then begin
      status_ret.all := name_$directory_full;
      return;
    end;
  end;

  { the text's first 16#90 bytes }
  dir^.blocks[block1].block_type := 3;
  for i := 1 to 144 do begin
    dir^.blocks[block1].text[i] := target[i];
    if i > target_len then
      exit;
  end;

  { the rest, in a second block }
  if target_len > 144 then begin
    block2 := dir_$old_alloc_block(dir);
    if block2 = 0 then begin
      if replace_flag then begin
        hint := hint + 1 mod dir^.hdr.buckets;
        block2 := dir_$old_reclaim_block(dir, hint);
      end;
      if block2 = 0 then begin
        dir_$old_free_slot(dir, 0, block1);
        status_ret.all := name_$directory_full;
        return;
      end;
    end;
    dir^.blocks[block2].block_type := 3;
    for i := 1 to 144 do begin
      dir^.blocks[block2].text[i] := target[i + 16#90];
      if i + 16#90 = target_len then
        exit;
    end;
  end;

  { the entry }
  rec.text_len := target_len;
  rec.block1 := block1;
  rec.block2 := block2;
  rec.reserved_06 := 0;
  dir_$old_add_entry(dir_uid, dir, new_name, new_name_len, 3, rec.uid,
                     replace_flag, entry_ret, status_ret);

  { the blocks back on failure }
  if status_ret.all <> status_$ok then begin
    dir_$old_free_slot(dir, 0, block1);
    if block2 <> 0 then
      dir_$old_free_slot(dir, 0, block2);
  end;
end;
