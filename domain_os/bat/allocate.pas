{ BAT_$ALLOCATE - allocate blocks from a volume's BAT bitmap.

  Image addresses:
    sau2  0x00E3B0D6  BAT_$ALLOCATE

  - Under the BAT lock.  The walk starts at the hint's allocation chunk
    and partition, through the one cached bitmap block; a set bit is a
    free block.
  - A stride counter, rearmed from the volume's step, spreads the blocks
    taken; a chunk, then a partition, is swept again while it has free
    blocks, the partitions wrapping.
  - The free pool keeps 11 blocks back on an old-format volume.

  Status stored:
    status_$ok: the blocks were allocated
    status_$bat_not_mounted: the volume is not mounted
    status_$disk_is_full: the pool asked for cannot give the count
    dbuf_$get_block's status: a bitmap block could not be read
}

procedure bat_$allocate(vol_idx: integer; hint: linteger;
                        alloc_count: integer; use_reserved: integer;
                        out blocks_out: univ linteger;
                        out status: status_$t);
label
  done;
var
  set_status: status_$t;
  bitmap_word: bat_$bitmap_word_t;
  step_remaining: integer32;
  partition_end: linteger;
  partition_start: linteger;
  chunk_end: linteger;
  allocated: integer;
  partition_idx: integer;
  rescan_chunk: boolean;
  out_ptr: integer32;
  rel_block: linteger;
  word_offset: pinteger;
  bat_block: linteger;
  chunk_start: linteger;
  bit_offset: pinteger;
begin
  ml_$lock(ml_$bat_lock);
  if not bat_$mounted[vol_idx] then begin
    status.all := status_$bat_not_mounted;
    goto done;
  end;

  with bat_data[vol_idx], hdr, ptab do begin
    if use_reserved = 0 then begin
      if ((alloc_count > free_blocks - 11)
          and not bat_$volume_flags[vol_idx])
         or else (bat_$volume_flags[vol_idx]
                  and then (alloc_count > free_blocks)) then begin
        status.all := status_$disk_is_full;
        goto done;
      end;
    end
    else if alloc_count > reserved_blocks then begin
      status.all := status_$disk_is_full;
      goto done;
    end;

    if hint < first_data_block then
      rel_block := 0
    else
      rel_block := hint - first_data_block;
    if rel_block >= total_blocks then
      rel_block := total_blocks - 1;

    step_remaining := step_long - 1;
    allocated := 0;

    if rel_block + first_data_block
       < partition_start_offset + partition_size then begin
      partition_idx := 0;
      partition_start := 0;
      partition_end := partition_start_offset + partition_size
                       - first_data_block;
    end
    else begin
      partition_idx := (rel_block + first_data_block
                        - partition_start_offset) div partition_size;
      partition_start := partition_start_offset
                         + partition_size * partition_idx
                         - first_data_block;
      partition_end := partition_start + partition_size;
    end;

    if rel_block < alloc_chunk_offset then begin
      chunk_start := 0;
      chunk_end := alloc_chunk_offset;
    end
    else begin
      chunk_start := (rel_block - alloc_chunk_offset) div alloc_chunk_size
                     * alloc_chunk_size + alloc_chunk_offset;
      chunk_end := chunk_start + alloc_chunk_size;
    end;

    if total_blocks < chunk_end then
      chunk_end := total_blocks;
    if total_blocks < partition_end then
      partition_end := total_blocks;

    bat_block := bat_block_start + rel_block div 8192;
    word_offset := (rel_block div 32) & 16#FF;
    bit_offset := rel_block & 16#1F;
    rescan_chunk := true;
    if bat_$cached_buffer <> nil then
      bitmap_word := bat_$cached_buffer^[word_offset];
    status.all := status_$ok;
    out_ptr := integer32(addr(blocks_out));

    repeat
      if (bat_block <> bat_$cached_block)
         or else (bat_$cached_vol <> vol_idx) then begin
        if bat_$cached_buffer <> nil then
          dbuf_$set_buff(bat_$cached_buffer, bat_$cached_dirty, set_status);
        bat_$cached_buffer := dbuf_$get_block(vol_idx, bat_block, bat_$uid,
                                              bat_block, 0, 0, status);
        if status.all <> status_$ok then begin
          bat_$cached_buffer := nil;
          bat_$cached_vol := 0;
          goto done;
        end;
        bat_$cached_vol := vol_idx;
        bat_$cached_block := bat_block;
        bat_$cached_dirty := bat_buf_clean;
        bitmap_word := bat_$cached_buffer^[word_offset];
      end;

      if bitmap_word = [] then begin
        rel_block := rel_block + (32 - bit_offset);
        step_remaining := step_remaining - (32 - bit_offset);
        bit_offset := 32;
      end
      else begin
        if bit_offset in bitmap_word then
          if step_remaining <= 0 then begin
            bitmap_word := bitmap_word - [bit_offset];
            bat_$cached_buffer^[word_offset] := bitmap_word;
            bat_$cached_dirty := bat_buf_dirty;
            bat_$long_ptr_t(out_ptr)^ := rel_block + first_data_block;
            allocated := allocated + 1;
            out_ptr := out_ptr + 4;
            partitions[partition_idx].free_count :=
              partitions[partition_idx].free_count - 1;
            if allocated >= alloc_count then
              exit;
            step_remaining := step_long;
          end
          else
            rescan_chunk := true;
        bit_offset := bit_offset + 1;
        rel_block := rel_block + 1;
        step_remaining := step_remaining - 1;
      end;

      if rel_block >= chunk_end then begin
        if rescan_chunk then begin
          rel_block := chunk_start;
          rescan_chunk := false;
        end
        else if rel_block >= partition_end then begin
          if partitions[partition_idx].free_count <> 0 then
            rel_block := partition_start
          else begin
            partition_idx := partition_idx + 1;
            if partition_idx >= num_partitions then begin
              rel_block := 0;
              partition_idx := 0;
              partition_start := 0;
              partition_end := partition_start_offset + partition_size
                               - first_data_block;
            end
            else begin
              partition_start := partition_end;
              partition_end := partition_start + partition_size;
            end;
            if partition_end > total_blocks then
              partition_end := total_blocks;
          end;
          if rel_block < alloc_chunk_offset then begin
            chunk_start := 0;
            chunk_end := alloc_chunk_offset;
          end
          else begin
            chunk_start := (rel_block - alloc_chunk_offset)
                           div alloc_chunk_size * alloc_chunk_size
                           + alloc_chunk_offset;
            chunk_end := chunk_start + alloc_chunk_size;
          end;
        end
        else if rel_block >= total_blocks then begin
          chunk_start := 0;
          chunk_end := alloc_chunk_offset;
        end
        else begin
          chunk_start := chunk_end;
          chunk_end := chunk_start + alloc_chunk_size;
        end;

        if total_blocks < chunk_end then
          chunk_end := total_blocks;
        bat_block := bat_block_start + rel_block div 8192;
        word_offset := (rel_block div 32) & 16#FF;
        bit_offset := rel_block & 16#1F;
        if bat_block = bat_$cached_block then
          bitmap_word := bat_$cached_buffer^[word_offset];
      end
      else if bit_offset >= 32 then begin
        word_offset := word_offset + 1;
        if word_offset = 256 then begin
          bat_block := bat_block + 1;
          word_offset := 0;
        end
        else
          bitmap_word := bat_$cached_buffer^[word_offset];
        bit_offset := bit_offset - 32;
      end;
    until false;

    if use_reserved = 0 then
      free_blocks := free_blocks - allocated
    else
      reserved_blocks := reserved_blocks - allocated;
  end;

done:
  ml_$unlock(ml_$bat_lock);
end;
