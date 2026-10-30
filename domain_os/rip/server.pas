{ RIP_$SERVER - take one RIP packet off socket 8 and act on it.

  Image addresses:
    sau2  0x00E68A08  RIP_$SERVER
    sau2  0x00E688C8  rip_$process_request (nested)

  - The packet (an IDP one over the standard routing, else broken down
    by PKT_$BRK_INTERNET_HDR) is counted; a bad status or length (not
    2 + 6n, n at most 90) counts an error.
  - A request (1) is answered (the nested rip_$process_request); a
    response (2) moves a non-routing port to its network and takes the
    entries in as routes through the sender; a name server (3) is
    registered with the name service.

  Status stored: none.
}

{ TODO(pascal) RIP_$SERVER's frame: 20 bytes no object explains

  The objects the image addresses lie at the offsets of the frame, those
  of 8 bytes or more at multiples of 8 and the 6-byte
  clock at a multiple of 4, which leaves 14 bytes of alignment above
  wait_status; the register-held locals' slots
  fit the 4- and 2-byte holes among the addressed words.  Two runs of
  8 and 12 bytes are left, which nothing addresses; the 2 bytes after
  header are read only by the name-server arm.  dpc does not 8-align:
  the stand-ins unused_4e8 (20 bytes, the 8 and the 12 of alignment
  above) and unused_534 are sized so that dpc --dump-locals gives the
  image's offsets from status down and the frame's 0x538 bytes; the
  objects above come out 0xC higher. }

procedure rip_$server;
var
  header: xns_$idp_header_t;
  source_addr: rip_$nexthop_t;
  pkt: sock_$pkt_info_t;
  response: rip_$packet_t;
  info_out: pkt_$info_t;
  packet_data: rip_$packet_t;
  wait_status: status_$t;
  wait_delay: time_$clock_t;
  reg_network: integer32;
  unused_4e8: array[1..5] of integer32;   { stand-in, see the TODO }
  status: status_$t;
  payload_va: integer32;
  src_node_or: integer32;
  src_node: linteger;
  network: integer32;
  dest_node: integer32;
  packet: xns_$idp_header_ptr_t;
  hdr_va: integer32;
  is_std: boolean;
  send_timeout: pinteger;
  send_retry_hint: integer;
  port_index: integer;
  response_count: integer;
  entry_count: integer;
  data_len: integer;
  id_out: pinteger;
  src_sock: pinteger;
  dest_sock: pinteger;
  page: netbuf_$hdr_page_ptr_t;
  port: route_$port_ptr_t;
  retries: pinteger;
  k: integer;
  unused_534: array[1..3] of integer32;   { stand-in, see the TODO }
  reg_node: integer32;

  { TODO(pascal) 12 frame bytes of rip_$process_request hold nothing

    Nothing addresses the frame; the link's slot and the slots of
    full_table, i, entry, j and route take 20 of its 32 bytes
    A network, two metric values and a
    state, which the image keeps in no register of its own, would fill
    the 12 (4 + 4 + 2 + 2 bytes).  The stand-in unused_20 holds them
    (dpc --dump-locals then gives the frame's size). }

  procedure rip_$process_request(is_std: boolean);
  var
    full_table: boolean;
    i: integer;
    entry: rip_$entry_ptr_t;
    j: integer;
    route: rip_$route_ptr_t;
    unused_20: array[1..3] of integer32;  { stand-in, see the TODO }
  begin
    response.command := rip_cmd_response;
    full_table := false;
    response_count := entry_count;

    for i := 1 to entry_count do begin
      if rip_$packet_ptr_t(payload_va)^.entries[i].network = -1 then begin
        full_table := true;
        exit;
      end;
      entry := rip_$entry_ptr_t(rip_$net_lookup(
                 rip_$packet_ptr_t(payload_va)^.entries[i].network,
                 false, false));
      response.entries[i].network :=
        rip_$packet_ptr_t(payload_va)^.entries[i].network;
      if is_std then begin
        if entry = nil then
          response.entries[i].metric := 16
        else
          response.entries[i].metric :=
            max(entry^.routes[1].metric + 1, 16);
      end
      else if entry = nil then
        response.entries[i].metric := 17
      else
        response.entries[i].metric := entry^.routes[0].metric + 1;
    end;

    if full_table then begin
      response_count := 0;
      for j := 0 to 63 do begin
        if is_std then
          route := addr(rip_$info[j].routes[1])
        else
          route := addr(rip_$info[j].routes[0]);
        if route^.flags.state in [rip_state_valid, rip_state_aging] then
          begin
          response_count := response_count + 1;
          response.entries[response_count].network := rip_$info[j].network;
          if is_std then
            response.entries[response_count].metric :=
              max(route^.metric + 1, 16)
          else
            response.entries[response_count].metric := route^.metric + 1;
          if response_count = rip_max_entries then
            return;
        end;
      end;
    end;
  end;

begin
  if not sock_$get(rip_socket, pkt) then
    return;
  is_std := sock_pkt_flag_xns in pkt.flags;
  pkt_$dump_data(pkt.data_pages, pkt.data_len);
  packet := xns_$idp_header_ptr_t(pkt.hdr);
  page := netbuf_$hdr_page_ptr_t(integer32(packet) & (-16#400));

  if is_std then begin
    status.all := status_$ok;
    payload_va := integer32(packet) + xns_idp_header_size;
    header := packet^;
    packet_data := rip_$packet_ptr_t(payload_va)^;
    data_len := header.length - xns_idp_header_size;
  end
  else
    pkt_$brk_internet_hdr(pkt_$hdr_ptr_t(packet)^, pkt.hdr_len, network,
                          dest_node, dest_sock, src_node_or, src_node,
                          src_sock, info_out, id_out, packet_data, 16#21E,
                          data_len, status);

  rip_$stats.packets_received := rip_$stats.packets_received + 1;
  if status.all <> status_$ok then begin
    rip_$stats.errors := rip_$stats.errors + 1;
    hdr_va := integer32(packet);
    netbuf_$rtn_hdr(hdr_va);
    return;
  end;
  entry_count := (data_len - 2) div 6;
  if (status.all <> status_$ok)
     or else (entry_count < 0)
     or else (entry_count > rip_max_entries)
     or else (rip_$packet_length(entry_count) <> data_len) then begin
    rip_$stats.errors := rip_$stats.errors + 1;
    hdr_va := integer32(packet);
    netbuf_$rtn_hdr(hdr_va);
    return;
  end;

  port_index := route_$find_port(page^.ec_param1, page^.ec_param2);
  hdr_va := integer32(packet);
  netbuf_$rtn_hdr(hdr_va);
  if port_index = -1 then
    return;

  case packet_data.command of
    rip_cmd_request: begin
      if is_std then begin
        if route_$std_n_routing_ports <= 1 then
          if (header.dest.host[0] = 16#FFFF)
             and (header.dest.host[1] = 16#FFFF)
             and (header.dest.host[2] = 16#FFFF) then
            return;
        rip_$process_request(true);
        retries := 0;
        repeat
          retries := retries + 1;
          rip_$send(header.src, port_index, response,
                    rip_$packet_length(response_count), true);
          wait_delay.high := 0;
          wait_delay.low := 25000;
          time_$wait(time_$relative, wait_delay, wait_status);
          if wait_status.all = time_$wait_quit then
            return;
        until retries >= 5;
      end
      else begin
        if (route_$n_routing_ports <= 1)
           and then (7 in rip_$template_flags_t(info_out.flags)) then
          return;
        rip_$process_request(false);
        info_out.flags := 16#20;
        pkt_$send_internet(src_node_or, src_node, src_sock, network,
                           node_$me, rip_socket, info_out, id_out,
                           response, rip_$packet_length(response_count),
                           0, 0, send_retry_hint, send_timeout, status);
      end;
    end;

    rip_cmd_response: begin
      port := route_$portp[port_index];
      if is_std then
        network := header.dest.network;
      if (network <> port^.network)
         and then not (port^.active in [3..5]) then begin
        source_addr.network := port^.network;
        for k := 0 to 2 do
          source_addr.host[k] := 0;
        rip_$update_int(port^.network, source_addr, 16, port_index, is_std,
                        status);
        source_addr.network := network;
        rip_$update_int(network, source_addr, 0, port_index, is_std,
                        status);
        port^.network := network;
        port^.xns_addr[0].network := network;
        if port_index = 0 then
          hint_$add_net(port^.network);
      end;
      if (is_std
          and then ((route_$std_n_routing_ports < 2)
                    or else ((route_$std_n_routing_ports > 1)
                             and then (port^.active in [4, 5]))))
         or else ((not is_std)
                  and then ((route_$n_routing_ports < 2)
                            or else ((route_$n_routing_ports > 1)
                                     and then (port^.active in [3, 5])))) then
        begin
        source_addr.network := network;
        if is_std then
          for k := 0 to 2 do
            source_addr.host[k] := header.src.host[k]
        else
          source_addr.host_bits.host_node := src_node;
        for k := 1 to entry_count do
          rip_$update_int(packet_data.entries[k].network, source_addr,
                          packet_data.entries[k].metric, port_index,
                          is_std, status);
      end;
      rip_$send_updates(is_std);
    end;

    rip_cmd_name_register: begin
      if is_std then begin
        if header.packet_type <> 16#BE then
          rip_$stats.unknown_commands := rip_$stats.unknown_commands + 1
        else begin
          reg_network := header.src.network;
          reg_node := rip_$nexthop_ptr_t(addr(header.src.host))^.
                        host_bits.host_node;
          rem_name_$register_server(reg_network, reg_node);
        end;
      end
      else
        rem_name_$register_server(src_node_or, src_node);
    end;

    otherwise begin
      rip_$stats.unknown_commands := rip_$stats.unknown_commands + 1;
    end;
  end;
end;
