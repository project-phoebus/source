{ ring_$receive_packet - hand a received packet to its channel or socket.

  Image addresses:
    sau2  0x00E7649E  ring_$receive_packet (module-local)
    sau8  0x03C82D8C  ring_$receive_packet (module-local)
    sau2  0x00E76470  ring_$discard_packet (nested)
    sau8  0x03C82D5E  ring_$discard_packet (nested)

  - A packet without the ring's own flag goes to NET_IO_$PUT_IN_SOCK.
    Else its type's channel gets it: a channel the system opened through
    MAC_OS_$DEMUX, a user channel's socket through SOCK_$PUT.
  - A packet that finds no taker is discarded (ring_$discard_packet).
  - ring_$discard_packet reads its parent's data_len through the static
    link.

  Status stored: none.
}

procedure ring_$receive_packet(unit: integer; var hdr_va: integer32;
                               var data_pa: integer32;
                               var hdr_len: pinteger;
                               var data_len: pinteger);
  internal;
label
  discard_it;
var
  rpkt: mac_os_$rcv_pkt_t;
  info: sock_$pkt_info_t;
  status: status_$t;
  flags7: set of 0..7;
  socket_id: pinteger;
  demux_flag: boolean;
  u: ring_$unit_ptr_t;
  hdr: ring_$hdr_ptr_t;
  idx: integer;
  ch: integer;
  is_fragment: boolean;
  i: integer;

  { ring_$discard_packet: return the header page, dump the data pages. }
  procedure ring_$discard_packet(hdr_va: integer32;
                                 in data_pages: univ pkt_$data_pages_t;
                                 len: integer);
  begin
    netbuf_$rtn_hdr(hdr_va);
    pkt_$dump_data(data_pages, data_len);
  end;

begin
  u := addr(ring_$ctl[unit]);
  if 0 in ring_$hdr_ptr_t(hdr_va)^.flags.info_bits then begin
    hdr := ring_$hdr_ptr_t(hdr_va);
    idx := ring_$find_pkt_type(hdr^.route_info, u^.pkt_types,
                               u^.pkt_type_cnt);
    if idx = 0 then
      goto discard_it;
    ch := u^.pkt_types[idx].entry.channel;
    if not u^.channels[ch].flags then
      goto discard_it;

    flags7 := hdr^.flags.flags_07;
    is_fragment := 3 in flags7;
    if u^.channels[ch].socket_id = ring_os_socket then begin
      { a channel the system opened }
      rpkt.is_local := pkt_$hdr_broadcast in hdr^.flags.info_bits;
      rpkt.link_addr.n_words := 2;
      for i := 0 to 1 do
        rpkt.link_addr.addr[i] := hdr^.src_id.words[i];
      rpkt.frame_type := hdr^.route_info;
      rpkt.data_pa[1] := data_pa;
      rpkt.body_len := hdr_len - 28;
      rpkt.body := hdr_va + 16#1C;
      rpkt.unused_24 := 0;
      rpkt.data_len := data_len;
      demux_flag := is_fragment;
      mac_os_$demux(rpkt, ring_$port_array[unit], demux_flag, status);
      if status.all = 0 then
        return;
      ring_$discard_packet(hdr_va, data_pa, data_len);
    end
    else begin
      { a user channel's socket }
      socket_id := u^.channels[ch].socket_id;
      info.hdr := integer32(hdr);
      info.data_pages[1] := data_pa;
      info.hdr_len := hdr_len;
      info.data_len := data_len;
      info.flags := [];
      info.n_hops := 0;
      if is_fragment then
        info.flags := [sock_pkt_flag_demux_bool];
      time_$abs_clock(info.src_addr);
      if sock_$put(socket_id, info, false, 0, unit) then
        return;
    discard_it:
      ring_$discard_packet(integer32(hdr), data_pa, data_len);
    end;
  end
  else
    net_io_$put_in_sock(0, unit, hdr_va, data_pa, hdr_len, data_len);
end;
