{ TIME_$SET_CPU_LIMIT - set the current address space's CPU time limit.

  Image addresses:
    sau2  0x00E58F64  TIME_$SET_CPU_LIMIT
    sau4  0x0F8613D8  TIME_$SET_CPU_LIMIT
    sau6  0x7806030E  TIME_$SET_CPU_LIMIT
    sau7  0x3C46910E  TIME_$SET_CPU_LIMIT

  - The limit's element is taken off the process's virtual-timer queue;
    a zero limit leaves it idle.  An absolute limit already past
    signals the process at once (signal 27).
  - Otherwise the element is queued again at the limit, through DXM's
    unwired queue, with TIME_$SET_CPU_LIMIT_CALLBACK.

  Status stored:
    status_$ok: the limit was set or cleared
    PROC2_$SIGNAL_OS's status: the limit was already past
}

procedure time_$set_cpu_limit(in limit: time_$clock_t; in relative: boolean;
                              out status: status_$t);
var
  limit_clock: time_$clock_t;
  queue: ^time_$queue_t;
  callback: univ_ptr;
  zero: time_$clock_t;
  delta: time_$clock_t;
  now: time_$clock_t;
begin
  status.all := status_$ok;
  callback := addr(time_$set_cpu_limit_callback);
  queue := addr(time_$vtq[proc1_$current]);
  limit_clock := time_$itimer_to_clock(limit);
  proc1_$get_cput8(now);
  zero.high := 0;
  zero.low := 0;

  { off the queue; a zero limit leaves it idle }
  time_$q_remove_elem(queue^, time_$cpu_limit_db[proc1_$as_id].elem,
                      status);
  if (limit.high = 0) and then (limit.low = 0) then begin
    time_$cpu_limit_db[proc1_$as_id].elem.expire := limit;
    status.all := status_$ok;
    return;
  end;

  { an absolute limit already past }
  delta := limit;
  if not relative then
    if not sub48(delta, now) then begin
      proc2_$signal_os(proc2_$uid[proc1_$as_id], 27, time_$cpu_limit_f,
                       status);
      return;
    end;

  if relative then
    time_$q_add_callback(queue^, limit_clock, time_$relative, now,
                         callback, univ_ptr(linteger(proc1_$as_id)), [2],
                         zero, time_$cpu_limit_db[proc1_$as_id].elem,
                         status)
  else
    time_$q_add_callback(queue^, limit_clock, time_$absolute, now,
                         callback, univ_ptr(linteger(proc1_$as_id)), [2],
                         zero, time_$cpu_limit_db[proc1_$as_id].elem,
                         status);
end;
