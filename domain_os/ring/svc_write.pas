{ RING_$SVC_WRITE - send a packet on a channel (the driver's svc_write).

  Image addresses:
    sau2  0x00E76F9E  RING_$SVC_WRITE
    sau5  0x00E7E21E  RING_$SVC_WRITE

  - Under a cleanup handler.  The ring header is built in a fresh
    header page, the caller's header bytes gathered after it and the
    rest into a data page.
  - A packet for another node or for all is sent with RING_$SENDP under
    the NET_IO lock (result its transmit status); one for this node or
    for all is put into the channel's own socket.
  - A NETBUF_$GETVA failure crashes the system; a fault returns the
    pages taken.

  Status stored:
    status_$ok: the packet was put into the channel's socket only
    ring_$sendp's status: the packet was sent
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_device_offline: the unit is not started, or its mask
      lacks bit 0
    status_$ring_channel_not_open: the channel is not 1..10 and open
    status_$ring_illegal_header_length: the header is over 968 bytes
    status_$ring_invalid_svc_packet_type: the channel does not own the
      packet type
    status_$ring_invalid_data_length: the data is over 1024 bytes
    fim_$cleanup's status: a fault
}

procedure ring_$svc_write(var unit: pinteger; var hdr: ring_$svc_hdr_t;
                          unused4: integer; var unused5: univ integer32;
                          var iov: univ ring_$iov_array_t; iov_cnt: integer;
                          out result: integer; out status: status_$t);
  options(val_param);
label
  release;
var
  info: sock_$pkt_info_t;
  crec: fim_$cleanup_rec_t;
  rest: integer;
  dst2: integer32;
  dst: integer32;
  cleanup_status: status_$t;
  xstatus: status_$t;
  data_pa: integer32;
  hdr_pa: integer32;
  data_va: integer32;
  hdr_va: integer32;
  channel: pinteger;
  xs: ring_$csr_t;
  flags: integer;
  sock_num: pinteger;
  off2: integer;
  idx2: integer;
  u: ring_$unit_ptr_t;
  rh: ring_$hdr_page_ptr_t;
  total: pinteger;
  idx: integer;
  hdr_len: integer;
  data_len: pinteger;
  i: integer;
begin
  flags := 0;
  result := 0;
  hdr_va := 0;
  data_pa := 0;
  data_va := 0;
  channel := hdr.channel;
  if unit > 1 then begin
    status.all := status_$ring_invalid_unit_num;
    return;
  end;

  cleanup_status := fim_$cleanup(crec);
  if cleanup_status.all = fault_$cleanup_set then begin
    { the unit, the channel }
    u := addr(ring_$ctl[unit]);
    if not (ring_unit_started in u^.state_flags)
       or else not odd(u^.tmask) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$ring_device_offline;
      return;
    end;
    if (channel = 0) or else (channel > 10)
       or else not u^.channels[channel].flags then begin
      fim_$rls_cleanup(crec);
      status.all := status_$ring_channel_not_open;
      return;
    end;

    { the lengths, the type }
    total := 0;
    for i := 1 to iov_cnt do
      total := total + iov[i].len;
    if hdr.hdr_len > 968 then begin
      fim_$rls_cleanup(crec);
      status.all := status_$ring_illegal_header_length;
      return;
    end;
    idx := ring_$find_pkt_type(hdr.pkt_type, u^.pkt_types, u^.pkt_type_cnt);
%if ring_owner_test_reversed %then
    if (idx = 0)
       or else (channel <> u^.pkt_types[idx].entry.channel) then begin
%else
    if (idx = 0)
       or else (u^.pkt_types[idx].entry.channel <> channel) then begin
%endif
      fim_$rls_cleanup(crec);
      status.all := status_$ring_invalid_svc_packet_type;
      return;
    end;
    hdr_len := 28 + hdr.hdr_len;
    data_len := total - hdr.hdr_len;
    if data_len > 1024 then begin
      fim_$rls_cleanup(crec);
      status.all := status_$ring_invalid_data_length;
      return;
    end;

    { the ring header and the caller's header }
    netbuf_$get_hdr(hdr_pa, hdr_va);
    rh := ring_$hdr_page_ptr_t(hdr_va);
    rh^.hdr.msg_type.node := hdr.node;
    if hdr.broadcast then
      rh^.hdr.flags.info_flags := 16#81
    else
      rh^.hdr.flags.info_flags := 1;
    rh^.hdr.flags.arrival_lo := 0;
    rh^.hdr.flags.flags_07 := [];
    rh^.hdr.src_id.node := node_$me;
    rh^.hdr.chksum := 1;
    rh^.hdr.hdr_len := hdr_len;
    rh^.hdr.data_len := data_len;
    rh^.hdr.route_info := hdr.pkt_type;
    idx2 := 1;
    off2 := 0;
    dst := integer32(addr(rh^.body));
    ring_$copy_data(iov, iov_cnt, idx2, off2, dst, hdr.hdr_len);

    { the data }
    if total > hdr.hdr_len then begin
      netbuf_$get_dat(data_pa);
      netbuf_$getva(data_pa, data_va, xstatus);
      if xstatus.all <> 0 then
        crash_system(xstatus);
      dst2 := data_va;
      rest := data_len;
      ring_$copy_data(iov, iov_cnt, idx2, off2, dst2, rest);
    end
    else
      data_len := 0;

    { to another node, or to all }
    if (rh^.hdr.msg_type.node <> rh^.hdr.src_id.node)
       or else hdr.broadcast then begin
      ml_$lock(ml_$net_io_lock);
      ring_$sendp(unit, hdr_pa, pkt_$hdr_ptr_t(rh), hdr_len, data_pa, 0,
                  data_len, flags, xs, xstatus);
      result := integer(xs);
      status := xstatus;
      ml_$unlock(ml_$net_io_lock);
    end
    else
      status.all := 0;

    if data_pa <> 0 then begin
      discard(netbuf_$rtnva(data_va));
      data_va := 0;
    end;

    { to this node, or to all }
    if (rh^.hdr.msg_type.node = rh^.hdr.src_id.node)
       or else hdr.broadcast then begin
      rh^.hdr.hdr_len := hdr_len;
      rh^.hdr.data_len := data_len;
      sock_num := u^.channels[u^.pkt_types[idx].entry.channel].socket_id;
      info.hdr := hdr_va;
      info.data_pages[1] := data_pa;
      info.hdr_len := hdr_len;
      info.data_len := data_len;
      info.flags := [];
      info.n_hops := 0;
      time_$abs_clock(info.src_addr);
      if sock_$put(sock_num, info, false, 0, unit) then
        goto release;
    end;

    { the pages not consumed }
    netbuf_$rtn_hdr(hdr_va);
    hdr_va := 0;
    if data_pa <> 0 then begin
      netbuf_$rtn_dat(data_pa);
      data_pa := 0;
    end;

  release:
    fim_$rls_cleanup(crec);
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    if data_va <> 0 then
      discard(netbuf_$rtnva(data_va));
    if data_pa <> 0 then
      netbuf_$rtn_dat(data_pa);
    status := cleanup_status;
  end;
end;
