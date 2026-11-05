{ TIME_$SET_ITIMER - set the current address space's interval timer.

  Image addresses:
    sau2  0x00E58E58  TIME_$SET_ITIMER
    sau4  0x0F8612CC  TIME_$SET_ITIMER
    sau6  0x78060202  TIME_$SET_ITIMER
    sau7  0x3C469002  TIME_$SET_ITIMER

  - The timers' cleanup handler is registered (PROC2_$SET_CLEANUP, bit
    6).  The real timer (which 0) is set as given, the virtual one
    (which 1) converted from and back to the caller's units.

  Status stored:
    time_$set_itimer_internal's status: in either case
}

procedure time_$set_itimer(in which: integer; in interval: time_$clock_t;
                           in value: time_$clock_t;
                           in out ointerval: time_$clock_t;
                           in out ovalue: time_$clock_t;
                           out status: status_$t);
begin
  proc2_$set_cleanup(6);
  if which = 0 then
    time_$set_itimer_internal(0, interval, value, ointerval, ovalue,
                              status)
  else begin
    time_$set_itimer_internal(1, time_$itimer_to_clock(interval),
                              time_$itimer_to_clock(value), ointerval,
                              ovalue, status);
    ointerval := time_$clock_to_itimer(ointerval);
    ovalue := time_$clock_to_itimer(ovalue);
  end;
end;
