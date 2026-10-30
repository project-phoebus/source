{ dir_$old_chain_unlink - take an overflow block out of a hash chain.

  Image addresses:
    sau2  0x00E54D62  dir_$old_chain_unlink (module-local)

  - The next block, if any, gets the previous one as its previous link;
    the previous block, if any, gets the next as its next link, else the
    bucket's head becomes the next block.
  - Equal links, both 0 or a two-block cycle, count as no next block.

  Status stored: none.
}

procedure dir_$old_chain_unlink(dir: dir_$old_dir_ptr_t; hash: pinteger;
                                block: pinteger);
  internal;
var
  next_link: pinteger;
  prev_link: pinteger;
begin
  next_link := dir^.blocks[block].next;
  prev_link := dir^.blocks[block].prev;
  if prev_link = next_link then
    next_link := 0;

  if next_link <> 0 then
    dir^.blocks[next_link].prev := prev_link;

  if prev_link <> 0 then
    dir^.blocks[prev_link].next := next_link
  else
    dir^.hash[hash] := next_link;
end;
