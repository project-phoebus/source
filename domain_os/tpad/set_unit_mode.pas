{ TPAD_$SET_UNIT_MODE - set a unit's mode, scales, hysteresis and origin.

  Image addresses:
    sau2  0x00E697F0  TPAD_$SET_UNIT_MODE
    sau9  0x3C4704BA  TPAD_$SET_UNIT_MODE

  - The conversion factors are recomputed (range div scale, 1024 for a
    scale of 0); in absolute mode the origin and the cursor offset both
    become the caller's origin.

  Status stored:
    status_$ok: the mode was set
    smd_$illegal_unit: unitp is not 1 .. SMD_$N_DEVICES
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_4)

  The frame holds no object the code addresses: 4 bytes that nothing
  the image shows explains.  The stand-in unused_4 holds the place, as
  in the KBD and TTY routines (tty/k_flush_input.pas, the frame-bytes survey).
  A lead reads the bytes as a slot for the `with' statement's temporary;
  TPAD_$SET_UNIT, with no `with', has none; that reading is not
  established outside TPAD, so the stand-in stays until it is. }

procedure tpad_$set_unit_mode(in unitp: integer; in new_modep: tpad_$mode_t;
                              in xsp, ysp: integer; in hysteresisp: integer;
                              in originp: smd_$pos_t;
                              out status_ret: status_$t);
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the unit must exist }
  if (unitp <= 0) or (unitp > smd_$n_devices) then begin
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do begin
    mode := new_modep;
    x_scale := xsp;
    y_scale := ysp;

    { the conversion factors }
    if x_scale = 0 then
      x_factor := 1024
    else
      x_factor := x_range div x_scale;
    if y_scale = 0 then
      y_factor := 1024
    else
      y_factor := y_range div y_scale;

    hysteresis := hysteresisp;

    { absolute mode starts at the origin }
    if mode = tpad_$absolute then begin
      origin := originp;
      cursor_offset := originp;
    end;
  end;

  status_ret.all := status_$ok;
end;
