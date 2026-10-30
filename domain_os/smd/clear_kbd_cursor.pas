{ SMD_$CLEAR_KBD_CURSOR - hide the cursor behind the keyboard cursor.

  Image addresses:
    sau2  0x00E6E828  SMD_$CLEAR_KBD_CURSOR
    sau5  0x00E70CA6  SMD_$CLEAR_KBD_CURSOR
    sau9  0x3C47521C  SMD_$CLEAR_KBD_CURSOR

  - The keyboard cursor's rectangle joins the tracking list.

  Status stored:
    smd_$add_trk_rect's status: always
}

procedure smd_$clear_kbd_cursor(out status: status_$t);
begin
  smd_$add_trk_rect(kbd_cursor_track_rect, 1, status);
end;
