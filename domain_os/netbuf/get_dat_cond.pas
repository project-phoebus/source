{ NETBUF_$GET_DAT_COND - take a data page from the free list, if any.

  Image addresses:
    sau2  0x00E0EF28  NETBUF_$GET_DAT_COND
    sau9  0x3C411386  NETBUF_$GET_DAT_COND

  - Under the spin lock, with a nonzero count, the head page leaves the
    list (its MMAP entry's prev_vpn word is the link) and its address is
    returned (true); with none the address is 0 (false).

  Status stored: none.
}

function netbuf_$get_dat_cond(out addr: integer32): boolean;
var
  ppn: integer32;
  token: pinteger;
begin
  token := ml_$spin_lock(netbuf_$spin_lock);

  if netbuf_$dat_cnt <> 0 then begin
    ppn := netbuf_$dat_top;
    netbuf_$dat_top := mmap[ppn].prev_vpn;
    netbuf_$dat_cnt := netbuf_$dat_cnt - 1;
    ml_$spin_unlock(netbuf_$spin_lock, token);
    addr := lshft(ppn, 10);
    netbuf_$get_dat_cond := true;
  end
  else begin
    ml_$spin_unlock(netbuf_$spin_lock, token);
    netbuf_$get_dat_cond := false;
    addr := 0;
  end;
end;
