{ ethernet_unwire_driver - unwire the driver when its last unit goes.

  Image addresses:
    sau9  0x3C480548  ethernet_unwire_driver

  - Under the I/O wiring lock.  When the last unit that keeps the
    driver wired lets go, every page of the list is unwired and both
    units' records are marked unwired; a count below zero crashes the
    system.

  Status stored: none.
}

procedure ethernet_unwire_driver; internal;
var
  i: integer;
begin
  ml_$exclusion_start(io_$wiring_exclusion);
  ethernet_wire_users := ethernet_wire_users - 1;
  if ethernet_wire_users = 0 then begin
    for i := 1 to ethernet_wire_cnt do
      wp_$unwire(ethernet_wire_list[i]);
    ethernet_wire_cnt := 0;
    ether_ucb[0].wired := false;
    ether_ucb[1].wired := false;
  end
  else if ethernet_wire_users < 0 then
    crash_system(status_$eth_internal_driver_error);
  ml_$exclusion_stop(io_$wiring_exclusion);
end;
