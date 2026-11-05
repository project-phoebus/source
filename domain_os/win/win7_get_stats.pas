{ WIN7_$GET_STATS - the statistics entry.

  Image addresses:
    sau7  0x3C41BBF0  WIN7_$GET_STATS

  - Under ml_$win_stats_lock.  Controller 0 or 1, drive 0 or 1 gets the
    drive's 22 bytes of statistics; any other pair 22 zero bytes (the
    zero fill: see the TODO(pascal) in win/get_stats.pas).

  Status stored: none.
}

procedure win7_$get_stats(cnum: pinteger; unit: pinteger;
                          out stats: win_$stats_t);
  options(val_param);
var
  zero: win_$stats_t;
begin
  ml_$lock(ml_$win_stats_lock);
  if (cnum <= 1) and (unit <= 1) then
    stats := win7_ctlrs[cnum]^.drives[unit].stats
  else begin
    zero.reads := 0;
    zero.writes := 0;
    zero.w_08 := 0;
    zero.timeouts := 0;
    zero.seek_errors := 0;
    zero.equip_checks := 0;
    zero.not_ready := 0;
    zero.data_checks := 0;
    zero.late_completions := 0;
    stats := zero;
  end;
  ml_$unlock(ml_$win_stats_lock);
end;
