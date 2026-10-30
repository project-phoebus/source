{ SMD_$SET_COLOR_TABLE - set a unit's color table.

  Image addresses:
    sau9  0x3C476832  SMD_$SET_COLOR_TABLE

  - The unit's device does the work.

  Status stored:
    smd_$illegal_unit: the unit is not valid
    the device's set_color_table's status: the unit is valid
}

procedure smd_$set_color_table(in unit: integer; in arg_1: integer;
                               in arg_2: integer; var flag: boolean;
                               out status: status_$t);
begin
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else
    with smd_$wired_data.unit[unit] do
      vector^.set_color_table^(dcte, arg_1, arg_2, flag, status);
end;
