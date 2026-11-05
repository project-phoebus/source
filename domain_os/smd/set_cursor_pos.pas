{ SMD_$SET_CURSOR_POS - move the cursor on the current display unit.

  Image addresses:
    sau2  0x00E6E766  SMD_$SET_CURSOR_POS
    sau4  0x0F878EF8  SMD_$SET_CURSOR_POS
    sau5  0x00E70BE4  SMD_$SET_CURSOR_POS
    sau6  0x78077F58  SMD_$SET_CURSOR_POS
    sau7  0x3C481A3A  SMD_$SET_CURSOR_POS
    sau9  0x3C47515A  SMD_$SET_CURSOR_POS

  Status stored:
    smd_$set_unit_cursor_pos's status: always
}

procedure smd_$set_cursor_pos(in pos: smd_$pos_t; out status: status_$t);
begin
  smd_$set_unit_cursor_pos(default_unit, pos, status);
end;
