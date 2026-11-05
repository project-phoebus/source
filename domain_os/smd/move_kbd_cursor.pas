{ SMD_$MOVE_KBD_CURSOR - move the keyboard cursor.

  Image addresses:
    sau2  0x00E6E7FA  SMD_$MOVE_KBD_CURSOR
    sau4  0x0F878F8C  SMD_$MOVE_KBD_CURSOR
    sau5  0x00E70C78  SMD_$MOVE_KBD_CURSOR
    sau6  0x78077FEC  SMD_$MOVE_KBD_CURSOR
    sau7  0x3C481ACE  SMD_$MOVE_KBD_CURSOR
    sau9  0x3C4751EE  SMD_$MOVE_KBD_CURSOR

  - The tracking list is emptied after the move.
  - The move's status is overwritten by the second call's.

  Status stored:
    smd_$clr_trk_rect's status: always (it overwrites the move's)
}

procedure smd_$move_kbd_cursor(in pos: smd_$pos_t; out status: status_$t);
begin
  smd_$set_cursor_pos(pos, status);
  smd_$clr_trk_rect(status);
end;
