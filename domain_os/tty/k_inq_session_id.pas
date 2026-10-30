{ TTY_$K_INQ_SESSION_ID - the session id of a line, for a caller of the
  kernel interface.

  Image addresses:
    sau2  0x00E679C4  TTY_$K_INQ_SESSION_ID

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_inq_session_id(in line: integer; out sid: integer;
                                out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  sid := tty_$desc_ptr_t(tty)^.session_id;
end;
