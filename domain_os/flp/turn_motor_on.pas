{ FLP_$TURN_MOTOR_ON - switch the drives' motor on, and wait for it.

  Image addresses:
    sau7  0x3C44DB30  FLP_$TURN_MOTOR_ON
    sau8  0x03C45B30  FLP_$TURN_MOTOR_ON

  - Under the driver's spin lock the motor is marked on and used.  A
    motor that was off is switched on, its callback queued after
    flp_motor_time, and the caller waits for it to come up.

  Status stored: none.
}

procedure flp_$turn_motor_on;
var
  delay: time_$clock_t;
  status: status_$t;
  token: pinteger;
  was_on: boolean;
begin
  token := ml_$spin_lock(flp_spin_lock);
  was_on := flp_$motor_on;
  flp_$motor_on := true;
  flp_$used := true;
  ml_$spin_unlock(flp_spin_lock, token);
  if not was_on then begin
    flp_hw_addr^.dor := 16#1C;
    set_flp_timer(flp_motor_time);
    delay.high := 5;
    delay.low := 0;
    time_$wait(time_$relative, delay, status);
  end;
end;
