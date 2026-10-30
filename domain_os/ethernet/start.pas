{ ETHERNET_$START - start a unit.

  Image addresses:
    sau9  0x3C4821D2  ETHERNET_$START

  - The driver is wired for the unit first.  Under the unit's lock: the
    first user brings the unit on line (ethernet_start_unit), a later
    one finds it on line; each success counts a user and marks the unit
    as taking Domain packets.  The driver is unwired again when the
    start failed.
  - A failure counts in the unit's seventh statistic.

  Status stored:
    status_$ok: the unit is started
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_already_online: it takes Domain packets already
    ethernet_start_unit's status: bringing it on line failed
}

procedure ethernet_$start(in unit: pinteger; out status: status_$t);
var
  u: ethernet_$unit_ptr_t;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[unit]);
  ethernet_wire_driver(u);
  ml_$exclusion_start(u^.lock);
  if eth_unit_domain in u^.flags then
    status.all := status_$eth_device_already_online
  else begin
    if u^.users = 0 then
      ethernet_start_unit(u, status)
    else
      status.all := status_$ok;
    if status.all = status_$ok then begin
      u^.users := u^.users + 1;
      u^.flags := u^.flags + [eth_unit_domain];
    end
    else
      with u^ do
        stats.counts[7] := stats.counts[7] + 1;
  end;
  ml_$exclusion_stop(u^.lock);
  if status.all <> status_$ok then
    ethernet_unwire_driver;
end;
