{ RIP_$STD_DEMUX - queue a packet of the standard IDP channel on RIP's
  socket.

  Image addresses:
    sau2  0x00E15A2C  RIP_$STD_DEMUX

  - From XNS_IDP_$OS_DEMUX's descriptor a socket packet record, marked
    as an XNS packet, is queued with SOCK_$PUT on socket 8, with the
    port's type and socket.

  Status stored:
    none: the packet was queued
    status_$xns_could_not_put_packet_into_socket: SOCK_$PUT failed
}

procedure rip_$std_demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                         in port_socket: integer; in mac_broadcast: boolean;
                         out status: status_$t);
var
  rec: sock_$pkt_info_t;
begin
  rec.flags := [sock_pkt_flag_xns];
  rec.src_addr := pkt.mac_src_hi;
  rec.src_port := pkt.mac_src_lo;
  rec.dst_addr := pkt.pkt_len;
  rec.hdr := pkt.header;
  rec.hdr_len := pkt.data_len;
  rec.data_len := pkt.port_info;
  rec.data_pages := pkt.mac_info;
  rec.n_hops := 0;

  if not sock_$put(rip_socket, rec, false, port_type, port_socket) then
    status.all := status_$xns_could_not_put_packet_into_socket;
end;
