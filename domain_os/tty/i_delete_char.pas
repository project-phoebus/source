{ tty_$i_delete_char - delete the last character of the input line and
  erase its echo.

  Image addresses:
    sau2  0x00E1B538  tty_$i_delete_char

  - An empty line is left alone; a line whose producer position is at
    the consumer's is committed up to it.  Emptying the line wakes a
    writer waiting for input (the output eventcount).
  - The echo is erased under tty_$if_echo: with BS (and a space, under
    tty_$echo_crt_erase) per column, with `\' once per run and the
    character again, or with the erase function character.
  - A control character or DEL is not erased without
    tty_$echo_cntl_with_hat.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_delete_char(var tty: tty_$desc_t); internal;
var
  tail: tty_$buf_pos_t;
  erase_count: tty_$uword_t;
  i: tty_$uword_t;
  ch: char;
  col: tty_$uword_t;
begin
  { nothing to delete, or nothing past the consumer position }
  tail := tty.input.tail;
  if tail = tty.input_head then
    return;
  if tail = tty.input.head then begin
    tty.input_head := tail;
    return;
  end;

  { back the producer position up one, 1 wraps to 256 }
  if tail = 1 then
    tty.input.tail := tty_$buf_size
  else
    tty.input.tail := tty.input.tail - 1;

  { the line is empty again; wake a writer waiting for input }
  if (tty.input.tail = tty.input_head)
     and then (tty_$st_input_wait in tty.state_flags) then begin
    tty.state_flags := tty.state_flags - [tty_$st_input_wait];
    tty_$i_advance_ec(tty.output_ec^);
  end;

  { nothing to erase without input echo }
  if not (tty_$if_echo in tty.input_flags) then
    return;

  ch := tty.input.data[tty.input.tail];

  { the columns the character's echo took }
  if ch = chr(9) then begin
    col := tty_$i_calc_column(tty.input, tty.input_head,
                              tty.saved_input_flags, tty.echo_flags);
    erase_count := 8 - (col & 7);
  end
  else if (ch < ' ') or else (ch = chr(127)) then begin
    if not (tty_$echo_cntl_with_hat in tty.echo_flags) then
      return;
    erase_count := 2;
  end
  else
    erase_count := 1;

  if tty_$echo_bs_erase in tty.echo_flags then
    { back over each column, blanking it under member 1
      (tty_$echo_crt_erase) }
    for i := 1 to erase_count do begin
      if tty_$echo_crt_erase in tty.echo_flags then begin
        tty_$i_xmit_char(tty, chr(8));
        tty_$i_xmit_char(tty, ' ');
      end;
      tty_$i_xmit_char(tty, chr(8));
    end
  else if tty_$echo_ptr_erase in tty.echo_flags then begin
    { `\' once per run, then the character }
    if not (7 in tty.state_flags) then
      tty_$i_xmit_char(tty, '\');
    if (ch < ' ') or else (ch = chr(127)) then begin
      tty_$i_xmit_char(tty, '^');
      if ch <> chr(127) then
        tty_$i_xmit_char(tty, chr(ord(ch) + 64))
      else
        tty_$i_xmit_char(tty, '?');
    end
    else
      tty_$i_xmit_char(tty, ch);
    tty.state_flags := tty.state_flags + [7];
  end
  else
    tty_$i_xmit_char(tty, tty.func_chars[tty_$func_erase]);
end;
