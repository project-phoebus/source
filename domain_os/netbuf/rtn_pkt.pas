{ NETBUF_$RTN_PKT - give back a packet's header page, window slot and
  data pages.

  Image addresses:
    sau2  0x00E0F0C6  NETBUF_$RTN_PKT

  - A nonzero header address goes to NETBUF_$RTN_HDR, a nonzero window
    address to NETBUF_$RTNVA; then one data page per 1024 bytes of
    dat_len to NETBUF_$RTN_DAT, from dat_arr's first element on.

  Status stored: none.
}

{ TODO(pascal) NETBUF_$RTN_PKT's index i is never formed

  The SAU2 loop reaches dat_arr[i] through a pointer stepped by 4, and i
  itself is kept nowhere: strength reduction of a `while' loop's
  variable, with the variable eliminated.  Stepped pointers are known
  for `for' loops only, and a `for' cannot be the source here. }

procedure netbuf_$rtn_pkt(var hdr: integer32; var va: integer32;
                          in dat_arr: pkt_$data_pages_t; dat_len: integer);
  options(val_param);
var
  i: integer;                             { never formed: see the TODO }
begin
  if hdr <> 0 then
    netbuf_$rtn_hdr(hdr);
  if va <> 0 then
    discard(netbuf_$rtnva(va));

  i := 1;
  while dat_len > 0 do begin
    netbuf_$rtn_dat(dat_arr[i]);
    dat_len := dat_len - 1024;
    i := i + 1;
  end;
end;
