{ time_$get_itimer_internal - read the current address space's interval
  timer.

  Image addresses:
    sau2  0x00E58C74  time_$get_itimer_internal (module-local)

  - An armed timer gives its reload interval and the time left (0 when
    already past); an idle one gives 0 for both.

  Status stored: none.
}

procedure time_$get_itimer_internal(which: integer;
                                    out interval: time_$clock_t;
                                    out value: time_$clock_t);
  internal;
var
  now: time_$clock_t;
begin
  with time_$itimer_db[which][proc1_$as_id] do
    if 0 in elem.flags then begin
      { armed: the interval and the time left }
      interval := elem.interval;
      value := elem.expire;
      if which = 0 then
        time_$abs_clock(now)
      else
        proc1_$get_cput8(now);
      if not sub48(value, now) then begin
        value.high := 0;
        value.low := 0;
      end;
    end
    else begin
      { idle }
      value.high := 0;
      value.low := 0;
      interval.high := 0;
      interval.low := 0;
    end;
end;
