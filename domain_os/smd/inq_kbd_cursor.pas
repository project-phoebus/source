{ SMD_$INQ_KBD_CURSOR - the current display's cursor position and
  visibility.

  Image addresses:
    sau2  0x00E6E0D4  SMD_$INQ_KBD_CURSOR
    sau4  0x0F87885C  SMD_$INQ_KBD_CURSOR
    sau5  0x00E70538  SMD_$INQ_KBD_CURSOR
    sau9  0x3C474A1A  SMD_$INQ_KBD_CURSOR

  - The result is whether the cursor is visible.
  - For an invalid current unit the position is not written and the
    result is not assigned.

  Status stored:
    status_$ok: always, an invalid unit too
}

function smd_$inq_kbd_cursor(out pos: smd_$pos_t;
                             out status: status_$t): boolean;
begin
  status.all := status_$ok;

  if smd_$validate_unit(default_unit) then
    with smd_$display_com[default_unit] do begin
      smd_$inq_kbd_cursor := cursor_visible;
      pos := cursor_pos;
    end;
end;
