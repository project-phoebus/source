{ NETBUF_$RTN_DAT - give back a data page.

  Image addresses:
    sau2  0x00E0F046  NETBUF_$RTN_DAT
    sau8  0x03C10390  NETBUF_$RTN_DAT
    sau9  0x3C4114A0  NETBUF_$RTN_DAT

  - Under the spin lock, while the data pool is under its limit
    (unsigned), the page goes on the data free list (its MMAP entry's
    prev_vpn word the link); otherwise it is freed after the lock.

  Status stored: none.
}

procedure netbuf_$rtn_dat(addr: integer32);
  options(val_param);
var
  ppn: integer32;
  token: pinteger;
begin
  ppn := rshft(addr, 10);
  token := ml_$spin_lock(netbuf_$spin_lock);

  if netbuf_$dat_cnt < netbuf_$dat_lim then begin
    mmap[ppn].prev_vpn := netbuf_$dat_top;
    netbuf_$dat_top := ppn;
    netbuf_$dat_cnt := netbuf_$dat_cnt + 1;
    ml_$spin_unlock(netbuf_$spin_lock, token);
  end
  else begin
    ml_$spin_unlock(netbuf_$spin_lock, token);
    mmap_$free(ppn);
  end;
end;
