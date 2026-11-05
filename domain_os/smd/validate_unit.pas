{ smd_$validate_unit - whether a display unit number names a display.

  Image addresses:
    sau2  0x00E6D700  smd_$validate_unit (module-local)
    sau3  0x00E6E624  smd_$validate_unit (module-local)
    sau4  0x0F877D4C  smd_$validate_unit (module-local)
    sau5  0x00E6F97C  smd_$validate_unit (module-local)
    sau6  0x78076DB0  smd_$validate_unit (module-local)
    sau7  0x3C480C2C  smd_$validate_unit (module-local)
    sau9  0x3C47434C  smd_$validate_unit (module-local)

  - Only unit 1 exists (units 1 and 2 with `two_display_units',
    base/config.ins.pas); the result is true when its display type is
    not smd_$none.  With `display_devices' any unit from 1 to the
    count of devices added is valid, whatever its type.

  - Without `display_driver' (no display: the SAU3) no unit is valid.
  Status stored: none.
}

function smd_$validate_unit(unit: integer): boolean; internal;
begin
%if not display_driver %then
  smd_$validate_unit := false;
%elseif display_devices %then
  smd_$validate_unit := (unit >= 1) and (unit <= smd_$wired_data.unit_count);
%else
%if two_display_units %then
  if (unit = 1) or else (unit = 2) then
%else
  if unit = 1 then
%endif
    smd_$validate_unit :=
      smd_$display_com[unit].display_type <> smd_$none
  else
    smd_$validate_unit := false;
%endif
end;
