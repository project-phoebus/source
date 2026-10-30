{ dir_$old_free_slot - return an overflow block to the free list.

  Image addresses:
    sau2  0x00E5518C  dir_$old_free_slot (module-local)

  - An entry block (type 1) still holding entries is left alone; an
    empty one leaves its hash chain first.  Text blocks (type 3) are
    freed directly (hash 0).
  - The block becomes the free list's head, its type cleared.

  Status stored: none.
}

procedure dir_$old_free_slot(dir: dir_$old_dir_ptr_t; hash: pinteger;
                             block: pinteger);
  internal;
var
  next_link: pinteger;
  prev_link: pinteger;
  old_free: pinteger;
begin
  with dir^.blocks[block] do begin
    { out of its hash chain }
    if block_type = 1 then begin
      if used <> 0 then
        return;
      next_link := next;
      prev_link := prev;
      if next_link = prev_link then
        next_link := 0;
      if next_link <> 0 then
        dir^.blocks[next_link].prev := prev_link;
      if prev_link <> 0 then
        dir^.blocks[prev_link].next := next_link
      else
        dir^.hash[hash] := next_link;
    end;

    { on to the free list }
    old_free := dir^.free_block;
    dir^.free_block := block;
    next := old_free;
    prev := 0;
    block_type := 0;
  end;
end;
