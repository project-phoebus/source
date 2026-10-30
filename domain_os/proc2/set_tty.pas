{ PROC2_$SET_TTY - record the caller's controlling TTY.

  Image addresses:
    sau2  0x00E41C04  PROC2_$SET_TTY

  - No lock.

  Status stored: none.
}

procedure proc2_$set_tty(in new_tty_uid: uid_$t);
begin
  with proc2_$info_table[proc2_$pid_to_index[proc1_$current]] do

    tty_uid := new_tty_uid;
end;
