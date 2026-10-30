{ SMD_$INQ_DISP_TYPE - the type of the display on a unit.

  Image addresses:
    sau2  0x00E6DE1C  SMD_$INQ_DISP_TYPE
    sau5  0x00E7023C  SMD_$INQ_DISP_TYPE
    sau9  0x3C4749DA  SMD_$INQ_DISP_TYPE

  - An invalid unit's type is smd_$none.
  - With `display_devices' (base/config.ins.pas) the type is the unit's
    device's.

  Status stored: none.
}

function smd_$inq_disp_type(unit: integer): smd_$display_type_t;
begin
  if not smd_$validate_unit(unit) then
    smd_$inq_disp_type := smd_$none
  else
%if display_devices %then
    smd_$inq_disp_type := smd_$wired_data.unit[unit].vector^.disp_type;
%else
    smd_$inq_disp_type := smd_$display_com[unit].display_type;
%endif
end;
