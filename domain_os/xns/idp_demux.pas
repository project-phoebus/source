{ XNS_IDP_$DEMUX - queue a received IDP packet on a user channel's
  socket.

  Image addresses:
    sau2  0x00E18B8A  XNS_IDP_$DEMUX

  - The demux routine XNS_IDP_$OPEN gives a user channel: a socket
    record (an IDP packet, local for the broadcast host, marked when MAC
    received it as a broadcast) is put on the channel's user socket; a
    full socket is counted as a drop.

  Status stored:
    status_$ok: the packet was queued
    status_$xns_no_client_for_packet (16#3B0010): the channel has no
      user socket
    status_$xns_could_not_put_packet_into_socket (16#3B0016): the socket
      is full
}

{ TODO(pascal) 4 frame bytes of XNS_IDP_$DEMUX no object explains

  In the SAU2 frame info, hdr's and chan's slots leave one longword to
  the stand-in unused_4c.  APP_$DEMUX, the routine of the same shape
  (app/demux.pas), has open bytes below its socket record too (its
  unused_4c). }

procedure xns_idp_$demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                         in port_socket: integer;
                         in mac_broadcast: boolean;
                         out status: status_$t);
var
  info: sock_$pkt_info_t;
  hdr: integer32;
  chan: xns_$channel_ptr_t;
  unused_4c: integer32;                   { stand-in }
begin
  status.all := status_$ok;
  info.flags := [sock_pkt_flag_xns];
  hdr := pkt.header;
  if (xns_$idp_header_ptr_t(hdr)^.dest.host[2] = 16#FFFF)
     and then (xns_$idp_header_ptr_t(hdr)^.dest.host[0] = 16#FFFF)
     and then (xns_$idp_header_ptr_t(hdr)^.dest.host[1] = 16#FFFF) then
    info.flags := info.flags + [sock_pkt_flag_local];
  if mac_broadcast then
    info.flags := info.flags + [sock_pkt_flag_demux_bool];

  info.src_addr := pkt.mac_src_hi;
  info.src_port := pkt.mac_src_lo;
  info.dst_addr := pkt.pkt_len;
  info.hdr := hdr;
  info.hdr_len := pkt.data_len;
  info.data_len := pkt.port_info;
  info.data_pages := pkt.mac_info;
  info.n_hops := 0;

  chan := xns_$channel_ptr_t(pkt.channel);
  if chan^.user_socket = xns_no_socket then begin
    status.all := status_$xns_no_client_for_packet;
    return;
  end;
  if not sock_$put(chan^.user_socket, info, false, port_type, port_socket)
  then begin
    xns_idp_$packets_dropped := xns_idp_$packets_dropped + 1;
    status.all := status_$xns_could_not_put_packet_into_socket;
  end;
end;
