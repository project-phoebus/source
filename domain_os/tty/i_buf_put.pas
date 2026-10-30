{ tty_$i_buf_put - put one character into a TTY circular buffer.

  Image addresses:
    sau2  0x00E1AF42  tty_$i_buf_put

  - Under the TTY spin lock.  A full buffer drops the character.
  - The store is written out between the lock calls instead of calling
    tty_$i_buf_insert.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_buf_put(ch: char; var buf: tty_$cbuf_t); internal;
var
  token: integer;
  new_tail: tty_$buf_pos_t;
begin
  token := ml_$spin_lock(tty_$spin_lock);

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

  ml_$spin_unlock(tty_$spin_lock, token);
end;
