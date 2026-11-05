{ SMD_$SET_CLIP_WINDOW - set the display's clipping window.

  Image addresses:
    sau2  0x00E6FE30  SMD_$SET_CLIP_WINDOW
    sau4  0x0F87A738  SMD_$SET_CLIP_WINDOW
    sau5  0x00E7235C  SMD_$SET_CLIP_WINDOW
    sau6  0x7807963A  SMD_$SET_CLIP_WINDOW

  - The window is clamped to the display's limits.

  Status stored:
    status_$ok: the window was set
    smd_$illegal_caller: the process has no display unit
}

procedure smd_$set_clip_window(in clip_rect: smd_$window_limits_t;
                               out status: status_$t);
var
  unit: integer;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;

  status.all := status_$ok;
  with smd_$display_com[unit] do begin
    clip_window := clip_rect;
    if disp_limits.xs > clip_rect.xs then
      clip_window.xs := disp_limits.xs;
    if disp_limits.ys > clip_rect.ys then
      clip_window.ys := disp_limits.ys;
    if disp_limits.xe < clip_rect.xe then
      clip_window.xe := disp_limits.xe;
    if disp_limits.ye < clip_rect.ye then
      clip_window.ye := disp_limits.ye;
  end;
end;
