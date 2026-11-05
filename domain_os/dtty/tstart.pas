{ DTTY_$TSTART - drain a line's output buffer to the display.

  Image addresses:
    sau2  0x00E1D6D0  DTTY_$TSTART
    sau4  0x0F81E9F0  DTTY_$TSTART
    sau6  0x7801F940  DTTY_$TSTART
    sau7  0x3C421980  DTTY_$TSTART

  - A resume position past the target means the buffer has wrapped: the
    part to the buffer's end goes first.
  - The line record's callback is called with its argument at the end.

  Status stored: none.
}

procedure dtty_$tstart(tstart: dtty_tstart_ptr_t); options(val_param);
var
  buf: dtty_buffer_ptr_t;
  length: integer;
  current: pinteger;
begin
  { the wrapped part }
  buf := tstart^.buffer_info;
  current := buf^.current;
  if current > buf^.target then begin
    length := buf^.end_pos + 1 - current;
    dtty_$write_string(buf^.data[current], length);
    buf^.current := 1;
  end;

  { up to the target }
  current := buf^.current;
  if current < buf^.target then begin
    length := buf^.target - current;
    dtty_$write_string(buf^.data[current], length);
    buf^.current := buf^.target;
  end;

  tstart^.callback^(tstart^.callback_arg);
end;
