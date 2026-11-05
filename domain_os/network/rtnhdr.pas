{ NETWORK_$RTNHDR - give back a header page NETWORK_$GETHDR handed out.

  Image addresses:
    sau2  0x00E0F414  NETWORK_$RTNHDR
    sau6  0x7800FD84  NETWORK_$RTNHDR
    sau7  0x3C41129C  NETWORK_$RTNHDR
    sau8  0x03C1074C  NETWORK_$RTNHDR

  - The module's own header page is given back by releasing the network
    transmit lock; any other page is unmapped (NETBUF_$RTNVA) and its
    frame freed (MMAP_$FREE).

  Status stored: none.
}

procedure network_$rtnhdr(in va: pkt_$hdr_ptr_t);
var
  pa: integer32;
begin
  if va <> network_$hdr_page then begin
    { a page of its own }
    pa := netbuf_$rtnva(va);
    mmap_$free(rshft(pa, 10));
  end
  else
    { the module's header page }
    ml_$unlock(ml_$net_io_lock);
end;
