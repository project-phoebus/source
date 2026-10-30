{ TTY_$K_ENABLE_FUNC - enable or disable a function slot of a line, for
  a caller of the kernel interface.

  Image addresses:
    sau2  0x00E675AE  TTY_$K_ENABLE_FUNC

  - The slot is not checked: the set operation takes it modulo 32.
    Unless the line is raw the default functions are bound again.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_enable_func(in line: integer; in func: tty_$func_t;
                             in enable: boolean; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  if enable then
    tty_$desc_ptr_t(tty)^.func_enabled := tty_$desc_ptr_t(tty)^.func_enabled + [func]
  else
    tty_$desc_ptr_t(tty)^.func_enabled := tty_$desc_ptr_t(tty)^.func_enabled - [func];

  if not tty_$desc_ptr_t(tty)^.raw_mode then
    tty_$i_set_dfl_funcs(tty_$desc_ptr_t(tty)^, true);
end;
