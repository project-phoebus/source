{ SMD_$DISSOC - dissociate a display.

  Image addresses:
    sau2  0x00E70106  SMD_$DISSOC
    sau5  0x00E72632  SMD_$DISSOC
    sau9  0x3C47677C  SMD_$DISSOC

  - Not implemented; param1 is not read.
  - With `display_devices' (base/config.ins.pas) the unit's device
    dissociates the display from the process.

  Status stored:
    smd_$not_implemented: always (not with `display_devices')
    the device's dissoc's status: with `display_devices', the unit is
      valid
    smd_$illegal_unit: with `display_devices', the unit is not valid
}

%if display_devices %then
procedure smd_$dissoc(in unit: integer; out status: status_$t);
begin
  if smd_$validate_unit(unit) then
    with smd_$wired_data.unit[unit] do
      vector^.dissoc^(dcte, status)
  else
    status.all := smd_$illegal_unit;
end;
%else
procedure smd_$dissoc(in param1: integer32;
                      out status: status_$t);
begin
  status.all := smd_$not_implemented;
end;
%endif
