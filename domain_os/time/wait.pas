{ TIME_$WAIT - wait until a time, or until a quit.

  Image addresses:
    sau2  0x00E1650A  TIME_$WAIT
    sau4  0x0F816EEA  TIME_$WAIT

  - A local eventcount is set to be advanced at the time (an absolute
    time rebased onto the absolute clock), then waited for together
    with the address space's quit eventcount.
  - A quit cancels the advance and is consumed.  An element left in
    use crashes the system.

  Status stored:
    status_$ok: the time came
    time_$wait_quit: a quit came first
    TIME_$ADVANCE's status: that failed
}

procedure time_$wait(in rel_abs: time_$rel_abs_t;
                     in exp_time: time_$clock_t;
                     out status: status_$t);
var
  ec: ec_$eventcount_t;
  elem: time_$queue_elem_t;
  abs_clock: time_$clock_t;
  current_clock: time_$clock_t;
  local_delay: time_$clock_t;
  quit_val: integer32;
  local_status: status_$t;
  dtype: time_$rel_abs_t;
begin
  status.all := status_$ok;
  dtype := rel_abs;
  elem.flags := [];
  ec_$init(ec);
  local_delay := exp_time;

  { an absolute time onto the absolute clock }
  if dtype = time_$absolute then begin
    time_$clock(current_clock);
    time_$abs_clock(abs_clock);
    discard(sub48(local_delay, current_clock));
    add48(local_delay, abs_clock);
  end;

  time_$advance(dtype, local_delay, ec, elem, local_status);
  if local_status.all <> status_$ok then begin
    status := local_status;
    return;
  end;

  { the time or a quit }
  quit_val := fim_$quit_value[proc1_$as_id] + 1;
  if ec_$wait(addr(ec), addr(fim_$quit_ec[proc1_$as_id]), addr(ec_$nil_ec),
              1, quit_val, 0) <> 0 then begin
    time_$cancel(1, elem, local_status);
    status.all := time_$wait_quit;
    fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
  end;

  if elem.flags <> [] then
    crash_system(time_$q_elem_in_use);
end;
