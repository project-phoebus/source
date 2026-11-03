{ SET_FLP_TIMER - queue the motor's callback after a time.

  Image addresses:
    sau8  0x03C45AA2  SET_FLP_TIMER

  - The driver's element is taken off the real-time queue and queued
    again, relative to now, with FLP_$MOTOR_CALLBACK; a failure to queue
    it crashes the system.

  Status stored: none.
}

procedure set_flp_timer(in when: time_$clock_t);
var
  status: status_$t;
  now: time_$clock_t;
begin
  status.all := status_$ok;
  flp_callback_arg := nil;
  time_$q_remove_elem(time_$rteq, flp_timer_elem, status);
  time_$clock(now);
  status.all := status_$ok;
  time_$q_add_callback(time_$rteq, when, time_$relative, now,
                       addr(flp_$motor_callback), flp_callback_arg, [2], 0,
                       flp_timer_elem, status);
  if status.all <> status_$ok then
    crash_system(status);
end;
