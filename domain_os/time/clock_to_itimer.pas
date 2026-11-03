{ time_$clock_to_itimer - a clock in the interval timers' units.

  Image addresses:
    sau2  0x00E58C02  time_$clock_to_itimer (module-local)
    sau4  0x0F861076  time_$clock_to_itimer (module-local)

  - The 48-bit clock doubled (the interval timers count in half ticks),
    the low word's carry into the high longword.

  Status stored: none.
}

function time_$clock_to_itimer(in clock: time_$clock_t): time_$clock_t;
  internal;
var
  r: time_$clock_t;
begin
  r.high := clock.high * 2;
  r.low := clock.low * 2;
  if clock.low >= 16#8000 then
    r.high := r.high + 1;
  time_$clock_to_itimer := r;
end;
