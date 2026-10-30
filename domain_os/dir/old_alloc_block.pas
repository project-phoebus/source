{ dir_$old_alloc_block - take an overflow block for use.

  Image addresses:
    sau2  0x00E54E10  dir_$old_alloc_block (module-local)

  - The free list's head, else the next block never used while the used
    blocks are below the header's maximum; the result is the block, 0
    when none can be had.

  Status stored: none.
}

function dir_$old_alloc_block(dir: dir_$old_dir_ptr_t): pinteger;
  internal;
var
  k: pinteger;
begin
  k := dir^.free_block;
  if k <> 0 then begin
    dir^.free_block := dir^.blocks[k].next;
    dir^.blocks[k].used := 0;
  end
  else if dir^.blocks_used < dir^.hdr.max_blocks then begin
    dir^.blocks_used := dir^.blocks_used + 1;
    k := dir^.blocks_used;
    dir^.blocks[k].used := 0;
  end
  else
    k := 0;

  dir_$old_alloc_block := k;
end;
