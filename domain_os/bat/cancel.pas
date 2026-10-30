{ BAT_$CANCEL - move blocks from a volume's reserved pool back to its
  free pool.

  Image addresses:
    sau2  0x00E3BAF6  BAT_$CANCEL

  - Under the BAT lock.

  Status stored:
    status_$ok: the blocks were moved
    bat_$error: the reserved pool does not hold the count
}

procedure bat_$cancel(vol_idx: integer; count: linteger;
                      out status: status_$t);
begin
  ml_$lock(ml_$bat_lock);
  status.all := status_$ok;

  with bat_data[vol_idx], hdr do
    if count > reserved_blocks then
      status.all := bat_$error
    else begin
      free_blocks := free_blocks + count;
      reserved_blocks := reserved_blocks - count;
    end;

  ml_$unlock(ml_$bat_lock);
end;
