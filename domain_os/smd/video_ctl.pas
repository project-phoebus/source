{ SMD_$VIDEO_CTL - turn the calling process's display on or off.

  Image addresses:
    sau2  0x00E6F838  SMD_$VIDEO_CTL
    sau4  0x0F87A0CA  SMD_$VIDEO_CTL
    sau5  0x00E71CB0  SMD_$VIDEO_CTL
    sau6  0x78078FE6  SMD_$VIDEO_CTL
    sau7  0x3C4827AA  SMD_$VIDEO_CTL
    sau9  0x3C475ECA  SMD_$VIDEO_CTL

  - The mode word's display-on bit is set from flags and written to the
    controller with the display acquired.
  - For the default unit the blanked state is noted, and turning it on
    restarts the blank timer.
  - With `color_board' or `gpu_driver' (base/config.ins.pas) a color
    display's flag goes to its board's driver instead.
  - With `display_devices' every unit's display is set, by its device,
    whatever the calling process's unit.

  Status stored:
    status_$ok: stored before the work, so a later failure is not
      reported
    smd_$illegal_caller: the process has no display unit
}

{ TODO(pascal) 4 frame bytes of SMD_$VIDEO_CTL not accounted

  The image's frame has 12 bytes of locals; the routine addresses only
  mode (unit and the `with' pointer are held in registers).  dpc's
  layout (`--dump-locals') gives the routine 8 bytes, so 4 are not
  explained; the other SMD routines have similar unexplained frame
  bytes (the README's TODO list). }

procedure smd_$video_ctl(in flags: boolean; out status: status_$t);
var
  mode: smd_$display_modereg_t;
  unit: integer;
begin
%if display_devices %then
  status.all := status_$ok;
  { every unit's display }
  for unit := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[unit] do begin
      { the display-on bit of the mode word }
      mode := smd_$display_modereg_t(hw^.video_flags);
      mode.dispon := flags;
      hw^.video_flags := integer(mode);
      vector^.video_ctl^(dcte, flags);
      if unit = default_unit then begin
        blank_flags.blank_pending := not flags;
        if flags then
          blank_time := time_$clockh;
      end;
    end;
%else
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  status.all := status_$ok;
  with smd_$wired_data.unit[unit] do begin
    { the display-on bit of the mode word }
    mode := smd_$display_modereg_t(hw^.video_flags);
    mode.dispon := flags;
    hw^.video_flags := integer(mode);
%if color_board or gpu_driver %then
    { a monochrome display's controller; a color board's driver }
    if hw^.display_type in [smd_$bw_15p, smd_$bw_19l] then begin
%endif
    { the word the acquisition returns, to the controller }
    mode := smd_$display_modereg_t(smd_$acq_display(0));
    ctrl_regs^.mode := integer(mode);
%if color_board or gpu_driver %then
    smd_$rel_display;
    end
%if color_board %then
    else if hw^.display_type in [smd_$color_display, smd_$800_color] then
      color_$video_ctl(flags)
%endif
%if gpu_driver %then
    else if hw^.display_type in
            [smd_$color2_display, smd_$color3_display] then
      color2_$video_ctl(flags)
%endif
%endif
  end;
%if not (color_board or gpu_driver) %then
  smd_$rel_display;
%endif
  if unit = default_unit then begin
    blank_flags.blank_pending := not flags;
    if flags then
      blank_time := time_$clockh;
  end;
%endif
end;
