{ TPAD_$INQUIRE_UNIT - return a unit's mode, scales, hysteresis and
  origin.

  Image addresses:
    sau2  0x00E6996C  TPAD_$INQUIRE_UNIT
    sau4  0x0F873432  TPAD_$INQUIRE_UNIT

  - The check reads the current unit, tpad_$unit; the record is unitp's,
    as in TPAD_$SET_UNIT_CURSOR.

  Status stored:
    status_$ok: the settings were returned
    smd_$illegal_unit: the current unit is not 1 .. SMD_$N_DEVICES (no
      result written)
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_4)

  The frame holds no object the code addresses: 4 bytes that nothing
  the image shows explains.  The stand-in unused_4 holds the place, as
  in the KBD and TTY routines (tty/k_flush_input.pas, the frame-bytes survey).
  A lead reads the
  bytes as a slot for the `with' statement's temporary; that reading is
  not established outside TPAD, so the
  stand-in stays until it is. }

procedure tpad_$inquire_unit(in unitp: integer;
                             out cur_modep: tpad_$mode_t;
                             out xsp, ysp: integer;
                             out hysteresisp: integer;
                             out originp: smd_$pos_t;
                             out status_ret: status_$t);
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the current unit must exist }
  if (tpad_$unit <= 0) or (tpad_$unit > smd_$n_devices) then begin
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do begin
    cur_modep := mode;
    xsp := x_scale;
    ysp := y_scale;
    hysteresisp := hysteresis;
    originp := origin;
  end;

  status_ret.all := status_$ok;
end;
