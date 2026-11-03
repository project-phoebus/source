{ CBUF_$INIT_CB - set up a circular buffer's control block.

  Image addresses:
    sau3  0x00E6EAE4  CBUF_$INIT_CB
    sau4  0x0F87B924  CBUF_$INIT_CB

  - The buffer is empty: both ends at its start.

  Status stored: none.
}

procedure cbuf_$init_cb(out cb: cbuf_$cb_t; var buf: univ cbuf_$buffer_t;
                        in size: pinteger);
begin
  cb.base := linteger(addr(buf));
  cb.read := cb.base;
  cb.write := cb.base;
  cb.size := size;
  ec_$init(cb.ec);
  cb.waiting := false;
end;
