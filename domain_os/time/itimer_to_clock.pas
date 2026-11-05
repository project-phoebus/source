{ time_$itimer_to_clock - an interval timer's value as a clock.

  Image addresses:
    sau2  0x00E58C3A  time_$itimer_to_clock (module-local)
    sau4  0x0F8610AE  time_$itimer_to_clock (module-local)
    sau6  0x7805FFE4  time_$itimer_to_clock (module-local)
    sau7  0x3C468DE4  time_$itimer_to_clock (module-local)

  - The 48-bit value halved, the high longword's low bit carried into
    the low word's top.

  Status stored: none.
}

function time_$itimer_to_clock(in clock: time_$clock_t): time_$clock_t;
  internal;
var
  r: time_$clock_t;
begin
  r.high := rshft(clock.high, 1);
  r.low := rshft(clock.low, 1);
  if (clock.high & 1) <> 0 then
    r.low := r.low ! 16#8000;
  time_$itimer_to_clock := r;
end;
