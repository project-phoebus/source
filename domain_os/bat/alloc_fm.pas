{ BAT_$ALLOC_FM - allocate one block in the partition with the most room.

  Image addresses:
    sau2  0x00E3AD20  BAT_$ALLOC_FM

  - The partition is chosen under the BAT lock, from the middle one: a
    state-1 partition (a VTOCE chain) more than a quarter free at once,
    else the largest free count, any other's counting half.
  - BAT_$ALLOCATE takes the block near that partition's start after the
    lock; the result is the block.

  Status stored:
    bat_$allocate's status: always
}

function bat_$alloc_fm(vol_idx: integer; out status: status_$t): linteger;
var
  block: linteger;
  threshold: linteger;
  search_idx: integer;
  best_idx: integer;
  best_count: integer;
  i: integer;
begin
  ml_$lock(ml_$bat_lock);
  status.all := status_$ok;

  with bat_data[vol_idx], ptab do begin
    threshold := partition_size div 4;
    search_idx := num_partitions div 2;
    best_count := 0;
    best_idx := 0;

    for i := 1 to num_partitions do begin
      if partitions[search_idx].state = 1 then begin
        if threshold < partitions[search_idx].free_count then begin
          best_idx := search_idx;
          exit;
        end;
        if best_count < partitions[search_idx].free_count then begin
          best_count := partitions[search_idx].free_count;
          best_idx := search_idx;
        end;
      end
      else if partitions[search_idx].free_count div 2 > best_count then begin
        best_idx := search_idx;
        best_count := partitions[search_idx].free_count div 2;
      end;
      search_idx := search_idx + 1;
      if search_idx >= num_partitions then
        search_idx := 0;
    end;

    if best_idx = 0 then
      block := 0
    else
      block := partition_size * best_idx + partition_start_offset;
  end;

  ml_$unlock(ml_$bat_lock);
  bat_$allocate(vol_idx, block, 1, 0, block, status);
  bat_$alloc_fm := block;
end;
