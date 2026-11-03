{ CBUF_$READ_NEXT - the block at a circular buffer's read end.

  Image addresses:
    sau3  0x00E6ECEE  CBUF_$READ_NEXT
    sau4  0x0F87BB2E  CBUF_$READ_NEXT

  - The result is the block's data and len its length; nil when the
    buffer is empty.  A zero length word sends the read end to the
    buffer's start; a zero length there crashes the system with
    status_$cbuf_wrap_around_error.

  Status stored: none.
}

function cbuf_$read_next(var cb: cbuf_$cb_t; out len: pinteger): univ_ptr;
begin
  if cb.write = cb.read then begin
    cbuf_$read_next := nil;
    return;
  end;
  len := cbuf_$word_ptr_t(cb.read)^;
  if len = 0 then begin
    cb.read := cb.base;
    if cb.write = cb.read then begin
      cbuf_$read_next := nil;
      return;
    end;
    len := cbuf_$word_ptr_t(cb.read)^;
    if len = 0 then
      crash_system(status_$cbuf_wrap_around_error);
  end;
  cbuf_$read_next := univ_ptr(cb.read + 2);
end;
