{ tty_$i_echo_char - echo one input character.

  Image addresses:
    sau2  0x00E1B3CE  tty_$i_echo_char

  - Under tty_$echo_cntl_with_hat, a control character other than TAB
    and LF is echoed as `^' and the character plus 64, DEL as `^?'; any
    other character as it is.
  - Each piece goes out through tty_$i_put_chars, keeping 12 bytes of
    the buffer back.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_echo_char(var tty: tty_$desc_t; ch: char); internal;
begin
  { the visible form, under echo_flags member 4
    (tty_$echo_cntl_with_hat),
    for the control characters other than TAB and LF, and for DEL }
  if (ch <> chr(9)) and then (ch <> chr(10))
     and then ((ch < ' ') or else (ch = chr(127)))
     and then (tty_$echo_cntl_with_hat in tty.echo_flags) then begin
    discard(tty_$i_put_chars(tty, '^', 1, 12));
    if ch <> chr(127) then
      discard(tty_$i_put_chars(tty, chr(ord(ch) + 64), 1, 12))
    else
      discard(tty_$i_put_chars(tty, '?', 1, 12));
  end
  else
    discard(tty_$i_put_chars(tty, ch, 1, 12));
end;
