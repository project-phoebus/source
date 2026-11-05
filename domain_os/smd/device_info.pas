{ SMD_$DEVICE_INFO - ask a unit's device for information.

  Image addresses:
    sau7  0x3C482F46  SMD_$DEVICE_INFO
    sau9  0x3C476666  SMD_$DEVICE_INFO

  - The unit's device does the work.

  Status stored:
    smd_$illegal_unit: the unit is not valid
    the device's device_info's status: the unit is valid
}

procedure smd_$device_info(in unit: integer; in arg_1: integer32;
                           var arg_2: integer32; var arg_3: integer32;
                           out status: status_$t);
begin
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else
    with smd_$wired_data.unit[unit] do
      vector^.device_info^(dcte, arg_1, arg_2, arg_3, status);
end;
