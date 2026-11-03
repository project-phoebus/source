{ TIME_$ADJUST_TIME_OF_DAY - adjust the clock gradually by a delta.

  Image addresses:
    sau2  0x00E168DE  TIME_$ADJUST_TIME_OF_DAY
    sau4  0x0F8172BE  TIME_$ADJUST_TIME_OF_DAY

  - The delta in 4-microsecond ticks is rounded toward zero to a
    multiple of the skew step (167 ticks, 1670 beyond a second), which
    the timer handler adds to each tick until the delta is used up.
  - The time of day moves by the delta and the calendar chip is
    written; the delta still pending before is returned.

  Status stored:
    status_$ok: the adjustment was set
    time_$bad_delta: more than 8000 seconds either way
}

procedure time_$adjust_time_of_day(in delta: time_$timeval_t;
                                   out old_delta: time_$timeval_t;
                                   out status: status_$t);
var
  rec: cal_$timedate_rec_t;
  tv: time_$timeval_t;
  usec_ticks: time_$clock_t;
  new_clock: time_$clock_t;
  delta_ticks: integer32;
  skew: integer;
  tick: integer;
  weekday: cal_$weekday_t;
  old_delta_ticks: integer32;
begin
  status.all := status_$ok;
  if abs(delta.sec) > 8000 then begin
    status.all := time_$bad_delta;
    return;
  end;

  { the delta in ticks, a multiple of the step }
  delta_ticks := delta.sec * 250000 + delta.usec div 4;
  if delta_ticks <> 0 then begin
    if abs(delta_ticks) > 250000 then
      skew := 1670
    else
      skew := 167;
    if delta_ticks < 0 then
      skew := -skew;
    if delta_ticks mod skew <> 0 then
      delta_ticks := (delta_ticks div skew) * skew;
  end;
  if delta_ticks = 0 then
    skew := 0;
  tick := skew + 4167;

  time_$get_time_of_day(tv);
  disable;
  time_$current_skew := skew;
  time_$current_tick := tick;
  old_delta_ticks := time_$current_delta;
  time_$current_delta := delta_ticks;
  enable;

  { the time of day moved by the delta }
  if delta_ticks <> 0 then begin
    tv.sec := tv.sec + delta.sec;
    tv.usec := tv.usec + delta.usec;
    if tv.usec < 0 then begin
      tv.usec := tv.usec + 1000000;
      tv.sec := tv.sec - 1;
    end
    else if tv.usec >= 1000000 then begin
      tv.usec := tv.usec - 1000000;
      tv.sec := tv.sec + 1;
    end;
  end;

  { the clock and the calendar }
  cal_$sec_to_clock(tv.sec - 315532800, new_clock);
  usec_ticks.high16 := 0;
  usec_ticks.low32 := tv.usec div 4;
  add48(new_clock, usec_ticks);
  cal_$decode_time(new_clock, rec);
  weekday := cal_$weekday(rec.year, rec.month, rec.day);
  cal_$write_calendar(rec.year, rec.month, rec.day, weekday, rec.hour,
                      rec.minute, rec.second);

  old_delta.sec := old_delta_ticks div 250000;
  old_delta.usec := (old_delta_ticks mod 250000) * 4;
end;
