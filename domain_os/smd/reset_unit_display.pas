{ smd_$reset_unit_display - reset a display unit's state to its defaults.

  Image addresses:
    sau2  0x00E6D736  smd_$reset_unit_display (module-local)
    sau4  0x0F877D8E  smd_$reset_unit_display (module-local)
    sau5  0x00E6F9B8  smd_$reset_unit_display (module-local)
    sau6  0x78076DEC  smd_$reset_unit_display (module-local)
    sau7  0x3C480CDA  smd_$reset_unit_display (module-local)
    sau9  0x3C4743FA  smd_$reset_unit_display (module-local)

  - The clip window becomes the display's limits, the font slots are
    emptied, and the hidden memory's free list gets one block, its place
    by the display type.
  - full resets the last raster line's eight words, for a unit that is
    borrowed or has no owner (a color display loads the board's cursors
    instead, with `color_board' or `gpu_driver').
  - With `display_devices' full is not read; the 1280 by 1024 display's
    free list has three blocks.

  Status stored: none.
}

{ TODO(pascal) frame of smd_$reset_unit_display not accounted

  The image's frame has 0x14 bytes; the code addresses no frame byte.
  The module-local's slot (4), i (2), and the `with' slot of unit[unit]
  (4) give 10 bytes, 12 with the rounding; 8 bytes are not explained.
  Slots for the `with' of hw^ and of hdm_list^ (4 each, a pointer's
  `with' temporary, which the one site HINT_$ADD_NET argues against)
  would make the 20.  SMD_$ASSOC's 12-byte frame (smd/assoc.pas) fits
  the same reading.  Not checked against dpc's layout. }

procedure smd_$reset_unit_display(unit: integer; full: boolean);
  internal;
var
  i: integer;
begin
  with smd_$wired_data.unit[unit], hw^ do begin
    clip_window := disp_limits;

    { the eight font slots }
    for i := 1 to 8 do
      font_table^[i].font_va := nil;

%if display_devices %then
    { TODO(pascal) the three-block free list as a block copy

      The SAU9 image fills the list's first 14 bytes (the count and
      three blocks) for the 1280 by 1024 display by one copy from a
      constant of that size after the routine's code, as PROC1_$BIND's
      cpu record (the TODO(pascal) in proc1/bind.pas).  The reference
      has no record constants; the Pascal assigns the fields (the same
      values, other instructions). }
    { the free list: three blocks for the 1280 by 1024 display, else
      one }
    if display_type = smd_$bw4_1280x1024 then
      with hdm_list^ do begin
        count := 3;
        blocks[1].offset := 16#29;
        blocks[1].size := 983;
        blocks[2].offset := 16#400;
        blocks[2].size := 1024;
        blocks[3].offset := 16#800;
        blocks[3].size := 1024;
      end
    else
      with hdm_list^ do begin
        count := 1;
        blocks[1].offset := 0;
        blocks[1].size := 855;
      end;
%else
    { the free list's one block }
    with hdm_list^ do begin
      count := 1;
      if not (display_type in [smd_$bw_19l, smd_$color3_display]) then
        begin
        blocks[1].offset := 16#31;
        blocks[1].size := 974;
        end
%if gpu_driver %then
      else if display_type = smd_$color3_display then begin
        blocks[1].offset := 5;
        blocks[1].size := 855;
        end
%endif
      else begin
        blocks[1].offset := 0;
        blocks[1].size := 855;
      end;
    end;
%endif

%if not display_devices %then
%if color_board %then
    { a color board's display: the four cursors' patterns to the board }
    if display_type in [smd_$color_display, smd_$800_color] then
      for i := 0 to 3 do
        with smd_$cursor_ptable[i]^ do
          color_$load_crsr(i, 0, hot_x, hot_y_adj, bitmap)
    else
%endif
%if gpu_driver %then
    { a graphics board's display: likewise, to that board }
    if display_type in [smd_$color2_display, smd_$color3_display] then
      for i := 0 to 3 do
        with smd_$cursor_ptable[i]^ do
          color2_$load_crsr(i, 0, hot_x, hot_y_adj, bitmap)
    else
%endif
    { the last raster line's eight words, for a unit that
      is borrowed or has no owner }
    if ((borrowed_asid <> 0) or else (owner_asid = 0)) and then full then
      for i := 0 to 3 do begin
        display_base^[1023, 56 + i] := 0;
        display_base^[1023, 60 + i] := 16#FFFF;
      end;
%endif
  end;
end;
