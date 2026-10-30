{ TTY_$K_INQ_DELAY - one of a line's output delays, for a caller of the
  kernel interface.

  Image addresses:
    sau2  0x00E67A58  TTY_$K_INQ_DELAY

  - TTY_$K_SET_DELAY with the word copied the other way.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
    status_$tty_invalid_option: delay is not tty_$delay_nl..tty_$delay_ff
}

procedure tty_$k_inq_delay(in line: integer; in delay: tty_$delay_t;
                           out val: pinteger; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  if not (delay in [tty_$delay_nl..tty_$delay_ff]) then begin
    status.all := status_$tty_invalid_option;
    return;
  end;

  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  val := tty_$desc_ptr_t(tty)^.delay[delay];
end;
