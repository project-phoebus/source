{ SMD_$CLEAR_SCREEN - clear the screen.

  Image addresses:
    sau2  0x00E70022  SMD_$CLEAR_SCREEN
    sau4  0x0F87A92E  SMD_$CLEAR_SCREEN
    sau5  0x00E7254E  SMD_$CLEAR_SCREEN
    sau6  0x7807982C  SMD_$CLEAR_SCREEN
    sau7  0x3C482D2A  SMD_$CLEAR_SCREEN
    sau9  0x3C47644A  SMD_$CLEAR_SCREEN

  - Without `display_devices' an empty procedure that does not write
    its status.
  - With `display_devices' (base/config.ins.pas) it takes no parameter,
    and every unit's device clears its screen.

  Status stored: none.
}

%if display_devices %then
procedure smd_$clear_screen;
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.clear_screen^(dcte);
end;
%else
procedure smd_$clear_screen(out status: status_$t);
begin
end;
%endif
