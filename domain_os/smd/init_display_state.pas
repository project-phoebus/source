{ smd_$init_display_state - put the caller's display back in its initial state.

  Image addresses:
    sau2  0x00E6F514  smd_$init_display_state (module-local)
    sau5  0x00E71902  smd_$init_display_state (module-local)
    sau9  0x3C475B32  smd_$init_display_state (module-local)

  - With the display acquired, the controller gets SMD_$ACQ_DISPLAY's
    mode word, the unit is reset, and full turns the video on.
  - With `color_board' or `gpu_driver' (base/config.ins.pas) a color
    display is not acquired: its board's driver is shut down instead.
  - With `display_devices' the unit's device is shut down, the display
    acquired, the device given the four cursor patterns, and the unit
    reset in full whatever full is.

  Status stored:
    status_$ok: the display was reset
    smd_$illegal_caller: the process has no display unit
    smd_$video_ctl's status: full is set
}

{ TODO(pascal) smd_$init_display_state's frame: 8 of its 0x14 bytes not accounted

  The image's frame is 20 bytes and addresses no frame slot: full,
  unit and the `with' pointer are held in registers.  A module-local
  routine's frame has the 4-byte slot at its top; dpc's layout
  (`--dump-locals' on the gate's copy) gives the routine as written 12
  bytes (the slot, unit and the `with' slot).  The other 8 (locals the
  source had and never used, or temporaries) are not accounted. }

procedure smd_$init_display_state(full: boolean; out status: status_$t);
  internal;
var
  unit: integer;
%if display_devices %then
  i: integer;
%endif
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  status.all := status_$ok;
%if display_devices %then
  { the device restarted, the display acquired, and the cursors'
    patterns loaded afresh }
  with smd_$wired_data.unit[unit] do begin
    vector^.shutdown^(dcte);
    discard(smd_$acq_display(0));
    crsr_versions := smd_$wired_data.crsr_versions;
    for i := 0 to 3 do
      with smd_$cursor_ptable[i]^ do
        vector^.load_crsr^(dcte, i, 16, hot_x, hot_y_adj, bitmap);
  end;
  smd_$reset_unit_display(unit, true);
%else
  with smd_$wired_data.unit[unit]
%if color_board or gpu_driver %then
       , hw^
%endif
       do
%if color_board %then
    if display_type in [smd_$color_display, smd_$800_color] then
      color_$shutdown
    else
%endif
%if gpu_driver %then
    if display_type in [smd_$color2_display, smd_$color3_display] then
      color2_$shutdown
    else
%endif
%if color_board or gpu_driver %then
    if display_type in [smd_$bw_15p, smd_$bw_19l] then
%endif
    ctrl_regs^.mode := smd_$acq_display(0);
  smd_$reset_unit_display(unit, full);
%endif
  if full then
    smd_$video_ctl(true, status);
%if color_board or gpu_driver %then
  if smd_$wired_data.unit[unit].hw^.display_type in
     [smd_$bw_15p, smd_$bw_19l] then
%endif
  smd_$rel_display;
end;
