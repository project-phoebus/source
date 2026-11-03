{ TPAD_$SET_MODE - set the current unit's mode, scales and hysteresis.

  Image addresses:
    sau2  0x00E697BE  TPAD_$SET_MODE
    sau4  0x0F873284  TPAD_$SET_MODE

  - TPAD_$SET_UNIT_MODE for the current unit; its status is ignored.

  Status stored: none.
}

procedure tpad_$set_mode(in new_mode: tpad_$mode_t; in xs, ys: integer;
                         in hysteresis: integer; in origin: smd_$pos_t);
var
  status: status_$t;
begin
  tpad_$set_unit_mode(tpad_$unit, new_mode, xs, ys, hysteresis, origin,
                      status);
end;
