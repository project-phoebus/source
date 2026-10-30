{ PROC2_$GET_TTY_DATA - the caller's TTY UID and session id.

  Image addresses:
    sau2  0x00E41BB8  PROC2_$GET_TTY_DATA

  - The TTY UID (+0x60) and the session id (+0x5C).  Nothing in the
    image references it.

  Status stored: none.
}

procedure proc2_$get_tty_data(out tty_uid: uid_$t;
                              out tty_flags: integer);
begin
  tty_uid := proc2_$info_table[proc2_$pid_to_index[proc1_$current]].tty_uid;

  tty_flags :=
    proc2_$info_table[proc2_$pid_to_index[proc1_$current]].session_id;

end;
