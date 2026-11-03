{ CBUF_$MAKE_VISIBLE - make an allocated block readable.

  Image addresses:
    sau3  0x00E6ECB6  CBUF_$MAKE_VISIBLE
    sau4  0x0F87BAF6  CBUF_$MAKE_VISIBLE

  - data is CBUF_$ALLOCATE's result; the write end moves past the
    block.

  Status stored: none.
}

procedure cbuf_$make_visible(var cb: cbuf_$cb_t; in data: univ_ptr);
var
  entry: linteger;
  n: pinteger;
begin
  entry := linteger(data) - 2;
  n := cbuf_$word_ptr_t(entry)^ + 2;
  if odd(n) then
    n := n + 1;
  cb.write := entry + n;
end;
