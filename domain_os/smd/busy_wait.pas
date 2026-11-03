{ SMD_$BUSY_WAIT - wait while the display is busy.

  Image addresses:
    sau2  0x00E1D89E  SMD_$BUSY_WAIT
    sau4  0x0F81EC5C  SMD_$BUSY_WAIT
    sau5  0x00E1E65E  SMD_$BUSY_WAIT
    sau9  0x3C420232  SMD_$BUSY_WAIT

  - The display is never busy here; param1 is not read.  With
    `display_devices' (base/config.ins.pas) the unit's device waits.

  Status stored:
    status_$ok: always (without `display_devices')
    smd_$illegal_unit: the unit is not valid (`display_devices')
    the device's busy_wait's status: the unit is valid
}

%if display_devices %then
[section(wired_proc, wired_data)]
procedure smd_$busy_wait(in unit: integer; out status: status_$t);
begin
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else
    with smd_$wired_data.unit[unit] do
      vector^.busy_wait^(dcte, status);
end;
%else
[section(wired_proc, wired_data)]
procedure smd_$busy_wait(in param1: integer32; out status: status_$t);
begin
  status.all := status_$ok;
end;
%endif
