{ ethernet_get_rcv_bufs_cond - give a unit a header and a data page to
  receive into, at interrupt level.

  Image addresses:
    sau8  0x03C888B6  ethernet_get_rcv_bufs_cond
    sau9  0x3C4844B6  ethernet_get_rcv_bufs_cond

  - ethernet_get_rcv_bufs without waiting: the pages are taken only if
    they are free.  The result is true when the unit has both; a header
    page taken without a data page goes back.

  Status stored: none.
}

function ethernet_get_rcv_bufs_cond(u: ethernet_$unit_ptr_t): boolean;
  internal;
var
  phys: integer32;
begin
  if netbuf_$get_hdr_cond(phys, u^.hdr_va) then begin
    if u^.spare_dat <> 0 then begin
      u^.dat_va := u^.spare_dat;
      u^.spare_dat := 0;
      ethernet_get_rcv_bufs_cond := true;
      return;
    end
    else if netbuf_$get_dat_cond(u^.dat_va) then begin
      ethernet_get_rcv_bufs_cond := true;
      return;
    end;
    netbuf_$rtn_hdr(u^.hdr_va);
  end;
  ethernet_get_rcv_bufs_cond := false;
end;
