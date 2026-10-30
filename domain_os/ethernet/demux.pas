{ ethernet_demux - hand a received packet to NET_IO, a channel or a
  socket.

  Image addresses:
    sau9  0x3C481A66  ethernet_demux

  Assume the packet is in the unit's header and data pages, its source
  and type in rcv_src.

  - A Domain packet goes to NET_IO_$PUT_IN_SOCK while the unit takes
    Domain packets.  Another packet goes to the channel whose range has
    its type: a channel the system opened through MAC_OS_$DEMUX (an
    all-ones destination is local), a user channel's socket through
    SOCK_$PUT (a refusal counted, the eighth count).
  - A packet that finds no taker has its pages returned.

  Status stored: none.
}

procedure ethernet_demux(u: ethernet_$unit_ptr_t);
  internal;
label
  discard;
var
  rpkt: mac_os_$rcv_pkt_t;
  info: sock_$pkt_info_t;
  h: integer32;
  status: status_$t;
  i: integer;
  idx: integer;
  sock: pinteger;
  demux_flag: boolean;
begin
  if u^.rcv_src.ptype = eth_type_domain then begin
    if not (eth_unit_domain in u^.flags) then
      goto discard;
    net_io_$put_in_sock(4, u^.cnum, u^.hdr_va, u^.dat_va, u^.rcv_hdr_len,
                        u^.rcv_data_len);
    return;
  end;
  idx := 0;
  for i := 1 to u^.range_count do
    if (u^.rcv_src.ptype >= u^.ranges[i].low)
       and then (u^.rcv_src.ptype <= u^.ranges[i].high) then begin
      idx := i;
      exit;
    end;
  if idx = 0 then
    goto discard;
  with u^.channels[u^.ranges[idx].chan] do begin
    if not open then
      goto discard;
    if socket = eth_os_socket then begin
      h := u^.hdr_va;
      rpkt.is_local :=
        (ethernet_$rcv_hdr_ptr_t(h)^.eth.dst.high = 16#FFFFFF)
        and then (ethernet_$rcv_hdr_ptr_t(h)^.eth.dst.low = 16#FFFFFF);
      rpkt.link_addr.n_words := 3;
      for i := 0 to 2 do
        rpkt.link_addr.addr[i] := ethernet_$rcv_hdr_ptr_t(h)^.words[4 + i];
      rpkt.frame_type := ethernet_$rcv_hdr_ptr_t(h)^.eth.src.ptype;
      rpkt.data_pa[1] := u^.dat_va;
      rpkt.body_len := u^.rcv_hdr_len - 14;
      rpkt.body := u^.hdr_va + 16;
      rpkt.unused_24 := 0;
      rpkt.data_len := u^.rcv_data_len;
      demux_flag := false;
      mac_os_$demux(rpkt, ethernet_port_array[u^.cnum], demux_flag, status);
      if status.all = status_$ok then
        return;
    end
    else begin
      sock := socket;
      info.hdr := u^.hdr_va;
      info.data_pages[1] := u^.dat_va;
      info.hdr_len := u^.rcv_hdr_len;
      info.data_len := u^.rcv_data_len;
      info.flags := [];
      info.n_hops := 0;
      time_$abs_clock(info.src_addr);
      if sock_$put(sock, info, false, 4, u^.cnum) then
        return;
      u^.stats.counts[8] := u^.stats.counts[8] + 1;
    end;
  end;
discard:
  ethernet_rtn_bufs(u^.hdr_va, u^.dat_va);
end;
