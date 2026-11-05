{ SMD_$SET_UNIT_CURSOR_POS - make a unit current and move its cursor.

  Image addresses:
    sau2  0x00E6E788  SMD_$SET_UNIT_CURSOR_POS
    sau4  0x0F878F1A  SMD_$SET_UNIT_CURSOR_POS
    sau5  0x00E70C06  SMD_$SET_UNIT_CURSOR_POS
    sau6  0x78077F7A  SMD_$SET_UNIT_CURSOR_POS
    sau7  0x3C481A5C  SMD_$SET_UNIT_CURSOR_POS
    sau9  0x3C47517C  SMD_$SET_UNIT_CURSOR_POS

  - A change of the current unit is counted; TPAD is told the unit and
    the position.
  - On success the status is not written.

  Status stored:
    smd_$illegal_unit: the unit is not valid
    tpad_$set_unit_cursor's status: TPAD refused the unit
}

procedure smd_$set_unit_cursor_pos(in unit: pinteger; in pos: smd_$pos_t;
                                   out status: status_$t);
begin
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else begin
    if unit <> default_unit then
      unit_change_count := unit_change_count + 1;
    default_unit := unit;
    show_cursor(pos, -1, true);
    tpad_$set_unit_cursor(unit, pos, status);
    saved_cursor_pos := pos;
  end;
end;
