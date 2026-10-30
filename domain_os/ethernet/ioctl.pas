{ ETHERNET_$IOCTL - a unit's control request.

  Image addresses:
    sau9  0x3C4827D8  ETHERNET_$IOCTL

  - The driver record's ioctl entry: no request is implemented.

  Status stored:
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_offline: the unit does not take Domain packets
    status_$eth_not_implemented: otherwise
}

procedure ethernet_$ioctl(var unit: pinteger; var unused2: univ integer32;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(val_param);
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  with ether_ucb[unit] do
    if not (eth_unit_domain in flags) then
      status.all := status_$eth_device_offline
    else
      status.all := status_$eth_not_implemented;
end;
