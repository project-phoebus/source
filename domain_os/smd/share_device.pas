{ SMD_$SHARE_DEVICE - ask a unit's device to share the display.

  Image addresses:
    sau9  0x3C4766C8  SMD_$SHARE_DEVICE

  - The unit's device does the work.

  Status stored:
    smd_$illegal_unit: the unit is not valid
    the device's share_device's status: the unit is valid
}

procedure smd_$share_device(in unit: integer; in arg_1: integer;
                            out status: status_$t);
begin
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else
    with smd_$wired_data.unit[unit] do
      vector^.share_device^(dcte, arg_1, status);
end;
