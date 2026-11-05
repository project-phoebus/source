{ TPAD_$INQUIRE - return the current unit's mode settings.

  Image addresses:
    sau2  0x00E6993A  TPAD_$INQUIRE
    sau4  0x0F873400  TPAD_$INQUIRE
    sau6  0x7807255E  TPAD_$INQUIRE
    sau7  0x3C47CED4  TPAD_$INQUIRE

  - TPAD_$INQUIRE_UNIT for the current unit; its status is ignored.

  Status stored: none.
}

procedure tpad_$inquire(out cur_mode: tpad_$mode_t; out xs, ys: integer;
                        out hysteresis: integer; out origin: smd_$pos_t);
var
  status: status_$t;
begin
  tpad_$inquire_unit(tpad_$unit, cur_mode, xs, ys, hysteresis, origin,
                     status);
end;
