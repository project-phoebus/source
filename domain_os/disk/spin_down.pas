{ DISK_$SPIN_DOWN - spin down every drive and wait for the slowest.

  Image addresses:
    sau2  0x00E3DB04  DISK_$SPIN_DOWN

  - Every registered driver's spin_down entry is called; the longest of
    the times they return, if positive, is waited for (four clock ticks
    a unit).

  Status stored: none.
}

procedure disk_$spin_down;
var
  max_time: integer;
  i: integer;
  t: integer;
  status: status_$t;
  delay: time_$clock_t;
begin
  max_time := 0;

  { each driver's spin down }
  for i := 1 to 32 do
    if disk_$devices[i].jump_table <> nil then
      with disk_$devices[i] do
        if disk_$jump_table_ptr_t(jump_table)^.spin_down <> nil then begin
          t := disk_$spin_down_proc_t(
                 disk_$jump_table_ptr_t(jump_table)^.spin_down)^(controller);
          if max_time < t then
            max_time := t;
        end;

  if max_time > 0 then begin
    delay.high := max_time * 4;
    delay.low := 0;
    time_$wait(time_$relative, delay, status);
  end;
end;
