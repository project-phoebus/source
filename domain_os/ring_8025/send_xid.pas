{ ring_8025_send_xid - send an XID frame.

  Image addresses:
    sau9  0x3C485F6C  ring_8025_send_xid

  - Builds the frame in a header page: to dest_addr from this node's
    station address, with a routing field of only its control word rc
    when rc is not 0, then the LLC header (dsap, ssap, ctl) and the XID
    information (the unit's LLC classes, window 0).
  - Sent under the unit's transmit lock as one piece; fstat returns the
    frame status.  The header page is given back.

  Status stored:
    ring_8025_transmit's status: the frame was or was not sent
}

procedure ring_8025_send_xid(u: ring_8025_$unit_ptr_t;
                             in dest_addr: ring_8025_$addr_t;
                             rc: ring_8025_$word_t;
                             dsap: integer; ssap: integer; ctl: integer;
                             out fstat: integer; out status: status_$t);
  internal;
var
  pieces: ring_8025_$xmit_pieces_t;
  pa: integer32;
  va: integer32;
  len: integer;
  hdr: ring_8025_$mac_hdr_ptr_t;
  llc: ring_8025_$llc_ptr_t;
  rif_len: integer;
begin
  netbuf_$get_hdr(pa, va);
  rif_len := 0;
  hdr := ring_8025_$mac_hdr_ptr_t(va);
  with hdr^ do begin
    ac := r8025_ac;
    fc := r8025_fc_llc;
    dest.high := dest_addr.high;
    dest.low := dest_addr.low;
    src.high := r8025_addr_high;
    src.low := node_$me;
  end;
  if rc <> 0 then begin
    hdr^.src.rii := true;
    hdr^.rif.rc_word := rc;
    rif_len := 2;
  end;
  llc := ring_8025_$llc_ptr_t(integer32(addr(hdr^.rif)) + rif_len);
  llc^.dsap := dsap;
  llc^.ssap := ssap;
  llc^.ctl := ctl;
  llc^.xid_format := r8025_xid_format;
  llc^.xid_class := u^.llc_class;
  llc^.xid_window := 0;
  len := rif_len + 20;
  ml_$exclusion_start(u^.xmit_lock);
  pieces[1].pa := pa;
  pieces[1].cnt.len := len;
  ring_8025_transmit(u, len, pieces, 1, hdr^.dest, fstat, status);
  ml_$exclusion_stop(u^.xmit_lock);
  netbuf_$rtn_hdr(va);
end;
