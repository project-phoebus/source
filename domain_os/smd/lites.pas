{ SMD_$LITES - draw a row of the memory lights.

  Image addresses:
    sau2  0x00E1D8B8  SMD_$LITES
    sau3  0x00E1C734  SMD_$LITES
    sau5  0x00E1E678  SMD_$LITES
    sau9  0x3C420288  SMD_$LITES

  - The hand-written DISP_LITES draws the pattern's 16 lights on row
    y_pos of the display; with `display_devices' (base/config.ins.pas)
    every unit's device draws them.

  - Without `display_driver' (no display: the SAU3) an empty procedure.
  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$lites(pattern: pinteger; y_pos: pinteger);
  options(val_param);
%if not display_driver %then
begin
end;
%elseif display_devices %then
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.lites^(dcte, pattern, y_pos);
end;
%else
begin
  disp_lites(pattern, y_pos);
end;
%endif
