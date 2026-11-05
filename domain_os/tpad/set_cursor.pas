{ TPAD_$SET_CURSOR - re-origin the locator where the DM put the cursor.

  Image addresses:
    sau2  0x00E698A0  TPAD_$SET_CURSOR
    sau4  0x0F873366  TPAD_$SET_CURSOR
    sau6  0x780724C6  TPAD_$SET_CURSOR
    sau7  0x3C47CE3A  TPAD_$SET_CURSOR

  - TPAD_$SET_UNIT_CURSOR for the current unit; its status is ignored.

  Status stored: none.
}

procedure tpad_$set_cursor(in new_crsr: smd_$pos_t);
var
  status: status_$t;
begin
  tpad_$set_unit_cursor(tpad_$unit, new_crsr, status);
end;
