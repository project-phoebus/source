{ NETBUF_$ADD_PAGES - grow the header and data page pools.

  Image addresses:
    sau2  0x00E0E928  NETBUF_$ADD_PAGES
    sau8  0x03C0FCA0  NETBUF_$ADD_PAGES
    sau9  0x3C410D8C  NETBUF_$ADD_PAGES

  - The requests are clamped to the room under 176 header pages and the
    data limit; more than 128 pages at once crashes the system.
  - The header pages are wired, mapped into the window (and made
    uncached with `netbuf_cache_inhibit'), cleared and pushed on the
    header free list; the data pages go on the data free
    list.
  - The trim of an over-full data pool passes NETBUF_$DEL_PAGES the
    count dat_lim - dat_cnt.

  Status stored: none.
}

procedure netbuf_$add_pages(hdr_pages: integer; data_pages: integer);
  options(val_param);
var
  zero16: pkt_$data_pages_t;
  pages: array[1..128] of integer32;
  status: status_$t;
  va: integer32;
  token: pinteger;
  hdr_take: integer;
  dat_take: integer;
  total: integer;
  i: integer;
  j: integer;
  unused_228: integer32;                  { stand-in }
begin
  token := ml_$spin_lock(netbuf_$spin_lock);

  { the counts within the pools' limits }
  if netbuf_hdr_alloc >= 176 then
    hdr_take := 0
  else
    hdr_take := min(hdr_pages, 176 - netbuf_hdr_alloc);
  dat_take := min(data_pages, netbuf_$dat_lim - netbuf_$dat_cnt);

  total := hdr_take + dat_take;
  if total > 128 then
    crash_system(status_$network_buffer_error);

  netbuf_hdr_alloc := netbuf_hdr_alloc + hdr_pages;
  ml_$spin_unlock(netbuf_$spin_lock, token);

  if total > 0 then
    wp_$calloc_list(total, pages);

  for i := 1 to 4 do
    zero16[i] := 0;

  { the header pages }
  for i := 1 to hdr_take do begin
    netbuf_$getva(lshft(pages[i], 10), va, status);
    if status.all <> status_$ok then
      crash_system(status);
%if netbuf_cache_inhibit %then
    mmu_$cache_inhibit_va(univ_ptr(va));
%endif
    with netbuf_$hdr_page_ptr_t(va)^ do begin
      data_len := 0;
      hdr_len := 0;
      phys := lshft(pages[i], 10);
      data_ptrs := zero16;
      token := ml_$spin_lock(netbuf_$spin_lock);
      next := netbuf_$hdr_top;
      netbuf_$hdr_top := va;
      ml_$spin_unlock(netbuf_$spin_lock, token);
    end;
  end;

  { the data pages }
  if dat_take > 0 then begin
    for j := hdr_take + 1 to total - 1 do
      mmap[pages[j]].prev_vpn := pages[j + 1];
    token := ml_$spin_lock(netbuf_$spin_lock);
    mmap[pages[total]].prev_vpn := netbuf_$dat_top;
    netbuf_$dat_top := pages[hdr_take + 1];
    netbuf_$dat_cnt := netbuf_$dat_cnt + dat_take;
    ml_$spin_unlock(netbuf_$spin_lock, token);
  end;

  if netbuf_$dat_cnt > netbuf_$dat_lim then
    netbuf_$del_pages(0, netbuf_$dat_lim - netbuf_$dat_cnt);
end;
