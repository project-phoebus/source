{ tty_$i_put_output - write characters to a line's output buffer, unless
  typed-ahead input must be read first.

  Image addresses:
    sau2  0x00E1BF0E  tty_$i_put_output

  - Under tty_$if_polite, while uncommitted input waits, nothing is
    taken: the input-wait flag is set under the spin lock and the result
    is 0.  Otherwise tty_$i_put_chars' result.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function tty_$i_put_output(var tty: tty_$desc_t; in buf: univ tty_$chars_t;
                           count: tty_$uword_t; avail_hint: integer):
                           tty_$uword_t;
  internal;
var
  token: integer;
begin
  { uncommitted input waits to be read }
  if (tty_$if_polite in tty.input_flags)
     and then (tty.input.tail <> tty.input_head) then begin
    { note the wait, take nothing }
    token := ml_$spin_lock(tty_$spin_lock);
    tty.state_flags := tty.state_flags + [tty_$st_input_wait];
    ml_$spin_unlock(tty_$spin_lock, token);
    tty_$i_put_output := 0;
  end
  else
    { put them }
    tty_$i_put_output := tty_$i_put_chars(tty, buf, count, avail_hint);
end;
