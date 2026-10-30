{ VTOC_$LOOKUP - find the VTOCE of a UID.

  Image addresses:
    sau2  0x00E38F80  VTOC_$LOOKUP

  - Under ml_$vtoc_lock the UID cache is asked first; else the UID's
    hash chain is walked (new-format buckets, a hit entering the cache,
    or old-format VTOC blocks).
  - On success the request is rewritten with the volume's mount word,
    the node and the volume.

  Status stored:
    status_$ok: the VTOCE was found
    status_$vtoc_not_mounted: the volume is not mounted
    status_$vtoc_invalid_vtoce: the chain ended without the UID
    vtoc_$hash_uid's or dbuf_$get_block's status: that step failed
}

procedure vtoc_$lookup(in out req: vtoc_$lookup_req_t;
                       out status: status_$t);
label
  20, 30;
var
  ignored: status_$t;
  buf: fm_$buffer_ptr_t;
  block: linteger;
  cache_vol: integer;
  bucket_idx: pinteger;
  vol_idx: integer;
  idx: pinteger;
  found: boolean;
  cache_hit: boolean;
  k: 0..19;                               { the scans }
begin
  { the cache }
  ml_$lock(ml_$vtoc_lock);
  vtoc_cach_lookups := vtoc_cach_lookups + 1;
  cache_hit := vtoc_$uid_cache_lookup(req.uid, cache_vol, req.block_hint,
                                      false);
  vol_idx := cache_vol;
  if cache_hit then begin
    vtoc_cach_hits := vtoc_cach_hits + 1;
    status.all := status_$ok;
    goto 20;
  end;

  if not vtoc_$mounted[req.tail.vol_idx] then begin
    status.all := status_$vtoc_not_mounted;
    goto 20;
  end;
  vol_idx := req.tail.vol_idx;
  vtoc_$hash_uid(req.uid, vol_idx, bucket_idx, block, status);
  idx := bucket_idx;
  if status.all <> status_$ok then
    goto 30;

  { the chain }
  found := false;
  repeat
    if vtoc_$format[vol_idx] then begin
      buf := dbuf_$get_block(vol_idx, block, vtoc_bkt_$uid, block, 0, 0,
                             status);
      if status.all <> status_$ok then
        goto 20;
      with buf^.bkt_block.buckets[idx] do begin
        for k := 0 to 19 do
          if (slots[k].block_info.all <> 0) and then
             (slots[k].uid = req.uid) then begin
            req.block_hint := slots[k].block_info;
            found := true;
            vtoc_$uid_cache_insert(req.uid, vol_idx, req.block_hint);
            exit;
          end;
        block := next_bucket;
        idx := next_bkt_idx;
      end;
    end
    else begin
      buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0,
                             status);
      if status.all <> status_$ok then
        goto 20;
      with buf^.old_vtoc do begin
        for k := 0 to 4 do
          if entries[k].hdr.in_use and then
             (entries[k].id.uid = req.uid) then begin
            req.block_hint.block_num := block;
            req.block_hint.entry_idx := k;
            found := true;
            exit;
          end;
        block := next_block;
      end;
    end;
    dbuf_$set_buff(buf, bat_buf_clean, ignored);
  until found or else (block = 0);
  if not found then
    status.all := status_$vtoc_invalid_vtoce;

  { the request rewritten }
20:
  if status.all = status_$ok then begin
    req.hdr.all := 0;
    req.hdr.mount_loc := vtoc_$mount_locs[req.tail.vol_idx];
    req.port := route_$port[0].network;
    req.node := node_$me;
    req.reserved_18 := 0;
    req.tail.all := 0;
    req.tail.scratch := true;
    req.tail.vol_idx := vol_idx;
    req.tail.kind := 1;
    req.hdr.kind := 1;
  end;

30:
  ml_$unlock(ml_$vtoc_lock);
end;
