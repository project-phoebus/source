{ tty_$i_wait - block a reader until input arrives, a quit, or the break
  timeout.

  Image addresses:
    sau2  0x00E1C204  tty_$i_wait (module-local)

  Assume we're called with the TTY lock held.

  - Waits, with the lock released, on the quit eventcount of the
    current address space and the line's input eventcount.
  - In break modes 2 and 3 (mode 3 once characters were read) a timer
    too: the break mode's timer times 25000 ticks, in mode 3 what is
    left of it since the last input.
  - A conditional get (wait_flag) does not wait.  The timer sets
    done_flag; a timer still queued is canceled.
  - ecs and vals are 1-based: 1 the quit, 2 the input, 3 the timer, the
    result being the element satisfied.

  Status stored:
    status_$tty_get_conditional_failed: a conditional get with nothing
      read
    status_$tty_quit_while_waiting_for_input: a quit (noted as seen)
    none: input or the timer ended the wait
}

{ TODO(pascal) the frame's alignment of 8 is not a known rule

  The SAU2 frame aligns elem and the two lists to 8 (as do TIME_$WAIT,
  TIME_$WAIT2 and other module-local frames); only word and longword
  alignment of frame objects is known, and dpc does not reproduce it.
  It does not explain the 4 bytes of the TTY_$K_ routines
  (k_flush_input.pas). }

{ TODO(pascal) the order of done_flag's and timer_armed's stores

  Neither source order of the two statements in the `result = 3' arm
  fits the known scheduling model, and the routine has no second site
  that tells them apart. }

[section(wired_proc, wired_data)]
procedure tty_$i_wait(var tty: tty_$desc_t; wait_flag: boolean;
                      out done_flag: boolean; count: tty_$uword_t;
                      out status: status_$t);
  internal;
var
  timer_ec: ec_$eventcount_t;
  elem: time_$queue_elem_t;
  vals: array[1..3] of integer32;
  ecs: array[1..3] of ec_$eventcount_ptr_t;
  scratch: time_$clock_t;
  timeout: time_$clock_t;
  adv_status: status_$t;
  timer_armed: boolean;
  num_ecs: integer;
  result: integer;
begin
  { the line's input eventcount }
  ecs[2] := tty.input_ec;
  vals[2] := ecs[2]^.value + 1;

  { the quit eventcount of this address space }
  ecs[1] := addr(fim_$quit_ec[proc1_$as_id]);
  vals[1] := fim_$quit_value[proc1_$as_id] + 1;

  timer_armed := false;

  { no timer in break modes 0 and 1, nor in mode 3 before the first
    character }
  if (tty.break_mode.break_type in [tty_$break_on_eol, tty_$break_on_count])
     or else ((tty.break_mode.break_type = tty_$break_on_timer_or_count)
              and then (count = 0)) then
    num_ecs := 2
  else begin
    { the timer eventcount and the timeout }
    elem.flags := [];
    num_ecs := 3;
    ec_$init(timer_ec);
    ecs[3] := addr(timer_ec);
    vals[3] := timer_ec.value + 1;
    timeout.high16 := 0;
    timeout.low32 := tty.break_mode.timer * 25000;

    if tty.break_mode.break_type = tty_$break_on_timer then begin
      { the whole timeout from now }
      scratch := timeout;
      timer_armed := true;
      time_$advance(time_$relative, scratch, timer_ec, elem, adv_status);
    end
    else begin
      { what is left of it since the last input }
      time_$clock(scratch);
      discard(sub48(scratch, tty.last_input_clock));
      discard(sub48(timeout, scratch));
      timer_armed := true;
      time_$advance(time_$relative, timeout, timer_ec, elem, adv_status);
    end;
  end;

  { a conditional get does not wait }
  if wait_flag then begin
    if count = 0 then
      status.all := status_$tty_get_conditional_failed;
  end
  else begin
    { wait without the lock }
    tty_$i_unlock(tty);
    result := ec_$waitn(ecs, vals, num_ecs);
    tty_$i_lock(tty);

    if result = 1 then begin
      { a quit; note it as seen }
      status.all := status_$tty_quit_while_waiting_for_input;
      fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
    end
    else if result = 3 then begin
      { the timer fired; nothing to cancel }
      done_flag := true;
      timer_armed := false;
    end;
  end;

  { take a timer that did not fire off its queue }
  if timer_armed then
    time_$cancel(vals[3], elem, adv_status);
end;
