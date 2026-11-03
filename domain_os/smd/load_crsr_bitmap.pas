{ SMD_$LOAD_CRSR_BITMAP - define the bitmap of one of the four cursors.

  Image addresses:
    sau2  0x00E6FBC6  SMD_$LOAD_CRSR_BITMAP
    sau4  0x0F87A486  SMD_$LOAD_CRSR_BITMAP
    sau5  0x00E7207C  SMD_$LOAD_CRSR_BITMAP
    sau9  0x3C4760A0  SMD_$LOAD_CRSR_BITMAP

  - The pattern is stored with the display acquired, yorg turned into the
    hot spot's y from the bottom, the rows past height zeroed; unit is
    not read, and the process is bound to the default unit.
  - A cursor being shown is hidden behind the keyboard cursor's tracking
    rectangle meanwhile; those calls write the status again.
  - With `color_board' or `gpu_driver' (base/config.ins.pas) the pattern
    also goes to a color display's board.
  - With `display_devices' the pattern's version is advanced and the
    pattern goes to the default unit's device, which then has that
    version.

  Status stored:
    status_$ok: the pattern was stored
    smd_$invalid_crsr_number: cnum is above 3
    smd_$invalid_displacement: width or height is not 1..16, or xorg or
      yorg not 0..16
    smd_$add_trk_rect's, then smd_$del_trk_rect's status: the cursor was
      shown
}

{ TODO(pascal) 32 frame bytes of SMD_$LOAD_CRSR_BITMAP not accounted

  The frame has 0x20 bytes of locals, and nothing addresses any of them
  (every local is in a register).  The source above has disp, pattern (4
  bytes each), redraw and i (2 each); dpc's layout (`--dump-locals')
  gives them 12 bytes.  What the other 20 bytes held is not known (the
  other SMD frames with unexplained bytes: the README's TODO list). }

procedure smd_$load_crsr_bitmap(in unit: integer; in cnum: integer;
                                in width: integer; in height: integer;
                                in xorg: integer; in yorg: integer;
                                in bitmap: smd_$cursor_bitmap_t;
                                out status: status_$t);
var
  disp: smd_display_hw_ptr_t;
  pattern: smd_cursor_pattern_ptr_t;
  redraw: boolean;
  i: integer;
begin
  { the cursor number }
  if cnum > 3 then begin
    status.all := smd_$invalid_crsr_number;
    return;
  end;

  { the hot spot and the size }
  if (yorg > 16) or else (yorg < 0) or else (xorg > 16) or else
     (xorg < 0) or else (height > 16) or else (height < 1) or else
     (width < 1) or else (width > 16) then begin
    status.all := smd_$invalid_displacement;
    return;
  end;

  status.all := status_$ok;
  asid_to_unit[proc1_$as_id] := default_unit;
%if display_devices %then
  with smd_$wired_data.unit[default_unit] do begin
    disp := hw;
    pattern := smd_$cursor_ptable[cnum];

    { the cursor being changed is the one shown }
    redraw := (cnum = disp^.cursor_number) and disp^.cursor_visible;
    if redraw then
      smd_$add_trk_rect(kbd_cursor_track_rect, 1, status);

    discard(smd_$acq_display(0));

    pattern^.width := width;
    pattern^.height := height;
    pattern^.hot_x := xorg;
    pattern^.hot_y_adj := pattern^.height - yorg - 1;

    { the caller's rows }
    for i := 1 to height do
      pattern^.bitmap[i] := bitmap[i];

    { zero rows up to 16 }
    for i := height + 1 to 16 do
      pattern^.bitmap[i] := 0;

    { a new version of the pattern, loaded into the device }
    smd_$wired_data.crsr_versions[cnum] :=
      smd_$wired_data.crsr_versions[cnum] + 1;
    crsr_versions[cnum] := smd_$wired_data.crsr_versions[cnum];
    vector^.load_crsr^(dcte, cnum, 16, pattern^.hot_x, pattern^.hot_y_adj,
                       pattern^.bitmap);

    smd_$rel_display;

    if redraw then
      smd_$del_trk_rect(kbd_cursor_track_rect, 1, status);
  end;
%else
  disp := smd_$wired_data.unit[default_unit].hw;
  pattern := smd_$cursor_ptable[cnum];

  { the cursor being changed is the one shown }
  redraw := (cnum = disp^.cursor_number) and disp^.cursor_visible;
  if redraw then
    smd_$add_trk_rect(kbd_cursor_track_rect, 1, status);

  discard(smd_$acq_display(0));

  pattern^.width := width;
  pattern^.height := height;
  pattern^.hot_x := xorg;
  pattern^.hot_y_adj := pattern^.height - yorg - 1;

  { the caller's rows }
  for i := 1 to height do
    pattern^.bitmap[i] := bitmap[i];

  { zero rows up to 16 }
  for i := height + 1 to 16 do
    pattern^.bitmap[i] := 0;

%if color_board %then
  { a color board's display: the pattern to the board }
  disp^.field_3a := -1;
  if disp^.display_type in [smd_$color_display, smd_$800_color] then
    color_$load_crsr(cnum, 0, pattern^.hot_x, pattern^.hot_y_adj,
                     pattern^.bitmap);
%endif
%if gpu_driver %then
  if disp^.display_type in [smd_$color2_display, smd_$color3_display] then
    color2_$load_crsr(cnum, 0, pattern^.hot_x, pattern^.hot_y_adj,
                      pattern^.bitmap);
%endif

  smd_$rel_display;

  if redraw then
    smd_$del_trk_rect(kbd_cursor_track_rect, 1, status);
%endif
end;
