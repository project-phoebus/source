{ ETHERNET_$STOP - stop a unit.

  Image addresses:
    sau8  0x03C86672  ETHERNET_$STOP
    sau9  0x3C482272  ETHERNET_$STOP

  - Under the unit's lock: a user goes and the unit stops taking Domain
    packets; the last user stops its receive process.  The driver is
    unwired once for the user.

  Status stored:
    status_$ok: the unit is stopped
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_offline: it does not take Domain packets
}

procedure ethernet_$stop(in unit: pinteger; out status: status_$t);
var
  u: ethernet_$unit_ptr_t;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[unit]);
  ml_$exclusion_start(u^.lock);
  if not (eth_unit_domain in u^.flags) then begin
    ml_$exclusion_stop(u^.lock);
    status.all := status_$eth_device_offline;
    return;
  end;
  u^.users := u^.users - 1;
  u^.flags := u^.flags - [eth_unit_domain];
  if u^.users = 0 then
    ethernet_stop_rcv(u);
  ml_$exclusion_stop(u^.lock);
  status.all := status_$ok;
  ethernet_unwire_driver;
end;
