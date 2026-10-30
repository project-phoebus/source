{ RING_8025_$START - start a unit.

  Image addresses:
    sau9  0x3C487236  RING_8025_$START

  - The driver is wired for the unit first.  Under the unit's lock: the
    first user brings the unit on line (ring_8025_start_unit), a later
    one finds it on line; each success counts a user and marks the unit
    as taking Domain packets.  The driver is unwired again when the
    start failed.

  Status stored:
    status_$ok: the unit is started
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    ring_8025_wire_driver's status: the driver could not be wired
    status_$r8025_device_already_online: it takes Domain packets already
    ring_8025_start_unit's status: bringing it on line failed
}

procedure ring_8025_$start(in unit: pinteger; out status: status_$t);
var
  u: ring_8025_$unit_ptr_t;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  u := addr(ring8025_ucb[unit]);
  ring_8025_wire_driver(u, status);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.lock);
  if r8025_unit_domain in u^.flags then
    status.all := status_$r8025_device_already_online
  else begin
    if u^.users = 0 then
      ring_8025_start_unit(u, status)
    else
      status.all := status_$ok;
    if status.all = status_$ok then begin
      u^.users := u^.users + 1;
      u^.flags := u^.flags + [r8025_unit_domain];
    end;
  end;
  ml_$exclusion_stop(u^.lock);
  if status.all <> status_$ok then
    ring_8025_unwire_driver;
end;
