{ dir_$old_find_overflow_slot - find a free entry slot in a hash chain.

  Image addresses:
    sau2  0x00E54F8A  dir_$old_find_overflow_slot (module-local)

  - A block of the chain with a free slot first (moved to the head when
    flags asks), else a new block (dir_$old_alloc_block).
  - With flags set and no block to be had, an evictable entry is deleted
    from the chain's tail end, or a whole block reclaimed.
  - The result is false only when nothing could be had.

  Status stored: none.
}

function dir_$old_find_overflow_slot(dir: dir_$old_dir_ptr_t; hash: pinteger;
                                     flags: boolean;
                                     out bucket_out: pinteger;
                                     out sub_slot_out: integer): boolean;
  internal;
var
  steps: pinteger;
  last: pinteger;
  j: integer;
begin
  dir_$old_find_overflow_slot := true;
  bucket_out := dir^.hash[hash];
  last := bucket_out;

  { a free slot in the chain }
  while bucket_out <> 0 do
    with dir^.blocks[bucket_out] do begin
      if used < dir^.hdr.block_slots then
        for j := 1 to dir^.hdr.block_slots do
          if slots[j].slot_type = 0 then begin
            sub_slot_out := j;
            slots[sub_slot_out].flags := slots[sub_slot_out].flags - [15];
            if flags then begin
              last := bucket_out;
              if last <> dir^.hash[hash] then begin
                dir_$old_chain_unlink(dir, hash, last);
                dir_$old_chain_push(dir, hash, last);
              end;
            end;
            return;
          end;

      last := bucket_out;
      bucket_out := next;
    end;

  { a new block }
  bucket_out := dir_$old_alloc_block(dir);
  if bucket_out = 0 then begin
    if not flags then begin
      dir_$old_find_overflow_slot := false;
      return;
    end;

    { an evictable entry, from the chain's end }
    steps := 0;
    while last <> 0 do begin
      for j := 1 to dir^.hdr.block_slots do
        if (dir^.blocks[last].slots[j].slot_type = 1) and then
           not (15 in dir^.blocks[last].slots[j].flags) then begin
          dir_$old_delete_entry(dir, last, j, hash);
          sub_slot_out := j;
          bucket_out := last;
          if dir^.hash[hash] <> bucket_out then begin
            dir_$old_chain_unlink(dir, hash, bucket_out);
            dir_$old_chain_push(dir, hash, bucket_out);
          end;
          return;
        end;

      last := dir^.blocks[last].prev;
      steps := steps + 1;
      if steps > dir^.hdr.max_blocks then
        exit;
    end;

    { a reclaimed block }
    bucket_out := dir_$old_reclaim_block(dir, hash);
    if bucket_out = 0 then begin
      dir_$old_find_overflow_slot := false;
      return;
    end;
  end;

  { the block set up empty }
  with dir^.blocks[bucket_out] do begin
    used := 0;
    block_type := 1;
    sub_slot_out := 1;
    for j := 1 to dir^.hdr.block_slots do begin
      slots[j].slot_type := 0;
      slots[j].flags := slots[j].flags - [15];
    end;
  end;

  dir_$old_chain_push(dir, hash, bucket_out);
end;
