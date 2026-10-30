{ FM_$WRITE - write one file-map entry into a VTOC block or a file-map
  block.

  Image addresses:
    sau2  0x00E3A45C  FM_$WRITE

  - Under the VTOC lock, as FM_$READ; write_now writes the block back at
    once, else it is marked dirty.  A write-protected volume is not
    written.

  Status stored:
    dbuf_$get_block's or dbuf_$set_buff's status: the entry was written,
      or not
    status_$ok: the volume is write-protected
    status_$vtoc_not_mounted: the volume is not mounted
}

procedure fm_$write(in file_ref: fm_$file_ref_t;
                    block_addr: fm_$block_addr_t;
                    level: pinteger;
                    in entry_in: fm_$entry_t;
                    write_now: boolean;
                    out status: status_$t);
  options(val_param);
var
  local_uid: uid_$t;
  block_num: linteger;
  hint: integer32;
  buffer: fm_$buffer_ptr_t;
  vol_idx: integer;
  buf_flags: integer;
  block_type: integer;
  entry_idx: integer;
begin
  vol_idx := file_ref.vol_idx;
  if write_now then
    buf_flags := fm_buf_writeback
  else
    buf_flags := fm_buf_dirty;
  block_num := block_addr.block_num;
  entry_idx := block_addr.entry_idx;
  ml_$lock(ml_$vtoc_lock);

  if not vtoc_$mounted[vol_idx] then
    status.all := status_$vtoc_not_mounted

  { a write-protected volume is not written }
  else if vtoc_$cach_wp_flag[vol_idx] then
    status.all := status_$ok

  else begin
    if level = 0 then begin
      hint := block_num;
      block_type := 0;
      local_uid := vtoc_$uid;
    end
    else begin
      hint := ((level - 1) div 8) * 256 + 32;
      block_type := 1;
      local_uid := file_ref.file_uid;
    end;

    buffer := dbuf_$get_block(vol_idx, block_num, local_uid, hint,
                              block_type, 0, status);

    if status.all = status_$ok then begin
      if level <> 0 then
        buffer^.fm_block[entry_idx] := entry_in
      else if vtoc_$format[vol_idx] then
        buffer^.new_vtoc.entries[entry_idx].direct := entry_in
      else
        buffer^.old_vtoc.entries[entry_idx].direct := entry_in;
      dbuf_$set_buff(buffer, buf_flags, status);
    end;
  end;

  ml_$unlock(ml_$vtoc_lock);
end;
