{ SMD_$SET_TP_CURSOR - offer a locator position to the display driver.

  Image addresses:
    sau2  0x00E6E964  SMD_$SET_TP_CURSOR
    sau4  0x0F8790F6  SMD_$SET_TP_CURSOR
    sau5  0x00E70DE2  SMD_$SET_TP_CURSOR
    sau6  0x7807814C  SMD_$SET_TP_CURSOR
    sau7  0x3C481C2E  SMD_$SET_TP_CURSOR
    sau9  0x3C47534E  SMD_$SET_TP_CURSOR

  - A move event (the edge flag false) to SMD_$LOC_EVENT.
  - The heading is Apollo's (customer smdu.ins.pas of SR10.2).

  Status stored: none.
}

procedure smd_$set_tp_cursor(in unit: integer; pos: smd_$pos_t;
                             buttons: integer);
begin
  smd_$loc_event(false, unit, pos, buttons);
end;
