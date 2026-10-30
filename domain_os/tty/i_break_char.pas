{ tty_$i_break_char - take a break (line-ending) character: store it and
  commit the line.

  Image addresses:
    sau2  0x00E1B8B0  tty_$i_break_char

  - The character is stored and echoed (under tty_$if_echo), the input
    committed and the readers woken.
  - A pending signal (tty_$st_sig_pend) signals the process group; a
    writer waiting for input is woken.
  - saved_input_flags gets the column, as in TTY_$I_FLUSH_INPUT.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_break_char(var tty: tty_$desc_t; ch: char); internal;
begin
  tty_$i_buf_insert(ch, tty.input);

  { echo it }
  if tty_$if_echo in tty.input_flags then
    tty_$i_xmit_char(tty, ch);

  { commit the line and wake the readers }
  tty.input_head := tty.input.tail;
  tty.saved_input_flags := tty.column;
  tty_$i_advance_ec(tty.input_ec^);

  { a pending signal }
  if tty_$st_sig_pend in tty.state_flags then
    tty_$i_signal(tty, tty_$sig_winch);

  { wake a writer waiting for input }
  if tty_$st_input_wait in tty.state_flags then begin
    tty.state_flags := tty.state_flags - [tty_$st_input_wait];
    tty_$i_advance_ec(tty.output_ec^);
  end;
end;
