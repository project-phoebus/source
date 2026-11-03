{ FLP_$MOTOR_CALLBACK - the motor's time-queue callback.

  Image addresses:
    sau8  0x03C45BAC  FLP_$MOTOR_CALLBACK

  - With the motor on, under the driver's spin lock: a drive used since
    the last call queues the callback again, else the motor goes off;
    the used flag is cleared.  The element is not read.

  Status stored: none.
}

procedure flp_$motor_callback(in elem: time_$queue_elem_ptr_t);
var
  token: pinteger;
begin
  if flp_$motor_on then begin
    token := ml_$spin_lock(flp_spin_lock);
    if flp_$used then
      set_flp_timer(flp_motor_time)
    else begin
      flp_$shut_down_motor;
      flp_$motor_on := false;
    end;
    flp_$used := false;
    ml_$spin_unlock(flp_spin_lock, token);
  end;
end;
