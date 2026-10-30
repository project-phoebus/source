{ TTY_$K_SET_DELAY - set one of a line's output delays, for a caller of
  the kernel interface.

  Image addresses:
    sau2  0x00E67A02  TTY_$K_SET_DELAY

  - The delay is tested, before the line is looked up, with a set
    constant: a word of 32 or more is taken modulo 32, so 32..36 pass
    as 0..4.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
    status_$tty_invalid_option: delay is not tty_$delay_nl..tty_$delay_ff
}

procedure tty_$k_set_delay(in line: integer; in delay: tty_$delay_t;
                           in val: pinteger; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  { only the delays the descriptor stores }
  if not (delay in [tty_$delay_nl..tty_$delay_ff]) then begin
    status.all := status_$tty_invalid_option;
    return;
  end;

  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  tty_$desc_ptr_t(tty)^.delay[delay] := val;
end;
