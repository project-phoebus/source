{ NETBUF_$RTNVA - give back a buffer page's slot of the window.

  Image addresses:
    sau2  0x00E0ED26  NETBUF_$RTNVA

  - Under the spin lock, netbuf_rtnva_locked's result: the page's
    physical address.

  Status stored: none.
}

function netbuf_$rtnva(in va: univ integer32): integer32;
var
  token: pinteger;
begin
  token := ml_$spin_lock(netbuf_$spin_lock);
  netbuf_$rtnva := netbuf_rtnva_locked(va);
  ml_$spin_unlock(netbuf_$spin_lock, token);
end;
