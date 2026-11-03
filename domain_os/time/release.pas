{ TIME_$RELEASE - stop the current address space's interval timers.

  Image addresses:
    sau2  0x00E58B58  TIME_$RELEASE
    sau4  0x0F860FCC  TIME_$RELEASE

  - The real interval timer's element is taken off the real-time queue,
    the virtual one's off the current process's virtual-timer queue,
    and both expiries cleared.

  Status stored: none.
}

procedure time_$release;
var
  status: status_$t;
begin
  { the real interval timer }
  time_$q_remove_elem(time_$rteq, time_$itimer_db[0][proc1_$as_id].elem,
                      status);
  time_$itimer_db[0][proc1_$as_id].elem.expire.high := 0;
  time_$itimer_db[0][proc1_$as_id].elem.expire.low := 0;

  { the virtual one }
  time_$q_remove_elem(time_$vtq[proc1_$current],
                      time_$itimer_db[1][proc1_$as_id].elem, status);
  time_$itimer_db[1][proc1_$as_id].elem.expire.high := 0;
  time_$itimer_db[1][proc1_$as_id].elem.expire.low := 0;
end;
