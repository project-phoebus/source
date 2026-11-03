{ proc1_$init_ts_timer - arm a process's first timeslice.

  Image addresses:
    sau2  0x00E14B12  proc1_$init_ts_timer (module-local)
    sau4  0x0F815386  proc1_$init_ts_timer (module-local)

  - The element expires 65535 ticks of the process's CPU time from its
    current CPU clock, with PROC1_$TS_END_CALLBACK and the pid as its
    datum, on the process's virtual-timer queue.
  - TIME_$Q_ENTER_ELEM's status is ignored.

  Status stored: none.
}

procedure proc1_$init_ts_timer(pid: pinteger); internal;
var
  now: time_$clock_t;
  status: status_$t;
  d: time_$clock_t;
begin
  with proc1_$ts_elem[pid].elem do begin
    flags := [];
    now := pcbs[pid]^.cpu.total;
    d.high := 0;
    d.low := 65535;
    expire := now;
    add48(expire, d);
    callback := addr(proc1_$ts_end_callback);
    callback_arg := univ_ptr(linteger(pid));
  end;
  time_$q_enter_elem(time_$vtq[pid], now, proc1_$ts_elem[pid].elem,
                     status);
end;
