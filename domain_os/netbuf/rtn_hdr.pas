{ NETBUF_$RTN_HDR - put a header page back on the free list.

  Image addresses:
    sau2  0x00E0EEB4  NETBUF_$RTN_HDR
    sau8  0x03C10202  NETBUF_$RTN_HDR

  - An address outside the window's 192 pages crashes the system;
    otherwise its page (the low ten bits cleared) is pushed on the
    header free list under the spin lock.

  Status stored: none.
}

procedure netbuf_$rtn_hdr(in va: integer32);
var
  slot: integer32;
  hdr: netbuf_$hdr_page_ptr_t;
  token: pinteger;
begin
  slot := (va - netbuf_$va_base_addr) div 1024;
  if (slot < 0) or else (slot > 191) then
    crash_system(status_$network_buffer_error);

  token := ml_$spin_lock(netbuf_$spin_lock);
  hdr := netbuf_$hdr_page_ptr_t(va & (-16#400));
  hdr^.next := netbuf_$hdr_top;
  netbuf_$hdr_top := integer32(hdr);
  ml_$spin_unlock(netbuf_$spin_lock, token);
end;
