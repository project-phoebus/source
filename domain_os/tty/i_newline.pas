{ tty_$i_newline - echo a new line.

  Image addresses:
    sau2  0x00E1B456  tty_$i_newline

  - LF then CR; only CR under tty_$of_cr_to_crnl, only LF under
    tty_$of_nl_to_crnl.  Each goes out through tty_$i_put_chars,
    keeping 12 bytes of the buffer back.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_newline(var tty: tty_$desc_t); internal;
var
  send_lf: boolean;
  send_cr: boolean;
begin
  send_lf := true;
  send_cr := true;

  { member 0 (tty_$of_cr_to_crnl), CR only; member 1
    (tty_$of_nl_to_crnl), LF only }
  if tty_$of_cr_to_crnl in tty.output_flags then
    send_lf := false
  else if tty_$of_nl_to_crnl in tty.output_flags then
    send_cr := false;

  if send_lf then
    discard(tty_$i_put_chars(tty, chr(10), 1, 12));
  if send_cr then
    discard(tty_$i_put_chars(tty, chr(13), 1, 12));
end;
