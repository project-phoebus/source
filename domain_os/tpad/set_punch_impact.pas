{ TPAD_$SET_PUNCH_IMPACT - set a unit's edge-event threshold.

  Image addresses:
    sau2  0x00E69ADC  TPAD_$SET_PUNCH_IMPACT

  - The result is the unit's old threshold (0 for a bad unit).
    TPAD_$DATA sends an edge event when a clamped motion reaches the
    threshold.

  Status stored:
    status_$ok: the threshold was set
    smd_$illegal_unit: unitp is not 1 .. SMD_$N_DEVICES
}

{ TODO(pascal) 4 frame bytes above the result's slot (stand-in unused_4)

  The frame holds the word result variable's slot and 4 bytes that nothing
  the image shows explains, 4 + 2 rounded.  The stand-in unused_4 holds
  them, declared first, so that the result variable lies below it (dpc's
  place for it; the original's is Uncertain).  A lead
  reads the 4 bytes as a slot
  for the `with' statement's temporary; that reading is not
  established outside TPAD, so the stand-in stays until it is. }

function tpad_$set_punch_impact(in unitp: integer; in impact: integer;
                                out status_ret: status_$t): integer;
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the unit must exist }
  if (unitp <= 0) or (unitp > smd_$n_devices) then begin
    tpad_$set_punch_impact := 0;
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do begin
    tpad_$set_punch_impact := punch_impact;
    punch_impact := impact;
  end;

  status_ret.all := status_$ok;
end;
