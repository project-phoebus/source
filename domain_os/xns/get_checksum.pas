{ xns_$get_checksum - the IDP checksum of a packet.

  Image addresses:
    sau2  0x00E17D46  xns_$get_checksum

  - The IDP header from its length word, the header chain's other
    buffers, then the data pages (at most 1024 bytes of each) are
    summed.  -1 when the bytes summed exceed the IDP length plus 1, or a
    data page is missing or cannot be mapped.
  - NETBUF_$GETVA is given the first data page for every page.

  Status stored: none.
}

function xns_$get_checksum(in pkt: univ xns_$mac_pkt_t): integer; internal;
var
  st: status_$t;
  page_va: integer32;
  hdr: xns_$idp_header_ptr_t;
  total: integer32;
  node: xns_$buf_desc_ptr_t;
  va: integer32;
  sum: integer;
  page: integer;
  words: integer;
  chunk: integer;
begin
  hdr := xns_$idp_header_ptr_t(pkt.hdr_desc.address);
  total := pkt.hdr_desc.length;
  if hdr^.length + 1 < total then begin
    xns_$get_checksum := -1;
    return;
  end;

  words := (total - 1) div 2;
  va := integer32(addr(hdr^.length));
  sum := xns_idp_$checksum(va, words);

  node := pkt.hdr_desc.next;
  while node <> nil do begin
    va := node^.address;
    total := total + node^.length;
    if hdr^.length + 1 < total then begin
      xns_$get_checksum := -1;
      return;
    end;
    words := (node^.length + 1) div 2;
    sum := sum + xns_idp_$checksum(va, words);
    node := node^.next;
  end;

  if pkt.data.length > 0 then
    for page := 1 to 4 do begin
      chunk := min(pkt.data.length - (page - 1) * 1024, 1024);
      if pkt.data.pages[page] = 0 then begin
        if chunk <= 0 then
          return;
        xns_$get_checksum := -1;
        return;
      end;
      if chunk <= 0 then
        return;
      total := total + chunk;
      if hdr^.length + 1 < total then begin
        xns_$get_checksum := -1;
        return;
      end;
      netbuf_$getva(pkt.data.pages[1], page_va, st);
      if st.all <> status_$ok then begin
        xns_$get_checksum := -1;
        return;
      end;
      chunk := (chunk + 1) div 2;
      sum := sum + xns_idp_$checksum(page_va, chunk);
      discard(netbuf_$rtnva(page_va));
    end;

  xns_$get_checksum := sum;
end;
