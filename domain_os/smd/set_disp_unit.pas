{ SMD_$SET_DISP_UNIT - make a display unit the calling process's.

  Image addresses:
    sau2  0x00E6F7D4  SMD_$SET_DISP_UNIT
    sau4  0x0F87A066  SMD_$SET_DISP_UNIT
    sau5  0x00E71C4C  SMD_$SET_DISP_UNIT
    sau9  0x3C475E66  SMD_$SET_DISP_UNIT

  Status stored:
    status_$ok: the unit is the process's display unit
    smd_$illegal_unit: the unit is not valid
}

procedure smd_$set_disp_unit(in unit: integer; out status: status_$t);
begin
  if not smd_$validate_unit(unit) then begin
    status.all := smd_$illegal_unit;
    return;
  end;
  asid_to_unit[proc1_$as_id] := unit;
  status.all := status_$ok;
end;
