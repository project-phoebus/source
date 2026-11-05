{ ethernet_get_rcv_bufs - give a unit a header and a data page to
  receive into.

  Image addresses:
    sau6  0x78086BF0  ethernet_get_rcv_bufs
    sau7  0x3C49152A  ethernet_get_rcv_bufs
    sau8  0x03C84D26  ethernet_get_rcv_bufs
    sau9  0x3C480926  ethernet_get_rcv_bufs

  - The header page is a new one; the data page is the one kept back,
    if there is one, else a new one.

  Status stored: none.
}

procedure ethernet_get_rcv_bufs(u: ethernet_$unit_ptr_t); internal;
var
  phys: integer32;
begin
  netbuf_$get_hdr(phys, u^.hdr_va);
  if u^.spare_dat = 0 then
    netbuf_$get_dat(u^.dat_va)
  else begin
    u^.dat_va := u^.spare_dat;
    u^.spare_dat := 0;
  end;
end;
