{ WIN8_$GET_STATS - the statistics entry.

  Image addresses:
    sau8  0x03C1AEE4  WIN8_$GET_STATS

  - Controller 0, drive 0 or 1 gets the drive's 22 bytes of statistics;
    any other pair 22 zero bytes (the zero fill: see the TODO(pascal) in
    win/get_stats.pas).

  Status stored: none.
}

procedure win8_$get_stats(cnum: integer; unit: pinteger;
                          out stats: win_$stats_t);
  options(val_param);
var
  zero: win_$stats_t;
begin
  if (cnum = 0) and then (unit <= 1) then
    stats := win_stats[unit].stats
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
end;
