{ CBUF_$RELEASE - release the block at a circular buffer's read end.

  Image addresses:
    sau3  0x00E6ED4E  CBUF_$RELEASE
    sau4  0x0F87BB8E  CBUF_$RELEASE

  - The read end moves past the block at IPL 7, to the buffer's start
    when a zero length word follows.  A waiting writer is woken: at IPL
    0 by EC_$ADVANCE, at interrupt level by ADVANCE with interrupts
    disabled, and the routine returns with them disabled.

  Status stored: none.
}

procedure cbuf_$release(var cb: cbuf_$cb_t);
var
  old_sr: pinteger;
  n: pinteger;
  ipl: integer;
begin
  n := cbuf_$word_ptr_t(cb.read)^ + 2;
  if odd(n) then
    n := n + 1;
  old_sr := set_sr(16#2700);
  cb.read := cb.read + n;
  if (cb.read <> cb.write) and then (cbuf_$word_ptr_t(cb.read)^ = 0) then
    cb.read := cb.base;
  discard(set_sr(old_sr));
  if cb.waiting then begin
    ipl := rshft(old_sr, 8) & 7;
    if ipl = 0 then
      ec_$advance(cb.ec)
    else begin
      disable;
      advance(cb.ec);
    end;
  end;
end;
