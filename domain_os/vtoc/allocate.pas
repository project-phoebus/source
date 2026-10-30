{ VTOC_$ALLOCATE - allocate a VTOCE for a new object.

  Image addresses:
    sau2  0x00E388AC  VTOC_$ALLOCATE

  - Under ml_$vtoc_lock, new format: a free slot in the UID's hash
    bucket chain (a bucket appended when none), the VTOCE in a block
    BAT_$ALLOC_VTOCE gives.
  - Old format: a free entry in the hash's VTOC block chain, written in
    the old format.
  - The location goes into the UID cache; the caller's request is
    rewritten with the volume's mount word, the location and the node.
  - The old arm uses DBUF_$GET_BLOCK's new block without testing its
    status.

  Status stored:
    status_$ok: the VTOCE was allocated (the last step's status)
    status_$vtoc_not_mounted: the volume is not mounted
    status_$vtoc_duplicate_uid: the UID is in the VTOC already
    status_$vtoc_is_bad: the bucket chain is bad
    the failed step's status: vtoc_$hash_uid, DBUF_$GET_BLOCK,
      DBUF_$SET_BUFF, BAT_$ALLOCATE or BAT_$ALLOC_VTOCE
}

procedure vtoc_$allocate(in out loc: vtoc_$lookup_req_t;
                         in out new_vtoce: vtoce_$t;
                         out status: status_$t);
label
  10, 20, 30, 35, 40, 45, 50, 60, 70, 80, 90;
var
  vol_idx: integer;
  vtoce_loc: fm_$block_addr_t;
  cur_buf: fm_$buffer_ptr_t;
  ignored: status_$t;
  bkt_buf: fm_$buffer_ptr_t;
  prev_buf: fm_$buffer_ptr_t;
  block: linteger;
  alloc_block: linteger;
  bkt_dirty: integer;
  blk_dirty: integer;
  free_slot: integer;
  free_vtoce: integer;
  bucket_idx: pinteger;
  new_blk_flag: boolean;
  blk_buf: fm_$buffer_ptr_t;
  walk_idx: pinteger;
  next_block: integer32;
  new_bkt_block: boolean;
  k: integer;                             { the scans }
  i: integer;                             { the fills }
begin
  vol_idx := loc.tail.vol_idx;
  vtoce_loc := loc.block_hint;
  new_vtoce.hdr.in_use := true;
  ml_$lock(ml_$vtoc_lock);
  if not vtoc_$mounted[vol_idx] then begin
    status.all := status_$vtoc_not_mounted;
    goto 90;
  end;

  prev_buf := nil;
  bkt_buf := nil;
  bkt_dirty := bat_buf_clean;
  vtoc_$hash_uid(new_vtoce.id.uid, vol_idx, bucket_idx, block, status);
  if status.all <> status_$ok then
    goto 90;
  if not vtoc_$format[vol_idx] then
    goto 30;

  { the new format's bucket }
  with vtoc_$vols[vol_idx] do begin
    bkt_buf := dbuf_$get_block(vol_idx, block, vtoc_bkt_$uid, block, 0, 0,
                               status);
    if status.all <> status_$ok then
      goto 90;

    { the file server looks for the UID first }
    if proc1_$type[proc1_$current] = 9 then begin
      cur_buf := bkt_buf;
      walk_idx := bucket_idx;
      repeat
        with cur_buf^.bkt_block.buckets[walk_idx] do begin
          next_block := next_bucket;
          walk_idx := next_bkt_idx;
          for k := 0 to 19 do
            if (slots[k].block_info.all <> 0) and then
               (slots[k].uid = new_vtoce.id.uid) then begin
              vtoce_loc := slots[k].block_info;
              status.all := status_$vtoc_duplicate_uid;
              exit;
            end;
        end;
        if bkt_buf <> cur_buf then
          dbuf_$set_buff(cur_buf, bat_buf_clean, ignored);
        if status.all <> status_$ok then
          goto 70;
        if next_block = 0 then
          exit;
        cur_buf := dbuf_$get_block(vol_idx, next_block, vtoc_bkt_$uid,
                                   next_block, 0, 0, status);
        if status.all <> status_$ok then
          goto 70;
      until false;
    end;

    { a free slot in the bucket or its chain }
    free_slot := -1;
10: with bkt_buf^.bkt_block.buckets[bucket_idx] do begin
      for k := 0 to 19 do
        if slots[k].block_info.all = 0 then begin
          free_slot := k;
          exit;
        end;
      if free_slot >= 0 then
        goto 20;

      new_bkt_block := false;
      if next_bucket = 0 then begin
        if cur_bkt_block = 0 then begin
          bat_$allocate(vol_idx, block, 1, 0, block, status);
          if status.all <> status_$ok then
            goto 70;
          cur_bkt_block := block;
          cur_bkt_idx := 0;
          new_bkt_block := true;
          bkt_dirty := bat_buf_writeback;
          blocks_added := blocks_added + 1;
        end;
        bucket_idx := cur_bkt_idx;
        block := cur_bkt_block;
        cur_bkt_idx := cur_bkt_idx + 1;
        if cur_bkt_idx = 4 then
          cur_bkt_block := 0;
        next_bucket := block;
        next_bkt_idx := bucket_idx;
        prev_buf := bkt_buf;
      end
      else begin
        block := next_bucket;
        bucket_idx := next_bkt_idx;
        dbuf_$set_buff(bkt_buf, bat_buf_clean, status);
      end;
    end;
    if new_bkt_block then
      bkt_buf := dbuf_$get_block(vol_idx, block, vtoc_bkt_$uid, block, 0,
                                 dbuf_get_no_read, status)
    else
      bkt_buf := dbuf_$get_block(vol_idx, block, vtoc_bkt_$uid, block, 0,
                                 0, status);
    if status.all <> status_$ok then
      goto 80;
    if new_bkt_block then begin
      for i := 0 to 253 do
        bkt_buf^.longs[i] := 0;
      bkt_buf^.bkt_block.magic := vtoc_bkt_block_magic;
      bkt_buf^.bkt_block.self_block := block;
    end;
    goto 10;
  end;

  { the VTOCE block and the slot }
20:
  alloc_block := vtoce_loc.block_num;
  blk_buf := bat_$alloc_vtoce(vol_idx, alloc_block, alloc_block, status,
                              new_blk_flag);
  if status.all <> status_$ok then
    goto 70;
  free_vtoce := -1;
  for k := 0 to 2 do
    if not blk_buf^.new_vtoc.entries[k].core.hdr.in_use then begin
      free_vtoce := k;
      exit;
    end;
  if free_vtoce = -1 then begin
    status.all := status_$vtoc_is_bad;
    goto 60;
  end;
  for i := 16 to 83 do
    blk_buf^.new_vtoc.entries[free_vtoce].longs[i] := 0;
  new_vtoce.hdr.type_mode := 1;
  blk_buf^.new_vtoc.entries[free_vtoce].core := new_vtoce;
  if new_blk_flag then
    blk_dirty := bat_buf_writeback
  else
    blk_dirty := bat_buf_dirty;
  dbuf_$set_buff(blk_buf, blk_dirty, status);
  if status.all <> status_$ok then
    goto 70;
  vtoce_loc.block_num := alloc_block;
  vtoce_loc.entry_idx := free_vtoce;
  bkt_buf^.bkt_block.buckets[bucket_idx].slots[free_slot].uid :=
    new_vtoce.id.uid;
  bkt_buf^.bkt_block.buckets[bucket_idx].slots[free_slot].block_info :=
    vtoce_loc;
  dbuf_$set_buff(bkt_buf, bkt_dirty ! 1, status);
  if status.all <> status_$ok then
    goto 80;
  goto 50;

  { the old format's chain of VTOC blocks }
30:
  with vtoc_$vols[vol_idx] do begin
    blk_buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0,
                               status);
    if status.all <> status_$ok then
      goto 90;
    blk_dirty := bat_buf_dirty;
    free_vtoce := -1;
40: with blk_buf^.old_vtoc do begin
      for k := 0 to 4 do begin
        if not entries[k].hdr.in_use then begin
          free_vtoce := k;
          exit;
        end;
        if entries[k].id.uid = new_vtoce.id.uid then begin
          status.all := status_$vtoc_duplicate_uid;
          goto 60;
        end;
      end;
      if free_vtoce >= 0 then
        goto 45;
      alloc_block := block;
      block := next_block;
      if block <> 0 then
        goto 35;
      bat_$allocate(vol_idx, alloc_block, 1, 0, block, status);
      if status.all <> status_$ok then
        goto 60;
      next_block := block;
    end;
    prev_buf := blk_buf;
    blk_buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0,
                               dbuf_get_no_read, status);
    for i := 0 to 255 do
      blk_buf^.longs[i] := 0;
    blocks_added := blocks_added + 1;
    blk_dirty := bat_buf_writeback;
    goto 40;

35: dbuf_$set_buff(blk_buf, bat_buf_clean, status);
    blk_buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0,
                               status);
    if status.all <> status_$ok then
      goto 90;
    goto 40;

45: vtoce_loc.block_num := block;
    vtoce_loc.entry_idx := free_vtoce;
    for i := 1 to 35 do
      blk_buf^.old_vtoc.entries[free_vtoce].fm_longs[i] := 0;
    vtoce_$new_to_old(new_vtoce, false,
                      blk_buf^.old_vtoc.entries[free_vtoce]);
    dbuf_$set_buff(blk_buf, blk_dirty, status);
    if status.all <> status_$ok then
      goto 70;
  end;

  { success }
50:
  if prev_buf <> nil then
    dbuf_$set_buff(prev_buf, bat_buf_dirty, ignored);
  vtoc_$uid_cache_insert(new_vtoce.id.uid, vol_idx, vtoce_loc);
  goto 90;

  { the buffers released }
60:
  if blk_buf <> nil then
    dbuf_$set_buff(blk_buf, bat_buf_clean, ignored);
70:
  if bkt_buf <> nil then
    dbuf_$set_buff(bkt_buf, bkt_dirty, ignored);
80:
  if prev_buf <> nil then
    dbuf_$set_buff(prev_buf, bat_buf_dirty, ignored);

  { the request rewritten }
90:
  ml_$unlock(ml_$vtoc_lock);
  loc.hdr.all := 0;
  loc.hdr.mount_loc := vtoc_$mount_locs[vol_idx];
  loc.block_hint := vtoce_loc;
  loc.port := route_$port[0].network;
  loc.node := node_$me;
  loc.reserved_18 := 0;
  loc.tail.all := 0;
  loc.tail.scratch := true;
  loc.tail.vol_idx := vol_idx;
  loc.tail.kind := 1;
  loc.hdr.kind := 1;
end;
