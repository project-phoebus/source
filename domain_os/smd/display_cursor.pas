{ SMD_$DISPLAY_CURSOR - draw a cursor on the current process's display.

  Image addresses:
    sau2  0x00E6E080  SMD_$DISPLAY_CURSOR
    sau5  0x00E704E4  SMD_$DISPLAY_CURSOR

  Status stored:
    smd_$cursor_op's status: always
}

procedure smd_$display_cursor(in cursor_num: integer; in pos: smd_$pos_t;
                              out status: status_$t);
begin
  smd_$cursor_op(cursor_num, pos, false, status);
end;
