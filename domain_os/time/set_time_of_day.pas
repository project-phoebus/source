{ TIME_$SET_TIME_OF_DAY - set the time of day and the calendar.

  Image addresses:
    sau2  0x00E1678C  TIME_$SET_TIME_OF_DAY
    sau4  0x0F81716C  TIME_$SET_TIME_OF_DAY

  - The microseconds are rounded down to whole ticks.  A time before
    1980 (the Apollo epoch) only sets the time of day and clears the
    current clock.
  - Otherwise, with interrupts off, the boot time, the current clock and
    the time of day are moved to the new time; then the calendar chip
    is written.

  Status stored:
    status_$ok: always
}

procedure time_$set_time_of_day(in tv: time_$timeval_t;
                                out status: status_$t);
var
  rec: cal_$timedate_rec_t;
  ticks: time_$clock_t;
  clock: time_$clock_t;
  usec: integer32;
  low: integer32;
  diff: pinteger;
  weekday: cal_$weekday_t;
begin
  status.all := status_$ok;
  usec := tv.usec & (-4);

  if tv.sec >= 315532800 then begin
    { the clock for the time }
    cal_$sec_to_clock(tv.sec - 315532800, clock);
    ticks.high16 := 0;
    ticks.low32 := tv.usec div 4;
    add48(clock, ticks);

    disable;
    if time_$current_clockh <> 0 then
      time_$boot_time := time_$boot_time + (clock.high - time_$current_clockh);
    time_$abs_clock(ticks);
    diff := ticks.low - time_$clockl;
    time_$current_clockh := clock.high;
    time_$current_time.sec := tv.sec;
    low := clock.low - diff;
    if low < 0 then
      time_$current_clockh := time_$current_clockh - 1;
    time_$current_clockl := low;
    usec := usec - diff * 4;
    if usec < 0 then begin
      usec := usec + 1000000;
      time_$current_time.sec := time_$current_time.sec - 1;
    end;
    time_$current_time.usec := usec;
    enable;

    { the calendar }
    cal_$decode_time(clock, rec);
    weekday := cal_$weekday(rec.year, rec.month, rec.day);
    cal_$write_calendar(rec.year, rec.month, rec.day, weekday, rec.hour,
                        rec.minute, rec.second);
  end
  else begin
    { before 1980 }
    time_$current_clockh := 0;
    time_$current_clockl := 0;
    time_$current_time.sec := tv.sec;
    time_$current_time.usec := usec;
  end;
end;
