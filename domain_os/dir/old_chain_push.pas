{ dir_$old_chain_push - put an overflow block at the head of a hash chain.

  Image addresses:
    sau2  0x00E54D10  dir_$old_chain_push (module-local)

  - The old head, if any, gets the block as its previous block; the
    block's previous link is 0 and its next the old head.

  Status stored: none.
}

procedure dir_$old_chain_push(dir: dir_$old_dir_ptr_t; hash: pinteger;
                              block: pinteger);
  internal;
var
  old: pinteger;
begin
  old := dir^.hash[hash];
  if old <> 0 then
    dir^.blocks[old].prev := block;

  dir^.hash[hash] := block;
  dir^.blocks[block].prev := 0;
  dir^.blocks[block].next := old;
end;
