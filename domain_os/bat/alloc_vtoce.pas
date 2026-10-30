{ BAT_$ALLOC_VTOCE - find or make room for a VTOCE and return its block.

  Image addresses:
    sau2  0x00E3AEC0  BAT_$ALLOC_VTOCE

  - The partition: the hint's if an eighth of it is free, else by a walk
    outward from the middle (a state-2 partition more than an eighth free
    at once, else the largest free count).
  - A chain with no head gets a new block from BAT_$ALLOCATE, called with
    the BAT lock released; new_vtoce says so.
  - The result is the VTOCE block's buffer, still held; nil on a
    failure.

  Status stored:
    dbuf_$get_block's status: the block's buffer was got, or not
    bat_$allocate's status: a new block could not be allocated
}

function bat_$alloc_vtoce(vol_idx: integer; hint: linteger;
                          out block_out: linteger; out status: status_$t;
                          out new_vtoce: boolean): univ_ptr;
label
  done;
var
  alloc_hint: linteger;
  best_free: integer32;
  result: univ_ptr;
  threshold: linteger;
  part_idx: integer;
  search_idx: integer;
  direction: integer;                     { the `for' index }
  flags: integer;
  vtoce: bat_$vtoce_block_ptr_t;
  ptr: integer32;
  i: integer;                             { the clearing loop's index }
begin
  result := nil;
  new_vtoce := false;
  ml_$lock(ml_$bat_lock);

  with bat_data[vol_idx], ptab do begin
    threshold := partition_size div 8;
    part_idx := -1;
    alloc_hint := hint;
    if hint <> 0 then begin
      if partition_start_offset > hint then
        part_idx := 0
      else
        part_idx := (hint - partition_start_offset) div partition_size;
      if (part_idx >= num_partitions)
         or else (threshold > partitions[part_idx].free_count) then
        part_idx := -1;
    end;

    if part_idx = -1 then begin
      search_idx := num_partitions div 2;
      best_free := -1;
      for direction := 1 to num_partitions do begin
        if (partitions[search_idx].state = 2)
           and then (threshold < partitions[search_idx].free_count) then begin
          part_idx := search_idx;
          exit;
        end;
        if partitions[search_idx].free_count > best_free then begin
          part_idx := search_idx;
          best_free := partitions[search_idx].free_count;
        end;
        if odd(direction) then
          search_idx := search_idx - direction
        else
          search_idx := search_idx + direction;
      end;
      if part_idx = 0 then
        alloc_hint := 0
      else
        alloc_hint := partition_size * part_idx + partition_start_offset;
    end;

    with partitions[part_idx] do begin
      if (chain & 16#FFFFFF) = 0 then begin
        ml_$unlock(ml_$bat_lock);
        bat_$allocate(vol_idx, alloc_hint, 1, 0, block_out, status);
        ml_$lock(ml_$bat_lock);
        if status.all <> status_$ok then
          goto done;
        flags := dbuf_get_no_read;
      end
      else begin
        block_out := chain & 16#FFFFFF;
        flags := 0;
      end;

      vtoce := dbuf_$get_block(vol_idx, block_out, vtoc_$uid, block_out,
                               0, flags, status);
      if status.all <> status_$ok then
        goto done;

      if flags = dbuf_get_no_read then begin
        ptr := integer32(addr(vtoce^));
        for i := 1 to 254 do begin
          bat_$long_ptr_t(ptr)^ := 0;
          ptr := ptr + 4;
        end;
        vtoce^.magic := vtoce_magic;
        vtoce^.self_block := block_out;
        new_vtoce := true;
        chain := chain & (-16#1000000);
        chain := chain ! block_out;
      end;

      vtoce^.entry_count := vtoce^.entry_count + 1;
      if vtoce^.entry_count = vtoce_entries_per_block then begin
        chain := chain & (-16#1000000);
        chain := chain ! vtoce^.next_vtoce;
      end;
      result := vtoce;
    end;
  end;

done:
  ml_$unlock(ml_$bat_lock);
  bat_$alloc_vtoce := result;
end;
