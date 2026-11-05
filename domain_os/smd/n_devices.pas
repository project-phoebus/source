{ SMD_$N_DEVICES - the number of the highest display unit present.

  Image addresses:
    sau2  0x00E70024  SMD_$N_DEVICES
    sau3  0x00E6E648  SMD_$N_DEVICES
    sau4  0x0F87A930  SMD_$N_DEVICES
    sau5  0x00E72550  SMD_$N_DEVICES
    sau6  0x7807982E  SMD_$N_DEVICES
    sau7  0x3C482D72  SMD_$N_DEVICES
    sau9  0x3C476492  SMD_$N_DEVICES

  - The units are 1 here (1 and 2 with `two_display_units',
    base/config.ins.pas); the result is 0 when no unit has a display.
  - With `display_devices' the result is the number of devices added.

  - Without `display_driver' (no display: the SAU3) there are none.
  Status stored: none.
}

function smd_$n_devices: integer;
var
  n: integer;
  u: integer;
  present: boolean;
begin
%if not display_driver %then
  smd_$n_devices := 0;
%elseif display_devices %then
  smd_$n_devices := smd_$wired_data.unit_count;
%else
  n := 0;
  for u := 1 to smd_unit_count do begin
    present := smd_$inq_disp_type(u) <> smd_$none;
    if present then
      n := u;
  end;
  smd_$n_devices := n;
%endif
end;
