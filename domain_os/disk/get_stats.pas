{ DISK_$GET_STATS - a driver's statistics.

  Image addresses:
    sau2  0x00E3DB9C  DISK_$GET_STATS

  - The block is first the zero template and the flag false.
  - A registered entry of the controller type and number whose driver
    has a get_stats entry fills it for the unit; the flag says whether a
    transfer count is nonzero.

  Status stored: none.
}

procedure disk_$get_stats(ctype: integer; cnum: integer; unit: integer;
                          out has_stats: boolean;
                          out stats: disk_$stats_t);
var
  stats_template: static disk_$stats_t;   { +0x180 of the block, zero }
  i: integer;
begin
  has_stats := false;
  stats := stats_template;

  for i := 1 to 32 do
    if disk_$devices[i].jump_table <> nil then
      with disk_$devices[i] do
        if (device_type = ctype) and then (controller = cnum) then begin
          if disk_$jump_table_ptr_t(jump_table)^.get_stats <> nil then begin
            disk_$get_stats_proc_t(
              disk_$jump_table_ptr_t(jump_table)^.get_stats)^(
                cnum, unit, stats);
            has_stats := (stats.xfers[1] <> 0) or (stats.xfers[2] <> 0);
          end;
          return;
        end;
end;
