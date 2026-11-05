{ NETWORK_$GETHDR - a packet header page for a send.

  Image addresses:
    sau2  0x00E0F37A  NETWORK_$GETHDR
    sau6  0x7800FCEA  NETWORK_$GETHDR
    sau7  0x3C411202  NETWORK_$GETHDR
    sau8  0x03C106B2  NETWORK_$GETHDR

  - A send that stays on this node (loopback on, or the destination this
    node) gets a wired page of its own, mapped into the network buffer
    window (a failure crashes the system).
  - Any other send takes the module's one header page under the network
    transmit lock, which NETWORK_$RTNHDR releases.  If the page is not
    there yet, the lock is released at once.

  Status stored: none.
}

procedure network_$gethdr(in node: integer32; out va: pkt_$hdr_ptr_t;
                          out pa: integer32);
var
  ppn: integer32;
  status: status_$t;
begin
  if network_$loopback_flag or else (node = node_$me) then begin
    { a page of the send's own }
    wp_$calloc(ppn, status);
    pa := lshft(ppn, 10);
    netbuf_$getva(pa, va, status);
    if status.all <> status_$ok then
      crash_system(status);
  end
  else begin
    { the module's header page, under the lock }
    ml_$lock(ml_$net_io_lock);
    va := network_$hdr_page;
    pa := network_$hdr_page_pa;
    if va = nil then
      ml_$unlock(ml_$net_io_lock);
  end;
end;
