{ TTY_$K_INQ_ECHO_FLAGS - the echo flags of a line, for a caller of the
  kernel interface.

  Image addresses:
    sau2  0x00E677E0  TTY_$K_INQ_ECHO_FLAGS

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_inq_echo_flags(in line: integer;
                                out flags: tty_$echo_flag_set_t;
                                out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  flags := tty_$desc_ptr_t(tty)^.echo_flags;
end;
