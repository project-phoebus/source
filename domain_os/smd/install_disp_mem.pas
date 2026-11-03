{ SMD_$INSTALL_DISP_MEM - install the display memory.

  Image addresses:
    sau2  0x00E34F02  SMD_$INSTALL_DISP_MEM
    sau4  0x0F83830C  SMD_$INSTALL_DISP_MEM
    sau5  0x00E372B8  SMD_$INSTALL_DISP_MEM
    sau9  0x3C43B69A  SMD_$INSTALL_DISP_MEM

  - Without `display_devices' an empty procedure.
  - With `display_devices' (base/config.ins.pas) every unit's device
    installs its display memory; their statuses are not looked at.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure smd_$install_disp_mem;
%if display_devices %then
var
  u: integer;
  status: status_$t;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.install_disp^(dcte, status);
end;
%else
begin
end;
%endif
