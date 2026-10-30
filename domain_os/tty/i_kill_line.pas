{ tty_$i_kill_line - discard the uncommitted input line.

  Image addresses:
    sau2  0x00E1B6AC  tty_$i_kill_line

  - Under tty_$echo_crt_kill the line is erased character by character.
    Otherwise the kill character is echoed, and a newline under
    tty_$echo_kill_nl, and the line dropped at once.
  - The store into input_head only happens when the two positions
    differ; the guard is the image's and is kept.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_kill_line(var tty: tty_$desc_t); internal;
var
  tail: tty_$buf_pos_t;
begin
  { erase the line one character at a time }
  if tty_$echo_crt_kill in tty.echo_flags then begin
    while tty.input.tail <> tty.input_head do
      tty_$i_delete_char(tty);
    return;
  end;

  { echo the kill character, and a newline }
  tty_$i_echo_char(tty, tty.func_chars[tty_$func_kill]);
  if tty_$echo_kill_nl in tty.echo_flags then
    tty_$i_newline(tty);

  { drop the line }
  tail := tty.input.tail;
  if tail = tty.input.head then begin
    if tail <> tty.input_head then
      tty.input_head := tail;
  end
  else
    tty.input.tail := tty.input_head;
end;
