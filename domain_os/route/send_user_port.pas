{ ROUTE_$SEND_USER_PORT - the user routing driver's send entry.

  Image addresses:
    sau2  0x00E87C34  ROUTE_$SEND_USER_PORT

  - The packet's copies (NET_IO_$COPY_PACKET) are queued on the user
    port's socket, counted by queue depth; a socket of no user port
    crashes the system.
  - xmit_status is the module's sequence word on a put, else 0.
  - The socket gets the caller's header and first data page; the copies
    are returned only when the put fails.

  Status stored:
    net_io_$copy_packet's status: the packet was queued, or not copied
    status_$network_data_length_too_large: data over 1024 bytes
    status_$route_queue_full: the put failed
}

procedure route_$send_user_port(var socket: pinteger; hdr_pa: integer32;
                                hdr: pkt_$hdr_ptr_t;
                                hdr_len: integer;
                                in data_pages: univ pkt_$data_pages_t;
                                data_va: integer32; data_len: pinteger;
                                in flags: univ integer;
                                out xmit_status: pinteger;
                                out status_ret: status_$t);
var
  pkt_info: sock_$pkt_info_t;
  pages: pkt_$data_pages_t;
  stats: route_$user_stat_ptr_t;
  hdr_va: integer32;
  index: integer;
  queue_count: pinteger;
begin
  xmit_status := 0;
  if data_len > 1024 then begin
    status_ret.all := status_$network_data_length_too_large;
    return;
  end;

  index := route_$find_port(route_$port_type_routing, socket);
  if index = -1 then
    crash_system(status_$internet_unknown_network_port);
  stats := route_$port[index].part_34.driver_stats;

  net_io_$copy_packet(hdr, hdr_len, data_va, data_pages, data_len, hdr_va,
                      pages, status_ret);
  if status_ret.all <> status_$ok then
    return;

  pkt_info.hdr := integer32(hdr);
  pkt_info.data_pages[1] := data_pages[1];
  pkt_info.hdr_len := hdr_len;
  pkt_info.data_len := data_len;
  pkt_info.n_hops := 0;

  if sock_$put(socket, pkt_info, false, 2, socket) then begin
    xmit_status := route_$packet_seq;
    queue_count := sock_$socket_ptr[socket]^.queue_count;
    if queue_count > 32 then
      stats^.counts.deep_queue_puts := stats^.counts.deep_queue_puts + 1
    else
      stats^.queue_depth[queue_count] := stats^.queue_depth[queue_count] + 1;
  end else begin
    stats^.counts.failed_puts := stats^.counts.failed_puts + 1;
    netbuf_$rtn_hdr(hdr_va);
    pkt_$dump_data(pages, data_len);
    status_ret.all := status_$route_queue_full;
  end;
end;
