{ TIME_$GET_ADJUST - the clock adjustment still to be applied.

  Image addresses:
    sau2  0x00E16AA8  TIME_$GET_ADJUST

  - TIME_$CURRENT_DELTA, read with interrupts off, in 4-microsecond
    ticks, is returned as seconds and microseconds.

  Status stored: none.
}

procedure time_$get_adjust(out delta: time_$timeval_t);
var
  current_delta: integer32;
begin
  disable;
  current_delta := time_$current_delta;
  enable;
  delta.sec := current_delta div 250000;
  delta.usec := (current_delta mod 250000) * 4;
end;
