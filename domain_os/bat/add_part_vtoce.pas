{ BAT_$ADD_PART_VTOCE - make a block the head of its partition's VTOCE
  chain.

  Image addresses:
    sau2  0x00E3AE2E  BAT_$ADD_PART_VTOCE

  - Under the BAT lock; the result is the old head, the chain word's low
    24 bits.  The block goes under the chain's state byte unmasked.

  Status stored:
    status_$ok: always
}

function bat_$add_part_vtoce(vol_idx: integer; block: linteger;
                             out status: status_$t): integer32;
var
  part: integer;
begin
  ml_$lock(ml_$bat_lock);
  status.all := status_$ok;

  with bat_data[vol_idx], ptab do begin
    if partition_start_offset > block then
      part := 0
    else
      part := (block - partition_start_offset) div partition_size;

    bat_$add_part_vtoce := partitions[part].chain & 16#FFFFFF;
    partitions[part].chain := partitions[part].chain & (-16#1000000);
    partitions[part].chain := partitions[part].chain ! block;
  end;

  ml_$unlock(ml_$bat_lock);
end;
