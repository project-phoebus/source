{ TTY_$K_SET_INPUT_FLAG - turn one input flag of a line on or off, for a
  caller of the kernel interface.

  Image addresses:
    sau2  0x00E67656  TTY_$K_SET_INPUT_FLAG

  - The flag is not checked: the set operation takes it modulo 32.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_input_flag(in line: integer;
                                in flag: tty_$input_flag_t;
                                in value: boolean; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  if value then
    tty_$desc_ptr_t(tty)^.input_flags := tty_$desc_ptr_t(tty)^.input_flags + [flag]
  else
    tty_$desc_ptr_t(tty)^.input_flags := tty_$desc_ptr_t(tty)^.input_flags - [flag];
end;
