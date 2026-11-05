{ TIME_$RTE_INT - the real-time timer's deferred interrupt routine.

  Image addresses:
    sau2  0x00E163A6  TIME_$RTE_INT
    sau4  0x0F816D86  TIME_$RTE_INT
    sau6  0x78016E2A  TIME_$RTE_INT
    sau7  0x3C417E16  TIME_$RTE_INT

  - The real-time queue is run at the current absolute time, then
    IN_RT_INT cleared so the timer handler may queue it again.  The
    result, the eventcount to advance, is nil.

  Status stored: none.
}

function time_$rte_int(data: univ_ptr): ec_$eventcount_ptr_t;
var
  status: status_$t;
  now: time_$clock_t;
begin
  time_$abs_clock(now);
  time_$q_scan_queue(time_$rteq, now, status);
  in_rt_int := false;
  time_$rte_int := nil;
end;
