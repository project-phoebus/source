{ ETHERNET_$LOAD - load the adapter's program.

  Image addresses:
    sau8  0x03C86700  ETHERNET_$LOAD
    sau9  0x3C482300  ETHERNET_$LOAD

  - The driver record's detach entry, which NETWORK_$LOAD calls.  Unless
    the downloaded program runs already, /sys/ethernet8_microcode is
    downloaded into the adapter and started.
  - A failure is logged (the network's UID, the unit, the status and the
    step that failed), counted in the unit's seventh statistic and not
    returned: the adapter goes on without the program.

  Status stored:
    status_$ok: the program runs, or it failed to load and was logged
    status_$eth_invalid_unit_num: unit is not 0 or 1
}

procedure ethernet_$load(var unit: pinteger; var unused2: univ integer32;
                         unused3: integer; var unused4: univ integer32;
                         out status: status_$t);
var
  u: ethernet_$unit_ptr_t;
  start: integer;
  err: status_$t;
  rec: ethernet_$load_log_t;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[unit]);
  if not (eth_unit_program in u^.flags) then begin
    ethernet_download(u, '/sys/ethernet8_microcode', 24, start, status);
    rec.step := eth_load_download;
    if status.all = status_$ok then begin
      ethernet_execute(u, start, status);
      rec.step := eth_load_execute;
    end;
    if status.all = status_$ok then
      return;
    err := status;
    rec.code := eth_log_load;
    rec.unit := unit;
    rec.network := ethernet_driver.network_uid;
    rec.status := err;
    log_$add(eth_log_type, rec, 18);
    with u^ do
      stats.counts[7] := stats.counts[7] + 1;
  end;
  status.all := status_$ok;
end;
