{ TIME_$VT_INT - the virtual timer's deferred interrupt routine.

  Image addresses:
    sau2  0x00E163E4  TIME_$VT_INT
    sau4  0x0F816DC4  TIME_$VT_INT
    sau6  0x78016E68  TIME_$VT_INT
    sau7  0x3C417E54  TIME_$VT_INT

  - The current process's virtual-timer queue is run at its virtual
    time, then IN_VT_INT cleared so the timer handler may queue it
    again.  The result is nil, as TIME_$RTE_INT's.

  Status stored: none.
}

function time_$vt_int(data: univ_ptr): ec_$eventcount_ptr_t;
var
  now: time_$clock_t;
  status: status_$t;
begin
  proc1_$vt_int(now);
  time_$q_scan_queue(time_$vtq[proc1_$current], now, status);
  in_vt_int := false;
  time_$vt_int := nil;
end;
