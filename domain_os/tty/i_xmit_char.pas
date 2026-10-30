{ tty_$i_xmit_char - send one character to a line's output.

  Image addresses:
    sau2  0x00E1B3B4  tty_$i_xmit_char (module-local)

  - tty_$i_put_chars with a buffer of one, keeping 12 bytes of the
    output buffer back; its count is ignored.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_xmit_char(var tty: tty_$desc_t; ch: char); internal;
begin
  discard(tty_$i_put_chars(tty, ch, 1, 12));
end;
