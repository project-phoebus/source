{ TTY_$K_INQ_FUNC_CHAR - the character bound to a function slot of a
  line, for a caller of the kernel interface.

  Image addresses:
    sau2  0x00E67554  TTY_$K_INQ_FUNC_CHAR

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
    status_$tty_invalid_function: func is beyond tty_$func_reserved_18
      (ch is NUL)
}

procedure tty_$k_inq_func_char(in line: integer; in func: tty_$func_t;
                               out ch: char; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  if not in_range(func) or else
     (func > tty_$func_reserved_18) then begin
    ch := chr(0);
    status.all := status_$tty_invalid_function;
    return;
  end;

  ch := tty_$desc_ptr_t(tty)^.func_chars[func];
end;
