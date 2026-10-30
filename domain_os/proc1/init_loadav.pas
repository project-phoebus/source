{ PROC1_$INIT_LOADAV - start the load-average timer.

  Image addresses:
    sau2  0x00E14C94  PROC1_$INIT_LOADAV

  - A periodic real-time callback (PROC1_$LOADAV_CALLBACK) every
    1250000 ticks (5 seconds at 250 kHz), on TIME_$RTEQ.
  - TIME_$Q_ENTER_ELEM's status is ignored.

  Status stored: none.
}

procedure proc1_$init_loadav;
var
  now: time_$clock_t;
  status: status_$t;
  iv: time_$clock_t;
begin
  proc1_$loadav[1] := 0;
  proc1_$loadav[2] := 0;
  proc1_$loadav[3] := 0;
  proc1_$loadav_elem.flags := [1];
  proc1_$loadav_elem.callback := addr(proc1_$loadav_callback);
  proc1_$loadav_elem.callback_arg := nil;

  iv.high16 := 0;
  iv.low32 := 1250000;
  proc1_$loadav_elem.interval := iv;
  time_$clock(now);
  add48(iv, now);
  proc1_$loadav_elem.expire := iv;

  time_$q_enter_elem(time_$rteq, now, proc1_$loadav_elem, status);
end;
