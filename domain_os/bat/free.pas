{ BAT_$FREE - return blocks to a volume's pool.

  Image addresses:
    sau2  0x00E3B516  BAT_$FREE

  - Under the BAT lock.  A 0 in the list moves a reserved block to the
    free pool; other blocks have their bitmap bits set, through the one
    cached bitmap block, and their pool's and partition's counts raised.
  - A bad block does not stop the walk; a failure to read a bitmap block
    does.

  Status stored:
    status_$ok: the blocks were freed
    status_$bat_not_mounted: the volume is not mounted
    bat_$invalid_block: a block is outside the volume
    bat_$error: a block is free already, or no block is reserved
    dbuf's status: a bitmap block could not be read or released, and the
      status is still status_$ok
}

procedure bat_$free(in blocks: univ linteger; count: integer;
                    vol_idx: integer; reserved: integer;
                    out status: status_$t);
label
  done;
var
  local_status: status_$t;
  i: integer;                             { its count in the frame }
  cursor: integer32;
  block: linteger;
  rel: linteger;
  bit_offset: pinteger;
  word_offset: integer;
  bat_block: linteger;
  bitmap_word: bat_$bitmap_word_t;
  part: integer;
begin
  ml_$lock(ml_$bat_lock);
  local_status.all := status_$ok;
  status.all := status_$ok;

  if not bat_$mounted[vol_idx] then begin
    ml_$unlock(ml_$bat_lock);
    status.all := status_$bat_not_mounted;
    return;
  end;

  with bat_data[vol_idx], hdr, ptab do begin
    cursor := integer32(addr(blocks));
    for i := 1 to count do begin
      block := bat_$long_ptr_t(cursor)^;
      if block = 0 then begin
        if reserved = 0 then
          if reserved_blocks = 0 then
            status.all := bat_$error
          else begin
            free_blocks := free_blocks + 1;
            reserved_blocks := reserved_blocks - 1;
          end;
      end
      else begin
        rel := block - first_data_block;
        if (rel < 0) or else (rel >= total_blocks) then
          status.all := bat_$invalid_block
        else begin
          bit_offset := rel & 16#1F;
          word_offset := (rel div 32) & 16#FF;
          bat_block := bat_block_start + rel div 8192;

          if (bat_block <> bat_$cached_block)
             or else (bat_$cached_vol <> vol_idx) then begin
            if bat_$cached_buffer <> nil then
              dbuf_$set_buff(bat_$cached_buffer, bat_$cached_dirty,
                             local_status);
            bat_$cached_buffer := dbuf_$get_block(vol_idx, bat_block,
                                                  bat_$uid, bat_block, 0, 0,
                                                  local_status);
            if local_status.all <> status_$ok then begin
              bat_$cached_buffer := nil;
              bat_$cached_vol := 0;
              goto done;
            end;
            bat_$cached_vol := vol_idx;
            bat_$cached_block := bat_block;
          end;

          bat_$cached_dirty := bat_buf_dirty;
          bitmap_word := bat_$cached_buffer^[word_offset];
          if partition_start_offset > block then
            part := 0
          else
            part := (block - partition_start_offset) div partition_size;

          if bit_offset in bitmap_word then
            status.all := bat_$error
          else begin
            bat_$cached_buffer^[word_offset] := [bit_offset] + bitmap_word;
            if reserved = 0 then
              free_blocks := free_blocks + 1
            else
              reserved_blocks := reserved_blocks + 1;
            partitions[part].free_count := partitions[part].free_count + 1;
          end;
        end;
      end;

      cursor := cursor + 4;
    end;
  end;

done:
  ml_$unlock(ml_$bat_lock);
  if (local_status.all <> status_$ok) and then (status.all = status_$ok) then
    status := local_status;
end;
