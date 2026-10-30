{ VTOC_$GET_UID - the UID of a VTOCE given by its position.

  Image addresses:
    sau2  0x00E391F2  VTOC_$GET_UID

  - Under ml_$vtoc_lock the index is mapped through the partitions to a
    block (new format: its low two bits the bucket), and the bucket or
    VTOC block chain followed, 20 slots or 5 entries a block.
  - On the not-mounted path buf is released before it is set.

  Status stored:
    status_$ok: the UID was found (the last read's status)
    status_$vtoc_not_mounted: the volume is not mounted
    status_$vtoc_not_found: the chain ended
    status_$vtoc_no_uid: an empty slot or free entry, or the volume's
      current VTOCE
    dbuf_$get_block's or dbuf_$set_buff's status: a block failed
}

procedure vtoc_$get_uid(vol_idx: integer; vtoc_idx: pinteger;
                        entry_idx: pinteger; out uid_ret: uid_$t;
                        out status_ret: status_$t);
label
  90;
var
  local_uid: uid_$t;
  ignored: status_$t;
  status: status_$t;
  bucket_idx: pinteger;
  part_limit: integer;
  part: integer;
  block: linteger;
  prev_block: linteger;
  info: fm_$block_addr_t;
  buf: fm_$buffer_ptr_t;
begin
  bucket_idx := vtoc_idx;
  if vtoc_$format[vol_idx] then begin
    part_limit := 9;
    bucket_idx := vtoc_idx & 3;
    vtoc_idx := rshft(vtoc_idx, 2);
    local_uid := vtoc_bkt_$uid;
  end
  else begin
    part_limit := 7;
    local_uid := vtoc_$uid;
  end;

  ml_$lock(ml_$vtoc_lock);
  with vtoc_$vols[vol_idx] do begin
    if not vtoc_$mounted[vol_idx] then begin
      status.all := status_$vtoc_not_mounted;
      goto 90;
    end;
    block := 0;
    for part := 0 to part_limit do begin
      if vtoc_idx < parts[part].count then begin
        block := vtoc_idx + parts[part].base;
        exit;
      end;
      vtoc_idx := vtoc_idx - parts[part].count;
    end;
  end;
  buf := nil;

  { the chain }
  repeat
    if block = 0 then begin
      status.all := status_$vtoc_not_found;
      goto 90;
    end;
    if buf <> nil then
      dbuf_$set_buff(buf, bat_buf_clean, status);
    buf := dbuf_$get_block(vol_idx, block, local_uid, block, 0, 0, status);
    if status.all <> status_$ok then
      goto 90;
    if vtoc_$format[vol_idx] then begin
      with buf^.bkt_block.buckets[bucket_idx] do begin
        block := next_bucket;
        bucket_idx := next_bkt_idx;
        if entry_idx < 20 then begin
          local_uid := slots[entry_idx].uid;
          info := slots[entry_idx].block_info;
          if (info.all = 0) or else
             (info.all = vtoc_$vols[vol_idx].current_vtoce.all) then
            status.all := status_$vtoc_no_uid;
          goto 90;
        end;
        entry_idx := entry_idx - 20;
      end;
    end
    else begin
      prev_block := block;
      block := buf^.old_vtoc.next_block;
      if entry_idx < 5 then begin
        with buf^.old_vtoc.entries[entry_idx] do begin
          local_uid := id.uid;
          if (not hdr.in_use) or else
             ((vtoc_$vols[vol_idx].current_vtoce.block_num = prev_block)
              and then
              (vtoc_$vols[vol_idx].current_vtoce.entry_idx = entry_idx)) then
            status.all := status_$vtoc_no_uid;
        end;
        goto 90;
      end;
      entry_idx := entry_idx - 5;
    end;
  until false;

90:
  if buf <> nil then
    dbuf_$set_buff(buf, bat_buf_clean, ignored);
  ml_$unlock(ml_$vtoc_lock);
  uid_ret := local_uid;
  status_ret := status;
end;
