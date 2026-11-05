{ TPAD_$SET_UNIT - make a display unit the locator's current unit.

  Image addresses:
    sau2  0x00E699DC  TPAD_$SET_UNIT
    sau4  0x0F8734A2  TPAD_$SET_UNIT
    sau6  0x780725FE  TPAD_$SET_UNIT
    sau7  0x3C47CF76  TPAD_$SET_UNIT

  - A unitnum outside 1 .. SMD_$N_DEVICES is ignored.

  Status stored: none.
}

procedure tpad_$set_unit(in unitnum: integer);
begin
  if (unitnum > 0) and (unitnum <= smd_$n_devices) then
    tpad_$unit := unitnum;
end;
