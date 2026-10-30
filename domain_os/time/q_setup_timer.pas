{ time_$q_setup_timer - arm the timer for a queue's first element.

  Image addresses:
    sau2  0x00E16BDA  time_$q_setup_timer (module-local)

  - The delay is the head's expiry less now, 0 when already past.
  - A virtual-timer queue hands it to PROC1_$SET_VT for its process;
    the real-time queue loads the auxiliary timer in units of 32 ticks
    (or 16#FFFF when it does not fit).

  Status stored: none.
}

{ TODO(pascal) time_$q_setup_timer's 4 unexplained frame bytes

  The SAU2 frame has 4 bytes no declared local or temporary accounts
  for: a register-held local of the source, or a second temporary.
  None is declared here. }

[section(wired_proc, wired_data)]
procedure time_$q_setup_timer(var queue: time_$queue_t;
                              in now: time_$clock_t);
  internal;
var
  status: status_$t;
  delay: time_$clock_t;
begin
  { the head's delay, 0 when past }
  delay := time_$queue_elem_ptr_t(queue.head)^.expire;
  if not sub48(delay, now) then begin
    delay.high := 0;
    delay.low := 0;
  end;

  if queue.virtual then
    proc1_$set_vt(queue.queue_id, delay, status)
  else if rshft(delay.high, 5) <> 0 then
    time_$wrt_timer(3, 16#FFFF)
  else
    time_$wrt_timer(3, rshft(delay.low32, 5));
end;
