{ RING_$SVC_READ - take a packet from a channel (the driver's svc_read).

  Image addresses:
    sau2  0x00E77402  RING_$SVC_READ

  - Under a cleanup handler.  A packet whose header is shorter than the
    ring header is dropped and the next taken.
  - The ring header's source, broadcast flag and packet type go into
    hdr; the header bytes and then the data are scattered into the
    caller's vector, and len_out is their length.
  - len_out is not cleared at entry.  A NETBUF_$GETVA failure crashes
    the system; a fault returns the pages held.

  Status stored:
    status_$ok: a packet was read
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_device_offline: the unit is not started, or its mask
      lacks bit 0
    status_$ring_channel_not_open: the channel is not 1..10 and open
    status_$ring_no_packet_to_receive: the socket is empty
    status_$network_msg_exceeds_max_size: the packet's data is over
      1024 bytes (dropped)
    fim_$cleanup's status: a fault
}

procedure ring_$svc_read(var unit: pinteger; var hdr: ring_$svc_hdr_t;
                         unused4: integer; var unused5: univ integer32;
                         var iov: univ ring_$iov_array_t; iov_cnt: integer;
                         out len_out: integer; out status: status_$t);
  options(val_param);
var
  info: sock_$pkt_info_t;
  crec: fim_$cleanup_rec_t;
  data_pa: pkt_$data_pages_t;
  cleanup_status: status_$t;
  data_va: integer32;
  hdr_va: integer32;
  channel: pinteger;
  off: integer;
  idx: integer;
  data_len: integer;
  src: integer32;
  u: ring_$unit_ptr_t;
  rh: ring_$hdr_page_ptr_t;
  hdr_len: integer;
begin
  hdr_va := 0;
  data_pa[1] := 0;
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

    { a packet with a whole ring header }
    repeat
      if not sock_$get(u^.channels[channel].socket_id, info) then begin
        fim_$rls_cleanup(crec);
        status.all := status_$ring_no_packet_to_receive;
        return;
      end;
      hdr_va := info.hdr;
      hdr_len := info.hdr_len;
      data_len := info.data_len;
      data_pa[1] := info.data_pages[1];
      if data_len > 1024 then begin
        netbuf_$rtn_hdr(hdr_va);
        pkt_$dump_data(data_pa, data_len);
        data_pa[1] := 0;
        fim_$rls_cleanup(crec);
        status.all := status_$network_msg_exceeds_max_size;
        return;
      end;
      if hdr_len < 28 then begin
        netbuf_$rtn_hdr(hdr_va);
        hdr_va := 0;
        pkt_$dump_data(data_pa, data_len);
        data_pa[1] := 0;
      end;
    until hdr_len >= 28;

    { the header }
    rh := ring_$hdr_page_ptr_t(hdr_va);
    hdr.node := rh^.hdr.src_id.node;
    hdr.broadcast := pkt_$hdr_broadcast in rh^.hdr.flags.info_bits;
    hdr.pkt_type := rh^.hdr.route_info;
    hdr_len := hdr_len - 28;
    hdr.hdr_len := hdr_len;
    len_out := hdr_len + data_len;
    idx := 1;
    off := 0;
    src := integer32(addr(rh^.body));
    ring_$copy_to_user(src, hdr_len, iov, iov_cnt, idx, off);
    netbuf_$rtn_hdr(hdr_va);
    hdr_va := 0;

    { the data }
    if data_pa[1] <> 0 then begin
      netbuf_$getva(data_pa[1], data_va, status);
      if status.all <> 0 then
        crash_system(status);
      ring_$copy_to_user(data_va, data_len, iov, iov_cnt, idx, off);
      netbuf_$rtn_dat(netbuf_$rtnva(data_va));
      data_va := 0;
      data_pa[1] := 0;
    end;

    fim_$rls_cleanup(crec);
    status.all := 0;
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    if data_va <> 0 then
      discard(netbuf_$rtnva(data_va));
    if data_pa[1] <> 0 then
      pkt_$dump_data(data_pa, data_len);
    status := cleanup_status;
  end;
end;
