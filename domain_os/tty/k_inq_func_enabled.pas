{ TTY_$K_INQ_FUNC_ENABLED - the enabled function slots of a line, for a
  caller of the kernel interface.

  Image addresses:
    sau2  0x00E67618  TTY_$K_INQ_FUNC_ENABLED

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_inq_func_enabled(in line: integer;
                                  out enabled: tty_$func_set_t;
                                  out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  enabled := tty_$desc_ptr_t(tty)^.func_enabled;
end;
