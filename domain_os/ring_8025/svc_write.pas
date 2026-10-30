{ RING_8025_$SVC_WRITE - send a frame on a user channel.

  Image addresses:
    sau9  0x3C487E78  RING_8025_$SVC_WRITE

  - The driver record's svc_write entry.  Under a cleanup handler the
    caller's vector, the whole frame from its MAC header on, is gathered
    into a fresh header page (952 bytes at most) and data pages (the
    rest, a page each, through the unit's first window page).
  - With source routing on a channel whose frames lose their routing
    field, the destination's route is found (ring_8025_find_route) and
    the LLC header moved after the routing field; on such a channel the
    source address is this node's station address, with the routing
    field marked.  The frame goes out under the unit's transmit lock.
  - The pages go back after the transmit; on a fault the header page if
    one is held and the data pages taken.

  Status stored:
    ring_8025_transmit's status: the frame was sent, or not
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_device_offline: the unit is not on line
    status_$r8025_channel_not_open: channel is 0, above 10 or not open
    status_$r8025_illegal_frame_length: the frame is shorter than a MAC
      and LLC header, or longer than the largest the ring takes
    fim_$cleanup's status: a fault
}

procedure ring_8025_$svc_write(var unit: pinteger; var channel: pinteger;
                               unused3: integer; var unused4: univ integer32;
                               var iov: univ ring_8025_$iov_array_t;
                               iov_cnt: integer;
                               var unused7: univ integer32;
                               out status: status_$t);
  options(val_param);
var
  crec: fim_$cleanup_rec_t;
  data_pa: pkt_$data_pages_t;
  pieces: array[1..5] of ring_8025_$xmit_piece_t;
  u: ring_8025_$unit_ptr_t;
  cleanup_status: status_$t;
  xstatus: status_$t;
  h: ring_8025_$mac_hdr_ptr_t;
  hdr_pa: integer32;
  hdr_va: integer32;
  llc: ring_8025_$llc_ptr_t;
  pa: integer32;
  total: pinteger;
  fstat: integer;
  rlen: integer;
  rest: pinteger;
  max_len: integer;
  off: integer;
  idx: integer;
  count: integer;
  n: pinteger;
  npages: integer;
  dsap: integer;
  ssap: integer;
  hlen: pinteger;
  rif_len: integer;
  ctl: integer;
  i: integer;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  hdr_va := 0;
  npages := 0;

  cleanup_status := fim_$cleanup(crec);
  if cleanup_status.all = fault_$cleanup_set then begin
    { the unit, the channel }
    u := addr(ring8025_ucb[unit]);
    if not (r8025_unit_online in u^.flags) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_device_offline;
      return;
    end;
    if (channel = 0) or else (channel > r8025_max_chan)
       or else not u^.channels[channel].open then begin
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_channel_not_open;
      return;
    end;

    { the header page: the MAC header and the LLC header }
    netbuf_$get_hdr(hdr_pa, hdr_va);
    pa := hdr_pa;
    h := ring_8025_$mac_hdr_ptr_t(hdr_va);
    idx := 1;
    off := 0;
    ring_8025_copy_data(iov, iov_cnt, idx, off, h, r8025_mac_llc_len);

    { the route, and the LLC header after it }
    if u^.routing and u^.channels[channel].strip_rif then begin
      llc := ring_8025_$llc_ptr_t(addr(h^.rif));
      dsap := llc^.dsap;
      ssap := llc^.ssap;
      ctl := llc^.ctl;
      ring_8025_find_route(u, h^, dsap, ssap, ctl, rif_len);
      rlen := rif_len;
      llc := ring_8025_$llc_ptr_t(integer32(llc) + rlen);
      llc^.dsap := dsap;
      llc^.ssap := ssap;
      llc^.ctl := ctl;
      max_len := u^.max_frame;
    end
    else begin
      rlen := 0;
      max_len := r8025_frame_size;
    end;

    { the frame's length }
    total := 0;
    for i := 1 to iov_cnt do
      total := total + iov[i].len;
    if (total < r8025_mac_llc_len) or else (total > max_len) then begin
      netbuf_$rtn_hdr(hdr_va);
      hdr_va := 0;
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_illegal_frame_length;
      return;
    end;
    total := total + rlen;

    { the rest of the header page }
    hlen := min(total, r8025_hdr_max);
    ring_8025_copy_data(iov, iov_cnt, idx, off,
                        rlen + integer32(addr(h^.rif)) + 3,
                        hlen - r8025_mac_llc_len - rlen);

    { the pieces: the header page, then the data pages }
    ml_$exclusion_start(u^.xmit_lock);
    pieces[1].pa := pa;
    pieces[1].cnt.len := hlen;
    count := 1;
    if u^.channels[channel].strip_rif then begin
      h^.src.high := r8025_addr_high;
      h^.src.low := node_$me;
      if rlen <> 0 then
        h^.src.rii := true;
    end;
    rest := total - hlen;
    while rest <> 0 do begin
      npages := npages + 1;
      count := count + 1;
      netbuf_$get_dat(data_pa[npages]);
      mmu_$set_pmape(u^.win1_va, u^.win1_pmape, rshft(data_pa[npages], 10));
      n := min(rest, 1024);
      ring_8025_copy_data(iov, iov_cnt, idx, off, u^.win1_va, n);
      pieces[count].pa := data_pa[npages];
      pieces[count].cnt.len := n;
      rest := rest - n;
    end;

    { the frame out }
    ring_8025_transmit(u, total, pieces, count, h^.dest, fstat, xstatus);
    ml_$exclusion_stop(u^.xmit_lock);
    status := xstatus;

    { the pages back }
    netbuf_$rtn_hdr(hdr_va);
    hdr_va := 0;
    if npages <> 0 then
      for i := 1 to npages do
        netbuf_$rtn_dat(data_pa[i]);
    fim_$rls_cleanup(crec);
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    if npages <> 0 then
      for i := 1 to npages do
        netbuf_$rtn_dat(data_pa[i]);
    status := cleanup_status;
  end;
end;
