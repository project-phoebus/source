{ TTY_$I_INTERRUPT - the line's interrupt condition: flush the input and
  signal SIGINT.

  Image addresses:
    sau2  0x00E1BEA8  TTY_$I_INTERRUPT

  - SIO_$I_RCV calls it through the SIO descriptor's special_rcv field,
    which TERM_$SET_REAL_LINE_DISCIPLINE sets from TERM_$DATA.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_interrupt(var tty: tty_$desc_t);
begin
  tty_$i_flush_input(tty);
  tty_$i_signal(tty, tty_$sig_int);
end;
