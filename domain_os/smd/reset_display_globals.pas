{ smd_$reset_display_globals - reset the cursor, blink, blank and tracking
  state.

  Image addresses:
    sau2  0x00E6D7E2  smd_$reset_display_globals (module-local)
    sau4  0x0F877E7C  smd_$reset_display_globals (module-local)
    sau5  0x00E6FAF6  smd_$reset_display_globals (module-local)
    sau6  0x78076EE4  smd_$reset_display_globals (module-local)
    sau7  0x3C480D5A  smd_$reset_display_globals (module-local)
    sau9  0x3C47447A  smd_$reset_display_globals (module-local)

  - full also resets the saved locator position, the last button state,
    the event ring and the three flags at +0x173D..+0x173F.
  - The tracking list is left holding the one keyboard-cursor rectangle,
    with cursor number 2.

  Status stored: none.
}

{ TODO(pascal) frame of smd_$reset_display_globals not accounted

  The image's frame has 12 bytes; the code addresses no frame byte.  The
  module-local's slot (4) and the `with' slot of smd_$display_com[unit]
  (4) give 8 bytes; 4 are not explained (a `with' of smd_time_$com, a
  whole variable, would explain them, but SMD_$INIT_BLINK's three stores
  to it in a 4-byte frame with a boolean local argue against a `with'
  there).  dpc's frame for the routine as written is 8 bytes. }

procedure smd_$reset_display_globals(unit: integer; full: boolean);
  internal;
begin
  with smd_$display_com[unit] do begin
    cursor_pos.line := 0;
    cursor_pos.column := 0;
    cursor_number := 0;
    cursor_visible := false;
  end;
  smd_time_$com.blink_enable := false;
  smd_time_$com.cursor_painted := false;

  { the locator and the event ring, on a full reset }
  if full then begin
    saved_cursor_pos.line := 0;
    saved_cursor_pos.column := 0;
    last_button_state := 0;
    event_queue_head := 0;
    event_queue_tail := 0;
    flags_173c.field_173e := true;
    flags_173c.field_173f := true;
    flags_173c.field_173d := false;
  end;

  { blanking, the touch pad and tracking }
  blank_flags.blank_enabled := false;
  blank_flags.blank_pending := false;
  tp_cursor_timeout := -1;
  tp_reporting := 1;
  tracking_enabled := false;
  tracking_rect_count := 1;
  tracking_rects[1] := kbd_cursor_track_rect;
  tracking_cursor_num := 2;
  cursor_pending_flag := false;
end;
