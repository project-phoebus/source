{ ROUTE_$PROCESS - the routing process.

  Image addresses:
    sau2  0x00E873EC  ROUTE_$PROCESS

  - A process's body, started by route_$init_routing.  It waits on the
    clock (RIP's periodic broadcasts), the routing socket and the
    control eventcount.
  - A packet on the socket is counted by queue depth, its hop count
    raised and checked, and forwarded by RIP's next hop: into a user
    port's socket, through MAC_OS, or through NET_IO.
  - Buffers not passed on are returned.  An empty socket crashes the
    system.
  - The control eventcount stops the router: the socket closed, the
    routing area unwired when no user port is open, the process unbound.

  Status stored: none.
}

{ TODO(pascal) 26 frame bytes of ROUTE_$PROCESS no object explains

  With the locals in the order below and the 8-byte alignment of the
  records, every addressed object is at its offset, but no instruction
  addresses 26 bytes of the frame, held by the stand-ins unused_cc,
  unused_dc, unused_ec, unused_f4 and unused_fc .. unused_104.  A local
  for the hop count, or a second loop index, would take some of them.
  dpc does not 8-align frame objects. }

procedure route_$process;
var
  mac_send: mac_os_$send_pkt_t;
  next_hop: rip_$nexthop_t;
  dest: route_$xns_addr_t;
  rcv: sock_$pkt_info_t;
  pkt: pkt_$hdr_ptr_t;
  idp: xns_$idp_header_ptr_t;
  port: route_$port_ptr_t;
  port_stats: route_$user_stat_ptr_t;
  is_std: boolean;
  should_forward: boolean;
  was_forwarded: boolean;
  depth: integer;
  next_port: integer;
  unused_cc: integer;                     { stand-in: the TODO above }
  status: status_$t;
  send_info: net_io_$send_info_t;
  next_broadcast: time_$clockh_t;
  unused_dc: integer32;                   { stand-in }
  hdr_cell: record
    case integer of
      1: (va: integer32);
      2: (ptr: pkt_$hdr_ptr_t);
  end;
  hdr_pa: integer32;
  route_sock: sock_$sock_ptr_t;
  bytes_sent: integer;
  unused_ec: integer;                     { stand-in }
  hop_port: integer;
  i: integer;
  unused_f4: integer32;                   { stand-in }
  closing: integer;
  unused_fc: integer32;                   { stand-in }
  unused_100: integer32;                  { stand-in }
  unused_104: integer32;                  { stand-in }
begin
  discard(ec_$waitn(route_$ptr_control_ec, route_$control_ecval, 1));
  route_$control_ecval := route_$control_ecval + 1;
  route_sock := sock_$socket_ptr[route_$sock];
  route_$routing := true;
  network_$set_service(network_op_or_bits, route_$service_id, status);
  next_broadcast := time_$clockh;
  proc1_$set_lock(ml_$server_lock);

  repeat
    case ec_$wait(ec_$eventcount_ptr_t(addr(time_$clockh)),
                  addr(route_sock^.ec), addr(route_$control_ec),
                  next_broadcast, route_$sock_ecval,
                  route_$control_ecval) of

      { a packet on the routing socket }
      1: begin
           if not sock_$get(route_$sock, rcv) then
             crash_system(status_$network_buffer_queue_is_empty);
           pkt := pkt_$hdr_ptr_t(rcv.hdr);

           depth := route_sock^.queue_count;
           if depth > 128 then
             depth := 128;
           route_$q_depth[depth] := route_$q_depth[depth] + 1;

           is_std := sock_pkt_flag_xns in rcv.flags;
           should_forward := (pkt^.routing_type >= pkt_$routing_inet)
                             or is_std;
           if is_std then
             idp := addr(pkt^)
           else
             idp := addr(pkt^.info_0c);
           if should_forward and then not is_std
              and then (rcv.data_pages[1] = 0)
              and then (pkt^.pkt_data_len <> 0) then begin
             route_$dlen_err := route_$dlen_err + 1;
             should_forward := false;
           end;

           idp^.transport_ctl := idp^.transport_ctl + 1;
           if idp^.checksum <> 16#FFFF then
             idp^.checksum := xns_idp_$hop_and_sum(idp^.checksum,
                                                   idp^.length);

           if should_forward then begin
             if idp^.transport_ctl >= route_$max_hop_count then begin
               if is_std then
                 route_$std_too_far := route_$std_too_far + 1
               else
                 route_$too_far := route_$too_far + 1;
               should_forward := false;
             end;
             if should_forward then begin
               dest := idp^.dest;
               discard(rip_$find_nexthop(dest, false, hop_port, next_hop,
                                         status));
               next_port := hop_port;
               if status.all <> status_$ok then begin
                 if is_std then
                   route_$std_misroute := route_$std_misroute + 1
                 else
                   route_$misroute := route_$misroute + 1;
                 should_forward := false;
               end;
             end;
           end;

           was_forwarded := false;
           if should_forward then begin
             port := addr(route_$port[next_port]);
             if is_std then begin
               if not (port^.active in [4, 5]) then begin
                 route_$std_misroute := route_$std_misroute + 1;
                 should_forward := was_forwarded;
               end;
             end else begin
               if not (port^.active in [3, 5]) then begin
                 route_$misroute := route_$misroute + 1;
                 should_forward := was_forwarded;
               end;
               pkt^.src_node := node_$me;
               pkt^.dest_node := next_hop.host_lo & 16#FFFFF;
             end;

             if port^.port_type = route_$port_type_routing then begin
               { a user port }
               if ring_$logging_now then
                 discard(ringlog_$logit(false, pkt^));
               port_stats := port^.part_34.driver_stats;
               if sock_$put(port^.socket, rcv, was_forwarded, 2,
                            port^.socket) then begin
                 was_forwarded := true;
                 depth := route_sock^.queue_count;
                 if depth > 32 then
                   port_stats^.counts.deep_queue_puts :=
                     port_stats^.counts.deep_queue_puts + 1
                 else
                   port_stats^.queue_depth[depth] :=
                     port_stats^.queue_depth[depth] + 1;
               end else
                 port_stats^.counts.failed_puts :=
                   port_stats^.counts.failed_puts + 1;
               port^.forward_count := port^.forward_count + 1;
             end else if rcv.data_len <= route_$max_forward_size then begin
               if is_std then begin
                 { a standard routing port }
                 mac_os_$arp(next_hop, next_port, mac_send.link_addr,
                             mac_send.is_broadcast, status);
                 if status.all <> status_$ok then
                   should_forward := was_forwarded
                 else begin
                   mac_send.hdr_desc.length := rcv.hdr_len;
                   mac_send.hdr_desc.address := integer32(pkt);
                   mac_send.hdr_desc.next := nil;
                   mac_send.hdr_prebuilt := true;
                   mac_send.frame_type := route_$mac_frame_type;
                   mac_send.data_length := rcv.data_len;
                   mac_send.data_pages := rcv.data_pages;
                   mac_os_$send(xns_idp_$port_table[next_port].mac_socket,
                                mac_send, bytes_sent, status);
                 end;
               end else begin
                 { a Domain routing port }
                 hdr_pa := netbuf_$hdr_page_ptr_t(integer32(pkt)
                                                  & (-16#400))^.phys;
                 ml_$lock(ml_$net_io_lock);
                 hdr_cell.ptr := pkt;
                 net_io_$send(next_port, hdr_cell.ptr, hdr_pa,
                              pkt^.total_len, 0, rcv.data_pages,
                              pkt^.pkt_data_len, route_$fwd_timeout,
                              send_info, status);
                 ml_$unlock(ml_$net_io_lock);
               end;
             end else begin
               { too long for a real port }
               if is_std then
                 route_$std_dlen_err := route_$std_dlen_err + 1
               else
                 route_$dlen_err := route_$dlen_err + 1;
               should_forward := was_forwarded;
             end;
           end;

           if is_std and then should_forward then
             route_$std_pkts_routed := route_$std_pkts_routed + 1
           else if not is_std and then should_forward then
             route_$pkts_routed := route_$pkts_routed + 1;

           if not was_forwarded then begin
             hdr_cell.ptr := pkt;
             netbuf_$rtn_hdr(hdr_cell.va);
             pkt_$dump_data(rcv.data_pages, rcv.data_len);
           end;
           route_$sock_ecval := route_$sock_ecval + 1;
         end;

      { the clock }
      0: begin
           if route_$n_routing_ports > 1 then
             rip_$broadcast(false);
           if route_$std_n_routing_ports > 1 then
             rip_$broadcast(true);
           next_broadcast := time_$clockh + route_$broadcast_interval;
         end;

      { the router stops }
      2: begin
           route_$control_ecval := route_$control_ecval + 1;
           proc1_$clr_lock(ml_$server_lock);
           route_$routing := false;
           route_$start_time := 0;
           network_$set_service(network_op_and_not_bits, route_$service_id,
                                status);
           closing := route_$sock;
           route_$sock := -1;
           sock_$close(closing);
           route_$netbuf_alloc := 0;
           if route_$n_user_ports = 0 then begin
             for i := 1 to route_$n_wired_pages do
               wp_$unwire(route_$wired_pages[i]);
             route_$n_wired_pages := 0;
           end;
           proc1_$unbind(route_$pid, status);
           exit;
         end;
    end;
  until false;
end;
