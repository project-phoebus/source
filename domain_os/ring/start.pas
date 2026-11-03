{ RING_$START - bring a ring unit on line.

  Image addresses:
    sau2  0x00E76830  RING_$START
    sau3  0x00E78020  RING_$START
    sau8  0x03C83116  RING_$START

  - The driver is wired and the unit marked running; its receive
    process is started if it is not yet, and its transmit mask gets the
    bits 16#BF.

  Status stored:
    status_$ok: the receive process was started already
    ring_$do_start's status: it was started now, or not
    status_$internet_unknown_network_port: the unit is not 0 or 1, or
      not initialized
}

procedure ring_$start(in unit: pinteger; out status: status_$t);
var
  mask: pinteger;
  u: ring_$unit_ptr_t;
begin
  u := addr(ring_$ctl[unit]);
  if (unit > 1) or else not u^.initialized then
    status.all := status_$internet_unknown_network_port
  else begin
    ring_$wire_driver;
    u^.state_flags := u^.state_flags + [ring_unit_running];
    if ring_unit_started in u^.state_flags then
      status.all := 0
    else
      ring_$do_start(unit, u^, status);
    mask := u^.tmask ! 16#BF;
    ring_$set_hw_mask(unit, mask);
  end;
end;
