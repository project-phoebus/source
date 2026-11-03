{ NETBUF_$GET_HDR_COND - take a header page from the free list, if any.

  Image addresses:
    sau2  0x00E0ED6C  NETBUF_$GET_HDR_COND
    sau8  0x03C100BE  NETBUF_$GET_HDR_COND

  - Under the spin lock va gets the list's head; a nil head means none
    (false, phys not written).  Otherwise the head moves on and, after
    the lock, phys gets the page's physical address (true).

  Status stored: none.
}

function netbuf_$get_hdr_cond(out phys: integer32; out va: integer32):
  boolean;
var
  token: pinteger;
  hdr: netbuf_$hdr_page_ptr_t;
begin
  token := ml_$spin_lock(netbuf_$spin_lock);
  va := netbuf_$hdr_top;

  hdr := netbuf_$hdr_page_ptr_t(va);
  if hdr <> nil then begin
    netbuf_$hdr_top := hdr^.next;
    ml_$spin_unlock(netbuf_$spin_lock, token);
    phys := hdr^.phys;
    netbuf_$get_hdr_cond := true;
  end
  else begin
    ml_$spin_unlock(netbuf_$spin_lock, token);
    netbuf_$get_hdr_cond := false;
  end;
end;
