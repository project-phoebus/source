{ VTOCE_$WRITE - write a VTOCE back.

  Image addresses:
    sau2  0x00E396D6  VTOCE_$WRITE

  - Under ml_$vtoc_lock the VTOCE is stored in its block (its read-only
    bit cleared, or converted for the old format), released dirty, or
    written back at once with flags.
  - On a write-protected volume the write is dropped with status_$ok.

  Status stored:
    status_$ok: a write-protected volume
    dbuf_$set_buff's status: the VTOCE was stored
    status_$vtoc_not_mounted: the volume is not mounted
    dbuf_$get_block's status: the block could not be read
}

procedure vtoce_$write(in req: vtoc_$lookup_req_t; in data: vtoce_$t;
                       flags: boolean; out status: status_$t);
var
  blk_dirty: integer;
  block: linteger;
  vol_idx: integer;
  entry: pinteger;
  buf: fm_$buffer_ptr_t;
begin
  vol_idx := req.tail.vol_idx;
  if flags then
    blk_dirty := bat_buf_writeback
  else
    blk_dirty := bat_buf_dirty;
  block := req.block_hint.block_num;
  entry := req.block_hint.entry_idx;

  ml_$lock(ml_$vtoc_lock);
  if not vtoc_$mounted[vol_idx] then
    status.all := status_$vtoc_not_mounted
  else if vtoc_$cach_wp_flag[vol_idx] then
    status.all := status_$ok
  else begin
    buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0, status);
    if status.all = status_$ok then begin
      if vtoc_$format[vol_idx] then begin
        buf^.new_vtoc.entries[entry].core := data;
        buf^.new_vtoc.entries[entry].core.hdr.read_only := false;
      end
      else
        vtoce_$new_to_old(data, false, buf^.old_vtoc.entries[entry]);
      dbuf_$set_buff(buf, blk_dirty, status);
    end;
  end;
  ml_$unlock(ml_$vtoc_lock);
end;
