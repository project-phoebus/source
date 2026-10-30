{ NETBUF_$DEL_PAGES - shrink the header and data page pools.

  Image addresses:
    sau2  0x00E0EB26  NETBUF_$DEL_PAGES
    sau9  0x3C410F7C  NETBUF_$DEL_PAGES

  - The header pages to free are the excess over 176, or the request
    down to 39 left; a negative count crashes the system.
  - That many header pages are taken off the free list, their slots
    given back and freed; the data pages are freed down to 10 left.

  Status stored: none.
}

procedure netbuf_$del_pages(hdr_pages: integer; data_pages: integer);
  options(val_param);
var
  ppn: integer32;
  va: integer32;
  token: pinteger;
  hdr_to_free: integer;
  dat_to_free: integer;
  i: integer;
begin
  token := ml_$spin_lock(netbuf_$spin_lock);
  if netbuf_hdr_alloc >= 176 then
    hdr_to_free := max(hdr_pages - (netbuf_hdr_alloc - 176), 0)
  else
    hdr_to_free := min(hdr_pages, netbuf_hdr_alloc - 39);
  if hdr_to_free < 0 then
    crash_system(status_$network_buffer_error);

  netbuf_hdr_alloc := netbuf_hdr_alloc - hdr_pages;
  ml_$spin_unlock(netbuf_$spin_lock, token);

  { the header pages }
  token := ml_$spin_lock(netbuf_$spin_lock);
  for i := 1 to hdr_to_free do begin
    va := netbuf_$hdr_top;
    netbuf_$hdr_top := netbuf_$hdr_page_ptr_t(va)^.next;
    mmap_$free(rshft(netbuf_rtnva_locked(va), 10));
  end;
  ml_$spin_unlock(netbuf_$spin_lock, token);

  { the data pages }
  token := ml_$spin_lock(netbuf_$spin_lock);
  dat_to_free := min(data_pages, netbuf_$dat_cnt - 10);
  for i := 1 to dat_to_free do begin
    ppn := netbuf_$dat_top;
    if ppn = 0 then exit;
    netbuf_$dat_top := mmap[ppn].prev_vpn;
    mmap_$free(ppn);
    netbuf_$dat_cnt := netbuf_$dat_cnt - 1;
  end;
  ml_$spin_unlock(netbuf_$spin_lock, token);
end;
