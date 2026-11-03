{ RING_8025_$IOCTL - a unit's control request.

  Image addresses:
    sau8  0x03C8BA90  RING_8025_$IOCTL
    sau9  0x3C487694  RING_8025_$IOCTL

  - The driver record's ioctl entry: no request is implemented.

  Status stored:
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_device_offline: the unit does not take Domain packets
    status_$r8025_not_implemented: otherwise
}

procedure ring_8025_$ioctl(var unit: pinteger; var unused2: univ integer32;
                           unused3: integer; var unused4: univ integer32;
                           out status: status_$t);
  options(val_param);
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  with ring8025_ucb[unit] do
    if not (r8025_unit_domain in flags) then
      status.all := status_$r8025_device_offline
    else
      status.all := status_$r8025_not_implemented;
end;
