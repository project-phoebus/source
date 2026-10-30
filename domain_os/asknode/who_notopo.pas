{ ASKNODE_$WHO_NOTOPO - list the nodes of a network without topology.

  Image addresses:
    sau2  0x00E65FDC  ASKNODE_$WHO_NOTOPO

  - One time request (type 16#45), its answers collected until the
    maximum (2000 at most), a receive error, the timeout or a quit; this
    node is first when the listing is local or the route direct.
  - An answer's node is written at count + 1 before it is checked, and a
    failed receive goes back to the wait without advancing wait_val.

  Status stored:
    status_$ok: the listing is done
    rip_$find_nexthop's status: no route to the network
    status_$network_no_more_free_sockets: no socket
    pkt_$send_internet's status: the request was not sent
    an answer's status: an answer reported a failure
    status_$network_quit_fault_during_node_listing: a quit
}

{ TODO(pascal) WHO_NOTOPO's frame has 46 bytes nothing addresses

  In the SAU2 image the records lie at multiples of 8, and below them
  the addressed locals leave holes (16, 8, 6, 2 and 18 bytes) for the
  register-held locals' homes, which no instruction shows.  dpc does not
  8-align: the register-held locals are declared into those holes by
  size, and the stand-ins unused_288, unused_2b6, unused_2be and
  unused_2d4 fill the rest, which gives the image's offsets from
  deadline down and the image's frame size; the records come out up to
  0x10 bytes off.  Which register's home is where is not known. }

procedure asknode_$who_notopo(in node_id: linteger;
                              in port: integer32;
                              out node_list: asknode_$node_list_t;
                              in max_count: integer;
                              out count: pinteger;
                              out status: status_$t);
var
  rcv: app_$receive_rec_t;
  nexthop: rip_$nexthop_t;
  dest: rip_$dest_addr_t;
  pkt_info: asknode_$template_t;
  response: asknode_$who_reply_t;
  request: asknode_$who_request_t;
  unused_288: array[1..3] of integer32;   { stand-in, see the TODO }
  deadline: integer32;
  quit_val: integer32;
  net: integer32;
  sock_ec: ec_$eventcount_ptr_t;
  wait_val: integer32;
  metric: integer;
  which: integer;
  local_status: status_$t;
  max_nodes: integer;
  port_index: pinteger;
  pkt_id: pinteger;
  copy_len: pinteger;
  dest_node: integer32;
  resp_id: pinteger;
  unused_2b6: array[1..2] of integer;     { stand-in, see the TODO }
  timeout: pinteger;
  retry_hint: integer;
  dump_len: pinteger;
  unused_2be: integer;                    { stand-in, see the TODO }
  sock_num: pinteger;
  hop_port: integer;
  is_local: boolean;
  unused_2d4: array[1..8] of integer;     { stand-in, see the TODO }
begin
  status.all := status_$ok;
  count := 0;
  max_nodes := max_count;
  if max_nodes <= 0 then
    return;
  if max_nodes > asknode_$max_who_count then
    max_nodes := asknode_$max_who_count;

  is_local := (node_id = 0) or (node_id = node_$me);
  if port <> -1 then
    net := port
  else if is_local then
    net := route_$port[0].network
  else
    net := dir_$find_net(name_$root_uid, node_id);

  dest.network := net;
  dest.host_node := 1;
  metric := rip_$find_nexthop(dest, false, hop_port, nexthop,
                              local_status);
  port_index := hop_port;
  if local_status.all <> status_$ok then begin
    status := local_status;
    return;
  end;

  if is_local or else (metric = 0) then begin
    count := 1;
    node_list[1] := node_$me;
    dest_node := 0;
  end
  else
    dest_node := node_id;

  if not sock_$allocate(sock_num, 16#20, 16#20, 0, 0) then begin
    status.all := status_$network_no_more_free_sockets;
    return;
  end;

  sock_ec := addr(sock_$socket_ptr[sock_num]^.ec);
  wait_val := ec_$read(sock_ec^) + 1;

  request.version := 3;
  request.req_type := asknode_$req_time_sync;
  request.args.param1 := node_$me;
  request.args.param2 := route_$portp[port_index]^.network;
  request.args.param3 := 16#5B8D8;
  pkt_id := pkt_$next_id;

  pkt_info := asknode_$pkt_info;
  pkt_info.retry_limit := 0;
  pkt_info.flags := 16#90;
  pkt_$send_internet(net, dest_node, 4, -1, node_$me, sock_num, pkt_info,
                     pkt_id, request, 24, 0, 0, retry_hint, timeout,
                     local_status);

  if local_status.all <> status_$ok then
    status := local_status
  else begin
    deadline := ec_$read(ec_$eventcount_ptr_t(addr(time_$clockh))^)
                + timeout + 6;
    quit_val := fim_$quit_value[proc1_$as_id] + 1;
    repeat
      which := ec_$wait(sock_ec,
                        ec_$eventcount_ptr_t(addr(time_$clockh)),
                        addr(fim_$quit_ec[proc1_$as_id]), wait_val,
                        deadline, quit_val);
      case which of
        0: begin
          app_$receive(sock_num, rcv, local_status);
          if local_status.all <> status_$ok then
            next;
          with pkt_$internet_hdr_ptr_t(rcv.reply)^ do begin
            dump_len := data_len;
            node_list[count + 1] := src_node;
            copy_len := min(hdr_len, 512);
            resp_id := request_id;
          end;
          os_$data_copy(pkt_$bytes_ptr_t(rcv.data)^, response,
                        copy_len);
          netbuf_$rtn_hdr(rcv.data);
          pkt_$dump_data(rcv.data_pages, dump_len);
          if local_status.all <> status_$ok then begin
            status := local_status;
            exit;
          end;
          if pkt_id = resp_id then
            if response.status.all <> status_$ok then
              status := response.status
            else begin
              count := count + 1;
              if count >= max_nodes then
                exit;
            end;
          wait_val := wait_val + 1;
        end;
        1: begin
          exit;
        end;
        2: begin
          fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
          status.all := status_$network_quit_fault_during_node_listing;
          exit;
        end;
        otherwise begin
          exit;
        end;
      end;
    until false;
  end;

  sock_$close(sock_num);
end;
