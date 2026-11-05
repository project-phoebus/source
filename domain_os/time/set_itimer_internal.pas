{ time_$set_itimer_internal - arm or disarm the current address space's
  interval timer.

  Image addresses:
    sau2  0x00E58D14  time_$set_itimer_internal (module-local)
    sau4  0x0F861188  time_$set_itimer_internal (module-local)
    sau6  0x780600BE  time_$set_itimer_internal (module-local)
    sau7  0x3C468EBE  time_$set_itimer_internal (module-local)

  - The old interval and time left are returned and the timer's element
    taken off its queue; a zero value leaves it idle.
  - Otherwise it is queued again at value, through DXM's unwired queue,
    with the matching callback, repeating when the interval is not 0.

  Status stored:
    status_$ok: the timer was set or cleared
    time_$bad_relative_time: a value or interval of 2^47 ticks or more
}

{ TODO(pascal) time_$set_itimer_internal's datum: PROC1_$AS_ID widened with zeros

  The SAU2 image widens PROC1_$AS_ID into callback_arg with zeros (in
  TIME_$SET_CPU_LIMIT too), the form of an unsigned source, though
  proc1/proc1.ins.pas declares it `integer'.  The Pascal converts to
  linteger; PROC1's insert file is left as it is. }

procedure time_$set_itimer_internal(which: integer;
                                    in interval: time_$clock_t;
                                    in value: time_$clock_t;
                                    out ointerval: time_$clock_t;
                                    out ovalue: time_$clock_t;
                                    out status: status_$t);
  internal;
var
  queue: ^time_$queue_t;
  callback: univ_ptr;
  now: time_$clock_t;
  flags: time_$qelem_flags_t;
begin
  status.all := status_$ok;

  { the queue, the callback, the time now }
  if which = 0 then begin
    callback := addr(time_$set_itimer_real_callback);
    queue := addr(time_$rteq);
    time_$abs_clock(now);
  end
  else begin
    callback := addr(time_$set_itimer_virt_callback);
    queue := addr(time_$vtq[proc1_$current]);
    proc1_$get_cput8(now);
  end;

  if (value.high16 >= 16#8000) or else (interval.high16 >= 16#8000) then
  begin
    status.all := time_$bad_relative_time;
    return;
  end;

  { the old setting; off its queue }
  time_$get_itimer_internal(which, ointerval, ovalue);
  time_$q_remove_elem(queue^, time_$itimer_db[which][proc1_$as_id].elem,
                      status);

  { a zero value leaves it idle }
  if (value.high = 0) and then (value.low = 0) then begin
    time_$itimer_db[which][proc1_$as_id].elem.expire := value;
    status.all := status_$ok;
    return;
  end;

  { armed again }
  if (interval.high <> 0) or else (interval.low <> 0) then
    flags := [1, 4]
  else
    flags := [];
  time_$q_add_callback(queue^, value, time_$relative, now, callback,
                       univ_ptr(linteger(proc1_$as_id)), [2] + flags,
                       interval, time_$itimer_db[which][proc1_$as_id].elem,
                       status);
end;
