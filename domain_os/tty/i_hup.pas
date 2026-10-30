{ TTY_$I_HUP - the line's hangup condition: forget the session, flush both
  directions and signal SIGHUP and SIGCONT.

  Image addresses:
    sau2  0x00E1BECE  TTY_$I_HUP

  - SIO_$I_DCD_CHANGE calls it through the SIO descriptor's dcd_handler
    field, which TERM_$SET_REAL_LINE_DISCIPLINE sets from TERM_$DATA.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_hup(var tty: tty_$desc_t);
begin
  tty.session_id := 0;
  tty_$i_flush_input(tty);
  tty_$i_flush_output(tty);
  tty_$i_signal(tty, tty_$sig_hup);
  tty_$i_signal(tty, tty_$sig_cont);
end;
