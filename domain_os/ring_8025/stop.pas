{ RING_8025_$STOP - stop a unit.

  Image addresses:
    sau9  0x3C4872D4  RING_8025_$STOP

  - Under the unit's lock: a user goes and the unit stops taking Domain
    packets; the last user stops its receive process.  The driver is
    unwired once for the user.

  Status stored:
    status_$ok: the unit is stopped
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_device_offline: it does not take Domain packets
}

procedure ring_8025_$stop(in unit: pinteger; out status: status_$t);
var
  u: ring_8025_$unit_ptr_t;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  u := addr(ring8025_ucb[unit]);
  ml_$exclusion_start(u^.lock);
  if not (r8025_unit_domain in u^.flags) then begin
    ml_$exclusion_stop(u^.lock);
    status.all := status_$r8025_device_offline;
    return;
  end;
  u^.users := u^.users - 1;
  u^.flags := u^.flags - [r8025_unit_domain];
  if u^.users = 0 then
    ring_8025_stop_rcv(u);
  ml_$exclusion_stop(u^.lock);
  status.all := status_$ok;
  ring_8025_unwire_driver;
end;
