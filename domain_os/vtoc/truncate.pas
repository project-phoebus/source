{ VTOCE_$TRUNCATE - truncate or delete an object's file map.

  Image addresses:
    sau2  0x00E39E42  VTOCE_$TRUNCATE
    sau2  0x00E39BC2  vtoc_$free_indirect (nested)

  - Under ml_$vtoc_lock: deleting clears the VTOCE's in-use bit (a block
    falling to two entries rejoins the free list) and drops it from the
    UID cache; truncating clears the roots beyond the kept length.
  - The direct blocks and the three indirect trees beyond it are freed
    (the nested walk); the count freed is handed back.
  - size is not read, and the third tree is walked whatever the kept
    length.

  Status stored:
    status_$ok: the map was truncated (the last step's status)
    status_$vtoc_not_mounted: the volume is not mounted
    status_$vtoc_invalid_vtoce: a deleted UID not in its bucket chain
    status_$vtoc_is_bad: the VTOCE is not in use, or not the UID's
    the failed step's status: a DBUF or BAT routine
}

procedure vtoce_$truncate(in loc: vtoc_$lookup_req_t; size: integer32;
                          alloc_length: integer32; delete_it: boolean;
                          out blocks_freed: integer32;
                          out status: status_$t);
label
  90;
var
  cache_loc: fm_$block_addr_t;
  map: fm_$entry_ptr_t;
  ignored: status_$t;
  bkt_buf: fm_$buffer_ptr_t;
  block: linteger;
  bkt_block: linteger;
  keep_blocks: linteger;
  vol_idx: integer;
  cache_vol: integer;
  bkt_idx: integer;
  i: pinteger;
  freed: integer;
  found: boolean;
  changed: boolean;
  entry: integer;
  new_fmt: boolean;
  walk_block: linteger;
  root1: integer32;
  root2: integer32;
  root3: integer32;
  slot_k: integer;
  k: integer;                             { the slots }
  buf: fm_$buffer_ptr_t;
  roots: vtoc_$fm_roots_ptr_t;

  { vtoc_$free_indirect - free a file-map tree beyond the kept length.

    - The level's block's 256 addresses from the kept length on are
      collected (level 1 into VTOC_'s free list) and cleared; every five
      subtrees the block is written back and the level-1 blocks freed or
      the subtrees walked.  A whole tree's block is freed itself.
    - Nested in VTOCE_$TRUNCATE, whose locals it reaches; its own status
      parameter is never written.

    Status stored (in VTOCE_$TRUNCATE's status):
      the DBUF and BAT routines' statuses: always }

  procedure vtoc_$free_indirect(block: linteger; level: integer;
                                base: linteger; span: linteger;
                                whole: boolean;
                                out unused_status: status_$t);
  label
    10;
  var
    children: array[1..5] of linteger;
    child_idx: array[1..5] of integer;
    cur_base: linteger;
    ibuf: fm_$buffer_ptr_t;
    i: integer;
    dirtied: boolean;
    sub_span: linteger;
    count: integer;
    first: integer;
    sub_base: linteger;
    j: integer;                           { the subtrees }
  begin
    count := 0;
    dirtied := false;
    ibuf := dbuf_$get_block(vol_idx, block, loc.uid, base, level, 0, status);
    if status.all <> status_$ok then
      return;

    if whole then
      first := 0
    else
      first := (keep_blocks - base) div span;
    cur_base := first * span + base;

    { the block's 256 addresses }
    sub_span := rshft(span, 8);
    for i := first to 255 do begin
      if ibuf^.longs[i] <> 0 then begin
        count := count + 1;
        if level = 1 then
          vtoc_$free_list[count] := ibuf^.longs[i] & 16#7FFFFFFF
        else begin
          children[count] := ibuf^.longs[i] & 16#7FFFFFFF;
          child_idx[count] := i;
        end;
        if (not whole) and then (keep_blocks <= cur_base) then begin
          ibuf^.longs[i] := 0;
          dirtied := true;
        end;
      end;

      if ((count >= 5) and (level > 1)) or else
         ((i = 255) and then (count > 0)) then begin
        if dirtied then begin
          dbuf_$set_buff(ibuf, 3, status);
          dirtied := false;
          if status.all <> status_$ok then
            goto 10;
        end;
        if level = 1 then begin
          bat_$free(vtoc_$free_list, count, vol_idx, 0, status);
          blocks_freed := blocks_freed + count;
          if status.all <> status_$ok then
            goto 10;
        end
        else
          for j := 1 to count do begin
            sub_base := child_idx[j] * span + base;
            vtoc_$free_indirect(children[j], level - 1, sub_base, sub_span,
                                sub_base >= keep_blocks, status);
            if status.all <> status_$ok then
              goto 10;
          end;
        count := 0;
      end;
      cur_base := cur_base + span;
    end;

    { the whole tree's own block }
    if whole then begin
      bat_$free(block, 1, vol_idx, 0, status);
      blocks_freed := blocks_freed + 1;
      dbuf_$set_buff(ibuf, 12, ignored);
      if status.all = status_$ok then
        status := ignored;
      return;
    end;

10:
    dbuf_$set_buff(ibuf, bat_buf_clean, ignored);
  end;

begin
  vol_idx := loc.tail.vol_idx;
  keep_blocks := (alloc_length + 16#3FF) div 1024;
  block := loc.block_hint.block_num;
  entry := loc.block_hint.entry_idx;
  blocks_freed := 0;
  freed := 0;
  new_fmt := vtoc_$format[vol_idx];
  changed := false;
  bkt_buf := nil;

  ml_$lock(ml_$vtoc_lock);
  if not vtoc_$mounted[vol_idx] then begin
    status.all := status_$vtoc_not_mounted;
    goto 90;
  end;

  { a deletion's bucket slot }
  if new_fmt and delete_it then begin
    found := false;
    vtoc_$hash_uid(loc.uid, vol_idx, bkt_idx, bkt_block, status);
    walk_block := bkt_block;
    if status.all <> status_$ok then
      goto 90;
    repeat
      bkt_buf := dbuf_$get_block(vol_idx, walk_block, vtoc_bkt_$uid,
                                 walk_block, 0, 0, status);
      if status.all <> status_$ok then
        goto 90;
      with bkt_buf^.bkt_block.buckets[bkt_idx] do begin
        for k := 0 to 19 do
          if (slots[k].block_info.all <> 0) and then
             (slots[k].uid = loc.uid) then begin
            found := true;
            slot_k := k;
            exit;
          end;
        if found then
          exit;
        walk_block := next_bucket;
        bkt_idx := next_bkt_idx;
      end;
      dbuf_$set_buff(bkt_buf, bat_buf_clean, ignored);
    until walk_block = 0;
    if not found then begin
      bkt_buf := nil;
      status.all := status_$vtoc_invalid_vtoce;
      goto 90;
    end;
  end;

  { the VTOCE }
  buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0, status);
  if status.all <> status_$ok then
    goto 90;
  if new_fmt then
    with buf^.new_vtoc.entries[entry] do begin
      if (not core.hdr.in_use) or else (core.id.uid <> loc.uid) then begin
        status.all := status_$vtoc_is_bad;
        goto 90;
      end;
      roots := addr(indirect);
      map := addr(direct);
    end
  else begin
    roots := addr(buf^.old_vtoc.entries[entry].indirect);
    map := addr(buf^.old_vtoc.entries[entry].direct);
  end;
  root3 := roots^[3];
  root2 := roots^[2];
  root1 := roots^[1];

  { deleted, or the trees beyond the length }
  if delete_it then begin
    changed := true;
    if new_fmt then begin
      buf^.new_vtoc.entries[entry].core.hdr.in_use := false;
      buf^.new_vtoc.entry_count := buf^.new_vtoc.entry_count - 1;
      if buf^.new_vtoc.entry_count = 2 then
        buf^.new_vtoc.next_block := bat_$add_part_vtoce(vol_idx, block,
                                                        status);
    end
    else
      buf^.old_vtoc.entries[entry].hdr.in_use := false;
    discard(vtoc_$uid_cache_lookup(loc.uid, cache_vol, cache_loc, true));
  end
  else begin
    if (keep_blocks <= 16#20) and then (root1 <> 0) then begin
      changed := true;
      roots^[1] := 0;
    end;
    if (keep_blocks <= 16#120) and then (root2 <> 0) then begin
      changed := true;
      roots^[2] := 0;
    end;
    if (keep_blocks <= 16#10120) and then (root3 <> 0) then begin
      changed := true;
      roots^[3] := 0;
    end;
  end;

  { the direct blocks beyond the length }
  if keep_blocks < 16#20 then begin
    for i := keep_blocks to 31 do
      if map^.blocks[i] <> 0 then begin
        freed := freed + 1;
        vtoc_$free_list[freed] := map^.blocks[i] & 16#7FFFFFFF;
        map^.blocks[i] := 0;
      end;
    if freed > 0 then
      changed := true;
  end;

  { the block written, the blocks freed }
  if changed then begin
    dbuf_$set_buff(buf, bat_buf_writeback, status);
    if status.all = status_$ok then begin
      if freed <> 0 then
        bat_$free(vtoc_$free_list, freed, vol_idx, 0, status);
      if bkt_buf <> nil then begin
        bkt_buf^.bkt_block.buckets[bkt_idx].slots[slot_k].block_info.all :=
          0;
        dbuf_$set_buff(bkt_buf, bat_buf_dirty, status);
        bkt_buf := nil;
      end;
    end;
  end
  else
    dbuf_$set_buff(buf, bat_buf_dirty, status);
  if status.all <> status_$ok then
    goto 90;
  blocks_freed := freed;

  { the three trees }
  if (root1 <> 0) and then (keep_blocks < 16#120) then begin
    vtoc_$free_indirect(root1, 1, 16#20, 1, keep_blocks <= 16#20, status);
    if status.all <> status_$ok then
      goto 90;
  end;
  if (root2 <> 0) and then (keep_blocks < 16#10120) then begin
    vtoc_$free_indirect(root2, 2, 16#120, 16#100, keep_blocks <= 16#120,
                        status);
    if status.all <> status_$ok then
      goto 90;
  end;
  if root3 <> 0 then
    vtoc_$free_indirect(root3, 3, 16#10120, 16#10000,
                        keep_blocks <= 16#10120, status);

90:
  if bkt_buf <> nil then
    dbuf_$set_buff(bkt_buf, bat_buf_clean, ignored);
  ml_$unlock(ml_$vtoc_lock);
end;
