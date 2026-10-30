{ dir_$old_reclaim_block - free an overflow block by evicting its entries.

  Image addresses:
    sau2  0x00E54E62  dir_$old_reclaim_block (module-local)

  - From the bucket after the given hash, each chain is searched from
    its tail for a block whose slots are all free or evictable; its
    entries are deleted and the result is dir_$old_alloc_block's block.
  - With no evictable block the result is not assigned.

  Status stored: none.
}

function dir_$old_reclaim_block(dir: dir_$old_dir_ptr_t;
                                hash: pinteger): pinteger;
  internal;
var
  evictable: boolean;
  h: pinteger;
  block: pinteger;
  n: integer;
  j: integer;
begin
  h := hash;

  for n := 1 to dir^.hdr.buckets do begin
    h := (h + 1) mod dir^.hdr.buckets;

    block := dir^.hash[h];
    if block <> 0 then begin
      { to the chain's last block }
      while dir^.blocks[block].next <> 0 do
        block := dir^.blocks[block].next;

      { back towards the head }
      while block <> 0 do begin
        { can every slot go? }
        evictable := true;
        for j := 1 to dir^.hdr.block_slots do
          if (dir^.blocks[block].slots[j].slot_type <> 0) and then
             ((15 in dir^.blocks[block].slots[j].flags) or else
              (dir^.blocks[block].slots[j].slot_type <> 1)) then begin
            evictable := false;
            exit;
          end;

        { evict them and take a block }
        if evictable then begin
          for j := 1 to dir^.hdr.block_slots do
            if dir^.blocks[block].slots[j].slot_type <> 0 then
              dir_$old_delete_entry(dir, block, j, h);
          dir_$old_reclaim_block := dir_$old_alloc_block(dir);
          return;
        end;

        block := dir^.blocks[block].prev;
      end;
    end;
  end;
end;
