{ SMD_$ASSOC_CSRS - associate the display's control registers.

  Image addresses:
    sau2  0x00E700E8  SMD_$ASSOC_CSRS
    sau4  0x0F87A9F4  SMD_$ASSOC_CSRS
    sau5  0x00E72614  SMD_$ASSOC_CSRS
    sau9  0x3C476724  SMD_$ASSOC_CSRS

  - Not implemented; param1 and param2 are not read.
  - With `display_devices' (base/config.ins.pas) the unit's device
    associates the display with the process and returns an address in
    va.

  Status stored:
    smd_$not_implemented: always (not with `display_devices')
    the device's assoc's status: with `display_devices', the unit is
      valid
    smd_$illegal_unit: with `display_devices', the unit is not valid
}

%if display_devices %then
procedure smd_$assoc_csrs(in unit: integer; out va: univ_ptr;
                          out status: status_$t);
begin
  if smd_$validate_unit(unit) then
    with smd_$wired_data.unit[unit] do
      vector^.assoc^(dcte, va, status)
  else
    status.all := smd_$illegal_unit;
end;
%else
procedure smd_$assoc_csrs(in param1: integer32;
                          in param2: integer32;
                          out status: status_$t);
begin
  status.all := smd_$not_implemented;
end;
%endif
