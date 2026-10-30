{ BAT_$RESERVE - move blocks from a volume's free pool to its reserved
  pool.

  Image addresses:
    sau2  0x00E3BA74  BAT_$RESERVE

  - Under the BAT lock; an old-format volume keeps 11 free blocks back.

  Status stored:
    status_$ok: the blocks were reserved
    status_$disk_is_full: the free pool cannot give the count
}

procedure bat_$reserve(vol_idx: integer; count: linteger;
                       out status: status_$t);
begin
  ml_$lock(ml_$bat_lock);

  with bat_data[vol_idx], hdr do
    if ((not bat_$volume_flags[vol_idx]) and (count + 11 > free_blocks))
       or else (bat_$volume_flags[vol_idx]
                and then (count > free_blocks)) then
      status.all := status_$disk_is_full
    else begin
      free_blocks := free_blocks - count;
      reserved_blocks := reserved_blocks + count;
      status.all := status_$ok;
    end;

  ml_$unlock(ml_$bat_lock);
end;
