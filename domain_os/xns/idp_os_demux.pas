{ XNS_IDP_$OS_DEMUX - deliver or forward a received IDP packet.

  Image addresses:
    sau2  0x00E184A8  XNS_IDP_$OS_DEMUX

  - MAC calls it for each received XNS frame.  A bad checksum is
    answered with an XNS error.
  - A packet for this node (or broadcast) goes to the open channel of
    its destination socket through the channel's demux routine; any
    other is forwarded through the routing socket, when standard routing
    has two ports or more and the packet fewer than 15 hops.

  Status stored:
    status_$ok: the packet was delivered or forwarded
    the demux routine's status: the channel's demux failed
    status_$xns_no_client_for_packet (16#3B0010): from the broadcast
      host, or no channel, demux routine or valid socket
    status_$xns_bad_checksum (16#3B0011): a wrong checksum
    status_$xns_hop_count_exceeded (16#3B0012): 15 hops or more
    status_$xns_could_not_put_packet_into_socket (16#3B0016): the
      routing socket is full
}

{ TODO(pascal) 14 frame bytes of XNS_IDP_$OS_DEMUX no object explains

  In the SAU2 frame info, desc and err_status fill the top, hdr's and
  rport's slots the 8 bytes down to err_result, and chan_idx and i's
  slot follow; with the `with''s temporary at the bottom,
  14 bytes hold no object the code addresses (the stand-in unused_a8). }

procedure xns_idp_$os_demux(in pkt: xns_$mac_pkt_t; in port: integer;
                            in mac_broadcast: boolean;
                            out status: status_$t);
var
  info: sock_$pkt_info_t;
  desc: xns_$pkt_desc_t;
  err_status: status_$t;
  hdr: xns_$idp_header_ptr_t;
  rport: route_$port_ptr_t;
  err_result: integer;
  chan_idx: pinteger;
  i: integer;
  unused_a8: array[1..7] of integer;      { stand-in }
begin
  status.all := status_$ok;
  xns_idp_$packets_received := xns_idp_$packets_received + 1;
  hdr := xns_$idp_header_ptr_t(pkt.hdr_desc.address);
  if (hdr^.src.host[2] = 16#FFFF) and then (hdr^.src.host[0] = 16#FFFF)
     and then (hdr^.src.host[1] = 16#FFFF) then begin
    xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
    status.all := status_$xns_no_client_for_packet;
    return;
  end;

  if (hdr^.checksum <> 16#FFFF)
     and (xns_$get_checksum(pkt) <> hdr^.checksum) then begin
    desc.mac_src_hi := pkt.mac_src_hi;
    desc.mac_src_lo := pkt.mac_src_lo;
    desc.head := pkt.hdr_desc;
    desc.from_net := true;
    desc.data := pkt.data;
    if xns_$is_broadcast_addr(hdr^.dest) then
      xns_error_$send(desc, xns_error_bad_checksum, xns_error_param_none,
                      err_result, err_status)
    else
      xns_error_$send(desc, xns_error_bad_checksum_transit,
                      xns_error_param_none, err_result, err_status);
    xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
    status.all := status_$xns_bad_checksum;
    return;
  end;

  rport := route_$portp[port];

  if xns_$is_broadcast_addr(hdr^.dest) then begin
    if (hdr^.dest.socket = 16#FFFF) or else (hdr^.dest.socket = 0) then
    begin
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
      status.all := status_$xns_no_client_for_packet;
      return;
    end;
    chan_idx := xns_max_channels;
    for i := 0 to xns_max_channels - 1 do
      with xns_idp_$channels[i] do
        if xns_socket = hdr^.dest.socket then begin
          chan_idx := i;
          exit;
        end;
    if (chan_idx = xns_max_channels)
       or else (xns_idp_$channels[chan_idx].demux = nil) then begin
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
      status.all := status_$xns_no_client_for_packet;
      return;
    end;
    desc.mac_src_hi := pkt.mac_src_hi;
    desc.mac_src_lo := pkt.mac_src_lo;
    desc.channel := integer32(addr(xns_idp_$channels[chan_idx]));
    desc.head := pkt.hdr_desc;
    desc.from_net := true;
    desc.data := pkt.data;
    xns_idp_$channels[chan_idx].demux^(desc, rport^.port_type,
                                       rport^.socket, mac_broadcast,
                                       status);
    if status.all <> status_$ok then
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
  end

  else begin
    if route_$std_n_routing_ports < 2 then begin
      route_$std_misroute := route_$std_misroute + 1;
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
      status.all := status_$xns_no_client_for_packet;
      return;
    end;
    if hdr^.transport_ctl >= 15 then begin
      route_$std_too_far := route_$std_too_far + 1;
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
      status.all := status_$xns_hop_count_exceeded;
      return;
    end;
    info.flags := [sock_pkt_flag_xns];
    info.src_addr := pkt.mac_src_hi;
    info.src_port := pkt.mac_src_lo;
    info.dst_addr := pkt.frame_type;
    info.hdr := integer32(hdr);
    info.hdr_len := pkt.hdr_desc.length;
    info.data_len := pkt.data.length;
    info.data_pages := pkt.data.pages;
    info.n_hops := 0;
    if not sock_$put(route_$sock, info, false, rport^.port_type,
                     rport^.socket) then begin
      xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
      status.all := status_$xns_could_not_put_packet_into_socket;
    end;
  end;
end;
