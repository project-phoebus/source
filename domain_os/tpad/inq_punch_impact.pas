{ TPAD_$INQ_PUNCH_IMPACT - return a unit's edge-event threshold.

  Image addresses:
    sau2  0x00E69B2E  TPAD_$INQ_PUNCH_IMPACT
    sau4  0x0F8735F4  TPAD_$INQ_PUNCH_IMPACT
    sau6  0x78072750  TPAD_$INQ_PUNCH_IMPACT
    sau7  0x3C47D0C8  TPAD_$INQ_PUNCH_IMPACT

  Status stored:
    status_$ok: the threshold was returned
    smd_$illegal_unit: unitp is not 1 .. SMD_$N_DEVICES (impact 0)
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_4)

  The frame holds no object the code addresses: 4 bytes that nothing
  the image shows explains.  The stand-in unused_4 holds the place, as
  in the KBD and TTY routines (tty/k_flush_input.pas, the frame-bytes survey).
  A lead reads the
  bytes as a slot for the `with' statement's temporary; that reading is
  not established outside TPAD, so the
  stand-in stays until it is. }

procedure tpad_$inq_punch_impact(in unitp: integer; out impact: integer;
                                 out status_ret: status_$t);
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the unit must exist }
  if (unitp <= 0) or (unitp > smd_$n_devices) then begin
    impact := 0;
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do
    impact := punch_impact;

  status_ret.all := status_$ok;
end;
