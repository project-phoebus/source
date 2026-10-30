{ SHOW_CURSOR - bring the displayed cursor up to date.

  Image addresses:
    sau2  0x00E6E1CC  SHOW_CURSOR
    sau5  0x00E70642  SHOW_CURSOR
    sau9  0x3C474B14  SHOW_CURSOR

  - The sentinel position and cursor -1 mean the previous display's own;
    a cursor whose box meets a tracking rectangle is hidden (checked
    under the tracking-rectangle lock).
  - Nothing is drawn unless the visibility, the unit, the position or
    the number changed; blocking false gives up when the display's lock
    is not free.
  - A hidden or failed draw owes a redraw (cursor_pending_flag).
  - With `display_devices' (base/config.ins.pas) the devices draw the
    cursors; the previous unit's display is locked through the current
    unit's device, the current one's too when the unit changed, and a
    cursor pattern newer than the device's is loaded first.
  - Global: a map symbol without `$'.

  Status stored: none.
}

{ TODO(pascal) frame of SHOW_CURSOR not accounted

  The image's frame has 64 bytes.  The image addresses pos's copy (4),
  pat_width (2), y_top (2), draw_cursor_num_var (2), visible (1), the
  current unit's `with' slot, cur_hw, the previous unit's `with' slot and
  blink (4 each): 27 bytes.  The other 37 are not addressed.  They fit
  the register-held values keeping slots of their own (the copies of
  cursor_num and blocking, perhaps at the top, the parameter copies then
  in reverse order above pos's; pat_height, x_left, y_bottom, x_right,
  draw_cursor_num and draw_result as words; prev_hw and pattern as
  longwords; the rectangle loop's element temporary), but no allocation
  order that puts every addressed object where the image has it was
  found, and dpc allocates the copies first in parameter order.  As in
  the module's other frames, not settled. }

procedure show_cursor(pos: smd_$pos_t; cursor_num: integer;
                      blocking: boolean);
var
  cur_hw: smd_display_hw_ptr_t;
  prev_hw: smd_display_hw_ptr_t;
  blink: ^smd_time_com_t;
  pattern: smd_cursor_pattern_ptr_t;
  pat_width: integer;
  pat_height: integer;
  x_left: integer;
  x_right: integer;
  y_bottom: integer;
  y_top: integer;
  visible: boolean;
  draw_result: boolean;
  i: integer;
  draw_cursor_num: integer;
  draw_cursor_num_var: integer;
begin
  if not smd_$validate_unit(default_unit) then
    return;

  if previous_unit = -1 then
    previous_unit := default_unit;

  with smd_$wired_data.unit[default_unit] do begin
    cur_hw := hw;

    with smd_$wired_data.unit[previous_unit] do begin
      prev_hw := hw;
      blink := addr(smd_time_$com);

      { the sentinel position and cursor -1 mean the
        previous display's own }
      if pos = cursor_pos_sentinel then
        pos := prev_hw^.cursor_pos;
      if cursor_num = -1 then
        cursor_num := prev_hw^.cursor_number;

      visible := true;

      { the cursor's box, clamped to the display's limits }
      pattern := smd_$cursor_ptable[cursor_num];
      pat_width := pattern^.width;
      pat_height := pattern^.height;
      x_left := max(pos.column - pattern^.hot_x, 0);
      y_bottom := min(pos.line + pattern^.hot_y_adj,
                      cur_hw^.disp_limits.ye);
      x_right := x_left + pat_width;
      if x_right > cur_hw^.disp_limits.xe then begin
        x_right := cur_hw^.disp_limits.xe + 1;
        x_left := x_right - pat_width;
      end;
      y_top := y_bottom - pat_height;
      if y_top < 0 then begin
        y_top := -1;
        y_bottom := pat_height - 1;
      end;

      { hidden where it meets a tracking rectangle }
      ml_$exclusion_start(smd_$wired_data.trk_rect_mutex);
      for i := 1 to tracking_rect_count do
        with tracking_rects[i] do
          if (y_top < y2) and then (y_bottom >= y1)
             and then (x_right > x1) and then (x_left <= x2) then begin
            visible := false;
            exit;
          end;
      ml_$exclusion_stop(smd_$wired_data.trk_rect_mutex);

      prev_hw^.cursor_number := cursor_num;
      prev_hw^.cursor_pos := pos;

      { nothing to do when nothing changed }
      if (visible = cur_hw^.cursor_visible)
         and then (previous_unit = default_unit)
         and then (pos = default_cursor_pos)
         and then (cursor_num = cursor_button_state) then
        return;

      asid_to_unit[proc1_$as_id] := previous_unit;

      { the display, waiting for it or not at all }
      if blocking then
        discard(smd_$acq_display(1))
%if display_devices %then
      else if not smd_$wired_data.unit[default_unit].vector^.
                    lock_display^(dcte, prev_hw^, 1) then
%else
      else if not smd_$lock_display(prev_hw^, 1) then
%endif
        return;

      { erase the previous display's cursor }
      draw_result := true;
      if prev_hw^.cursor_visible then begin
        blink^.blink_enable := false;
        if blink^.cursor_painted then
%if display_devices %then
          draw_result := vector^.xor_cursor^(dcte, cursor_button_state,
                                             default_cursor_pos,
                                             prev_hw^.disp_limits,
                                             draw_result, false);
%else
          draw_result := smd_$xor_cursor(cursor_button_state,
                                         default_cursor_pos,
                                         prev_hw^.disp_limits, prev_hw^,
                                         true, display_base, ctrl_regs);
%endif
        if draw_result then
          prev_hw^.cursor_visible := false;
      end;
    end;

%if display_devices %then
    { the current unit's display, when it is another }
    if previous_unit <> default_unit then begin
      smd_$rel_display;
      asid_to_unit[proc1_$as_id] := default_unit;
      if blocking then
        discard(smd_$acq_display(1))
      else if not vector^.lock_display^(dcte, cur_hw^, 1) then
        return;
    end;

    { the cursor's pattern, when the device has an older version }
    if smd_$wired_data.crsr_versions[cursor_num] <>
       crsr_versions[cursor_num] then begin
      crsr_versions[cursor_num] := smd_$wired_data.crsr_versions[cursor_num];
      with smd_$cursor_ptable[cursor_num]^ do
        vector^.load_crsr^(dcte, cursor_num, 16, hot_x, hot_y_adj, bitmap);
    end;

%endif
    { a hidden cursor at the drawn position is owed a redraw }
    cursor_pending_flag := cursor_pending_flag
                           or (not visible and (pos = default_cursor_pos));

    { draw the current display's cursor }
    if visible and draw_result then begin
      draw_cursor_num := cur_hw^.cursor_number;
      pos := cur_hw^.cursor_pos;
%if display_devices %then
      draw_result := vector^.xor_cursor^(dcte, draw_cursor_num, pos,
                                         cur_hw^.disp_limits, false,
                                         cursor_pending_flag);
%else
      draw_cursor_num_var := draw_cursor_num;
      draw_result := smd_$xor_cursor(draw_cursor_num_var, pos,
                                     cur_hw^.disp_limits, cur_hw^, false,
                                     display_base, ctrl_regs);
%endif
      if draw_result then begin
        cursor_pending_flag := false;
        default_cursor_pos := pos;
        cursor_button_state := draw_cursor_num;
        cur_hw^.cursor_visible := true;
        blink^.blink_enable := draw_cursor_num = 0;
        blink^.cursor_painted := true;
        blink^.blink_defer := 7;
      end
      else
        cursor_pending_flag := true;
    end;
  end;

  previous_unit := default_unit;
  smd_$rel_display;
end;
