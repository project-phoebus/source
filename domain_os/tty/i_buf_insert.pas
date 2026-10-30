{ tty_$i_buf_insert - put one character into a TTY circular buffer,
  without the spin lock.

  Image addresses:
    sau2  0x00E1AF0A  tty_$i_buf_insert

  Assume we're called with the TTY spin lock held, or at interrupt
  level.

  - tty_$i_buf_put's body without its lock calls.  A full buffer drops
    the character.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_buf_insert(ch: char; var buf: tty_$cbuf_t); internal;
var
  new_tail: tty_$buf_pos_t;
begin
  { the next producer position, 256 wraps to 1 }
  if buf.tail = tty_$buf_size then
    new_tail := 1
  else
    new_tail := buf.tail + 1;

  { the buffer is full when the next position is the consumer's; the
    character is dropped }
  if new_tail <> buf.head then begin
    buf.data[buf.tail] := ch;
    buf.tail := new_tail;
  end;
end;
