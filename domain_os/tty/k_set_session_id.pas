{ TTY_$K_SET_SESSION_ID - set the session id of a line, for a caller of
  the kernel interface.

  Image addresses:
    sau2  0x00E67986  TTY_$K_SET_SESSION_ID

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_session_id(in line: integer; in sid: integer;
                                out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  tty_$desc_ptr_t(tty)^.session_id := sid;
end;
