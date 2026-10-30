{ SMD_$COLD_INIT - initialize the display at cold start.

  Image addresses:
    sau2  0x00E34F00  SMD_$COLD_INIT
    sau5  0x00E372B6  SMD_$COLD_INIT
    sau9  0x3C43B652  SMD_$COLD_INIT

  - Without `display_devices' an empty procedure.
  - With `display_devices' (base/config.ins.pas) every unit's device
    initializes itself.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure smd_$cold_init;
%if display_devices %then
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.cold_init^(dcte);
end;
%else
begin
end;
%endif
