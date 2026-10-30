{ TTY_$K_SET_FLAG - turn a line's signal on input on or off, for a caller
  of the kernel interface.

  Image addresses:
    sau2  0x00E67422  TTY_$K_SET_FLAG

  - Flag 0 is the only one; any other number does nothing.  Setting it
    adds tty_$st_sig_pend, and signals the process group at once
    (tty_$sig_winch) when committed input is waiting already.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_flag(in line: integer; in flag: integer;
                          in value: boolean; out status: status_$t);
var
  tty: tty_$desc_ptr_t;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$desc_ptr_t(tty_$i_get_desc(line, status));
  if status.all <> status_$ok then
    return;
  if flag <> 0 then
    return;

  if value then begin
    tty^.state_flags := tty^.state_flags + [tty_$st_sig_pend];
    if tty^.input.head <> tty^.input_head then
      tty_$i_signal(tty^, tty_$sig_winch);
  end
  else
    tty^.state_flags := tty^.state_flags - [tty_$st_sig_pend];
end;
