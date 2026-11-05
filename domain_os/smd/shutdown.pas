{ SMD_$SHUTDOWN - shut the display driver down.

  Image addresses:
    sau2  0x00E700E6  SMD_$SHUTDOWN
    sau4  0x0F87A9F2  SMD_$SHUTDOWN
    sau5  0x00E72612  SMD_$SHUTDOWN
    sau6  0x780798F0  SMD_$SHUTDOWN
    sau7  0x3C482EFE  SMD_$SHUTDOWN
    sau9  0x3C47661E  SMD_$SHUTDOWN

  - Without `display_devices' an empty procedure.
  - With `display_devices' (base/config.ins.pas) every unit's device
    shuts down.

  Status stored: none.
}

procedure smd_$shutdown;
%if display_devices %then
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.shutdown^(dcte);
end;
%else
begin
end;
%endif
