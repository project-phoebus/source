{ ring_8025_unwire_driver - unwire the driver when its last unit goes.

  Image addresses:
    sau7  0x3C495AC0  ring_8025_unwire_driver
    sau8  0x03C892B8  ring_8025_unwire_driver
    sau9  0x3C484EB8  ring_8025_unwire_driver

  - Under the I/O wiring lock.  The last unit's stop unwires every page
    of the block's list and marks both units' records not wired; the
    count going below zero crashes the system.  The receive and transmit
    areas stay wired.

  Status stored: none.
}

procedure ring_8025_unwire_driver; internal;
var
  i: integer;
begin
  ml_$exclusion_start(io_$wiring_exclusion);
  ring_8025_wire_users := ring_8025_wire_users - 1;
  if ring_8025_wire_users = 0 then begin
    for i := 1 to ring_8025_wire_cnt do
      wp_$unwire(ring_8025_wire_list[i]);
    ring_8025_wire_cnt := 0;
    ring8025_ucb[0].wired := false;
    ring8025_ucb[1].wired := false;
  end
  else if ring_8025_wire_users < 0 then
    crash_system(status_$r8025_internal_driver_error);
  ml_$exclusion_stop(io_$wiring_exclusion);
end;
