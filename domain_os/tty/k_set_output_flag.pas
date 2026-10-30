{ TTY_$K_SET_OUTPUT_FLAG - turn one output flag of a line on or off, for
  a caller of the kernel interface.

  Image addresses:
    sau2  0x00E676EE  TTY_$K_SET_OUTPUT_FLAG

  - TTY_$K_SET_INPUT_FLAG on output_flags; the flag is not checked.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_output_flag(in line: integer;
                                 in flag: tty_$output_flag_t;
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
    tty_$desc_ptr_t(tty)^.output_flags := tty_$desc_ptr_t(tty)^.output_flags + [flag]
  else
    tty_$desc_ptr_t(tty)^.output_flags := tty_$desc_ptr_t(tty)^.output_flags - [flag];
end;
