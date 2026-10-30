{ TTY_$K_INQ_FLAGS - whether a line's signal on input is on, for a caller
  of the kernel interface.

  Image addresses:
    sau2  0x00E6748C  TTY_$K_INQ_FLAGS

  - flags gets member 0 when the line's state has tty_$st_sig_pend.
  - Not reachable as a system call in this build: no SVC table entry or
    other reference holds its address.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_inq_flags(in line: integer; out flags: tty_$flags16_t;
                           out status: status_$t);
var
  tty: tty_$desc_ptr_t;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$desc_ptr_t(tty_$i_get_desc(line, status));
  if status.all <> status_$ok then
    return;
  flags := [];
  if tty_$st_sig_pend in tty^.state_flags then
    flags := flags + [0];
end;
