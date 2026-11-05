{ TIME_$GET_ITIMER - read the current address space's interval timer.

  Image addresses:
    sau2  0x00E58F06  TIME_$GET_ITIMER
    sau4  0x0F86137A  TIME_$GET_ITIMER
    sau6  0x780602B0  TIME_$GET_ITIMER
    sau7  0x3C4690B0  TIME_$GET_ITIMER

  - time_$get_itimer_internal, the virtual timer's (which 1) values
    converted to the caller's units.

  Status stored: none.
}

procedure time_$get_itimer(in which: integer;
                           in out interval: time_$clock_t;
                           in out value: time_$clock_t);
begin
  time_$get_itimer_internal(which, interval, value);
  if which = 1 then begin
    interval := time_$clock_to_itimer(interval);
    value := time_$clock_to_itimer(value);
  end;
end;
