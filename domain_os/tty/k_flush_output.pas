{ TTY_$K_FLUSH_OUTPUT - discard a line's buffered output, for a caller of
  the kernel interface.

  Image addresses:
    sau2  0x00E1C0E6  TTY_$K_FLUSH_OUTPUT

  - TTY_$K_FLUSH_INPUT with TTY_$I_FLUSH_OUTPUT; the TODO is
    TTY_$K_FLUSH_INPUT's.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

[section(wired_proc, wired_data)]
procedure tty_$k_flush_output(in line: integer; out status: status_$t);
var
  tty: integer32;
  token: integer;
  unused_c: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  { flush with the spin lock held }
  token := ml_$spin_lock(tty_$spin_lock);
  tty_$i_flush_output(tty_$desc_ptr_t(tty)^);
  ml_$spin_unlock(tty_$spin_lock, token);
end;
