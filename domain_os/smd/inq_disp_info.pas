{ SMD_$INQ_DISP_INFO - inquire a display unit's type and sizes.

  Image addresses:
    sau2  0x00E70124  SMD_$INQ_DISP_INFO
    sau5  0x00E72650  SMD_$INQ_DISP_INFO
    sau9  0x3C4767D0  SMD_$INQ_DISP_INFO

  - The visible width and height are the display limits' ends plus one.
  - The frame buffer is 1024 x 1024, 1024 x 2048 for types 3 and 4,
    2048 x 1024 for types 5 and 9, 0 x 0 for 7 or a type outside 1..11.
  - An invalid unit gets the cleared result.
  - With `display_devices' (base/config.ins.pas) a valid unit's result
    is its device's information, copied whole.

  Status stored:
    status_$ok: the unit is valid
    smd_$illegal_unit: the unit is not valid
}
procedure smd_$inq_disp_info(in unit: integer;
                             out info: smd_disp_info_result_t;
                             out status: status_$t);
%if two_display_units %then
var
  disp_unit: integer;
%endif
begin
  info.display_type := smd_$none;
  info.dims.mem_width := 0;
  info.dims.mem_height := 0;
  info.dims.width := 0;
  info.dims.height := 0;
  status.all := status_$ok;
  if not smd_$validate_unit(unit) then begin
    status.all := smd_$illegal_unit;
    return;
  end;

%if display_devices %then
  info := smd_$wired_data.unit[unit].vector^.info;
%else
%if two_display_units %then
  disp_unit := unit;
  info.display_type := smd_$display_com[disp_unit].display_type;
  { unit 1 without a display: the second unit's }
  if (info.display_type = smd_$none) and then (disp_unit = 1) then begin
    info.display_type := smd_$display_com[2].display_type;
    disp_unit := 2;
  end;
  with smd_$wired_data.unit[disp_unit], hw^ do begin
%else
  info.display_type := smd_$display_com[unit].display_type;
  with smd_$wired_data.unit[unit], hw^ do begin
%endif
    info.dims.width := disp_limits.xe + 1;
    info.dims.height := disp_limits.ye + 1;
  end;

  case info.display_type of
    smd_$bw_15p, smd_$bw_19l, smd_$color3_display, smd_$color4_display,
    smd_$color5_display, smd_$bw5_1024x800: begin
      info.dims.mem_width := 1024;
      info.dims.mem_height := 1024;
    end;
    smd_$color_display, smd_$800_color: begin
      info.dims.mem_width := 1024;
      info.dims.mem_height := 2048;
    end;
    smd_$color2_display, smd_$bw4_1280x1024: begin
      info.dims.mem_width := 2048;
      info.dims.mem_height := 1024;
    end;
  end;
%endif
end;
