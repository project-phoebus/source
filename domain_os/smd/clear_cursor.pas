{ SMD_$CLEAR_CURSOR - remove a cursor from the current process's display.

  Image addresses:
    sau2  0x00E6E0AA  SMD_$CLEAR_CURSOR
    sau4  0x0F878832  SMD_$CLEAR_CURSOR
    sau5  0x00E7050E  SMD_$CLEAR_CURSOR
    sau6  0x780778AA  SMD_$CLEAR_CURSOR

  Status stored:
    smd_$cursor_op's status: always
}

procedure smd_$clear_cursor(in cursor_num: integer; in pos: smd_$pos_t;
                            out status: status_$t);
begin
  smd_$cursor_op(cursor_num, pos, true, status);
end;
