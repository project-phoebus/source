{ TPAD_$RE_RANGE_UNIT - restart a unit's touchpad ranging.

  Image addresses:
    sau2  0x00E69A2C  TPAD_$RE_RANGE_UNIT
    sau4  0x0F8734F2  TPAD_$RE_RANGE_UNIT
    sau9  0x3C4706F6  TPAD_$RE_RANGE_UNIT

  - TPAD_$DATA ranges over the next 1000 touchpad samples, from the
    minima 16#100 and the ranges 16#200.

  Status stored:
    status_$ok: the ranging was restarted
    smd_$illegal_unit: unitp is not 1 .. SMD_$N_DEVICES
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_4)

  The frame holds no object the code addresses: 4 bytes that nothing
  the image shows explains.  The stand-in unused_4 holds the place, as
  in the KBD and TTY routines (tty/k_flush_input.pas, the frame-bytes survey).
  A lead reads the
  bytes as a slot for the `with' statement's temporary; that reading is
  not established outside TPAD, so the
  stand-in stays until it is. }

procedure tpad_$re_range_unit(in unitp: integer; out status_ret: status_$t);
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the unit must exist }
  if (unitp <= 0) or (unitp > smd_$n_devices) then begin
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do begin
    { range anew }
    sample_count := 0;
    x_min := 16#100;
    y_min := 16#100;
    x_range := 16#200;
    y_range := 16#200;

    { the conversion factors }
    if x_scale = 0 then
      x_factor := 1024
    else
      x_factor := x_range div x_scale;
    if y_scale = 0 then
      y_factor := 1024
    else
      y_factor := y_range div y_scale;
  end;

  status_ret.all := status_$ok;
end;
