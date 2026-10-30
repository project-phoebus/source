{ VTOCE_$READ - read a VTOCE.

  Image addresses:
    sau2  0x00E394EC  VTOCE_$READ

  - Under ml_$vtoc_lock the VTOCE is read (an old-format one converted),
    marked read-only as the volume is, and the request rewritten; a
    new-format block's in-use entries enter the UID cache.

  Status stored:
    dbuf_$set_buff's status: the VTOCE was read
    status_$vtoc_not_mounted: a diskless node, or the volume is not
      mounted
    status_$vtoc_uid_mismatch: the VTOCE's UID is not the request's
    dbuf_$get_block's status: the block could not be read
}

procedure vtoce_$read(in out req: vtoc_$lookup_req_t; out result: vtoce_$t;
                      out status: status_$t);
label
  90;
var
  loc: fm_$block_addr_t;
  block: linteger;
  vol_idx: integer;
  entry: pinteger;
  buf: fm_$buffer_ptr_t;
  k: 0..2;
begin
  vol_idx := req.tail.vol_idx;
  if network_$really_diskless then begin
    status.all := status_$vtoc_not_mounted;
    return;
  end;
  block := req.block_hint.block_num;
  entry := req.block_hint.entry_idx;

  ml_$lock(ml_$vtoc_lock);
  if not vtoc_$mounted[vol_idx] then begin
    status.all := status_$vtoc_not_mounted;
    goto 90;
  end;
  if netlog_$ok_to_log then
    netlog_$log_it(16#11, req.uid, 0, 0, vol_idx, 0, 0, 0);
  buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0, status);
  if status.all = status_$ok then begin
    { the entry, read-only as the volume }
    if vtoc_$format[vol_idx] then
      result := buf^.new_vtoc.entries[entry].core
    else
      vtoce_$old_to_new(buf^.old_vtoc.entries[entry], result);
    result.hdr.read_only := vtoc_$cach_wp_flag[vol_idx];

    { the request rewritten }
    req.hdr.all := 0;
    req.hdr.mount_loc := vtoc_$mount_locs[vol_idx];
    req.port := route_$port[0].network;
    req.node := node_$me;
    req.reserved_18 := 0;
    req.tail.all := 0;
    req.tail.scratch := true;
    req.tail.vol_idx := vol_idx;
    req.tail.kind := 1;
    req.hdr.kind := 1;

    { the block's entries into the cache }
    if vtoc_$format[vol_idx] then begin
      loc.block_num := req.block_hint.block_num;
      for k := 0 to 2 do
        if buf^.new_vtoc.entries[k].core.hdr.in_use then begin
          loc.entry_idx := k;
          vtoc_$uid_cache_insert(buf^.new_vtoc.entries[k].core.id.uid,
                                 vol_idx, loc);
        end;
    end;

    dbuf_$set_buff(buf, bat_buf_clean, status);
    if (req.uid <> result.id.uid) and then (req.uid <> uid_$nil) then
      status.all := status_$vtoc_uid_mismatch;
  end;

90:
  ml_$unlock(ml_$vtoc_lock);
end;
