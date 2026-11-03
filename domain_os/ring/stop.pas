{ RING_$STOP - take a ring unit off line.

  Image addresses:
    sau2  0x00E769C4  RING_$STOP
    sau3  0x00E781B4  RING_$STOP

  - Under the unit's transmit lock, the unit is marked not running and
    its mask set to 0.

  Status stored:
    status_$ok: the unit was taken off line
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_device_offline: the unit has no transmit mask
}

procedure ring_$stop(in unit: pinteger; out status: status_$t);
var
  mask: pinteger;
  u: ring_$unit_ptr_t;
begin
  if unit > 1 then
    status.all := status_$ring_invalid_unit_num
  else begin
    u := addr(ring_$ctl[unit]);
    ml_$exclusion_start(u^.tx_exclusion);
    if u^.tmask = 0 then begin
      ml_$exclusion_stop(u^.tx_exclusion);
      status.all := status_$ring_device_offline;
    end
    else begin
      u^.state_flags := u^.state_flags - [ring_unit_running];
      mask := 0;
      ring_$set_hw_mask(unit, mask);
      ml_$exclusion_stop(u^.tx_exclusion);
      status.all := 0;
    end;
  end;
end;
