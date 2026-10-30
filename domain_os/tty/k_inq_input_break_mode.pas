{ TTY_$K_INQ_INPUT_BREAK_MODE - a line's input break mode, for a caller
  of the kernel interface.

  Image addresses:
    sau2  0x00E678BC  TTY_$K_INQ_INPUT_BREAK_MODE

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_inq_input_break_mode(in line: integer;
                                      out mode: tty_$input_break_mode_t;
                                      out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  mode := tty_$desc_ptr_t(tty)^.break_mode;
end;
