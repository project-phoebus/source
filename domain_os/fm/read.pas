{ FM_$READ - read one file-map entry out of a VTOC block or a file-map
  block.

  Image addresses:
    sau2  0x00E3A314  FM_$READ

  - Under the VTOC lock.  Level 0 reads a VTOCE's direct addresses in
    the volume's format, another level an entry of a file-map block,
    through the buffer cache.
  - Block 1, entry 15 of a write-protected volume reads as zeros.
  - A fragment of the VTOC_ module (fm/README.md).

  Status stored:
    dbuf_$get_block's or dbuf_$set_buff's status: the entry was read,
      or not
    status_$ok: block 1, entry 15 of a write-protected volume
    status_$vtoc_not_mounted: the volume is not mounted
}

procedure fm_$read(in file_ref: fm_$file_ref_t;
                   block_addr: fm_$block_addr_t;
                   level: pinteger;
                   out entry_out: fm_$entry_t;
                   out status: status_$t);
  options(val_param);
var
  local_uid: uid_$t;
  block_num: linteger;
  src: fm_$entry_ptr_t;
  hint: integer32;
  buffer: fm_$buffer_ptr_t;
  vol_idx: integer;
  block_type: integer;
  entry_idx: integer;
  i: integer;                             { the zero fill's index }
begin
  vol_idx := file_ref.vol_idx;
  block_num := block_addr.block_num;
  entry_idx := block_addr.entry_idx;
  ml_$lock(ml_$vtoc_lock);

  if not vtoc_$mounted[vol_idx] then
    status.all := status_$vtoc_not_mounted

  { block 1, entry 15 of a write-protected volume reads as zeros }
  else if vtoc_$cach_wp_flag[vol_idx] and then (block_num = 1)
          and then (entry_idx = 15) then begin
    status.all := status_$ok;
    for i := 0 to 31 do
      entry_out.blocks[i] := 0;
  end

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
        src := addr(buffer^.fm_block[entry_idx])
      else if vtoc_$format[vol_idx] then
        src := addr(buffer^.new_vtoc.entries[entry_idx].direct)
      else
        src := addr(buffer^.old_vtoc.entries[entry_idx].direct);
      entry_out := src^;
      dbuf_$set_buff(buffer, fm_buf_release, status);
    end;
  end;

  ml_$unlock(ml_$vtoc_lock);
end;
