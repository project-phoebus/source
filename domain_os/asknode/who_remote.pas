{ ASKNODE_$WHO_REMOTE - list the nodes of a network through its servers.

  Image addresses:
    sau2  0x00E66334  ASKNODE_$WHO_REMOTE

  - Only on a node that serves paging requests, on the who socket (5):
    a who request (type 0) to node 2 or the node, or for a far network a
    remote who request (type 16#2D) a node there answers.
  - An answer flagged 16#B1FF carries its own position; a node already
    listed, or this node's own who reply, ends the listing.
  - Positioned answers must arrive in order, and a node already listed
    ends the whole listing.

  Status stored:
    status_$ok: the listing is done
    status_$network_operation_not_defined_on_hardware: route_$validate_port
      answers 2
    status_$network_conflict_with_another_node_listing: the who socket is
      busy
    pkt_$send_internet's status: the request was not sent
    status_$network_waited_too_long_for_more_node_responses: the timeout
    status_$network_quit_fault_during_node_listing: a quit
}

{ TODO(pascal) WHO_REMOTE's frame has 44 bytes nothing addresses

  In the SAU2 image the records lie at multiples of 8, and below them
  the addressed locals leave holes (4, 8, 14 and 18 bytes) for the
  register-held locals' homes, which no instruction shows.  dpc does not
  8-align: the register-held locals are declared into those holes by
  size, and the stand-ins unused_268 and unused_2ac fill the rest, which
  gives the image's offsets from sock_ec down and the image's frame
  size.  Which register's home is where is not known. }

procedure asknode_$who_remote(in node_id: linteger;
                              in port: integer32;
                              out node_list: asknode_$node_list_t;
                              in max_count: integer;
                              out count: pinteger;
                              out status: status_$t);
label
  done;
var
  rcv: app_$receive_rec_t;
  pkt_info: asknode_$template_t;
  response: asknode_$who_reply_t;
  request: asknode_$who_request_t;
  unused_268: integer32;                  { stand-in, see the TODO }
  sock_ec: ec_$eventcount_ptr_t;
  local_status: status_$t;
  quit_val: integer32;
  net: integer32;
  dest_node: integer32;
  wait_val: integer32;
  clock_ec: ec_$eventcount_ptr_t;
  dump_len: pinteger;
  timeout: pinteger;
  retry_hint: integer;
  len: pinteger;
  n: integer;
  pkt_id: pinteger;
  which: integer;
  copy_len: integer;
  resp_id: pinteger;
  pos: integer;
  max_nodes: integer;
  i: integer;
  is_local: boolean;
  unused_2ac: array[1..7] of integer;     { stand-in, see the TODO }
begin
  local_status.all := status_$ok;
  status := local_status;
  n := 0;
  count := n;

  max_nodes := max_count;
  if max_nodes <= 0 then
    return;
  if max_nodes > asknode_$max_who_count then
    max_nodes := asknode_$max_who_count;

  is_local := (node_id = 0) or (node_id = node_$me);
  if is_local then begin
    node_list[1] := node_$me;
    count := 1;
    n := 1;
  end
  else
    count := n;

  if (n >= max_nodes)
     or else not (network_service_paging in network_$allowed_service.service)
  then
    return;

  if asknode_$protocol_version = 3 then
    request.version := 2
  else
    request.version := 3;

  request.args.node_id := node_$me;
  dest_node := node_id;
  len := 16;
  if port <> -1 then
    net := port
  else if is_local then
    net := route_$port[0].network
  else
    net := dir_$find_net(name_$root_uid, node_id);

  if route_$validate_port(net, is_local) = 2 then begin
    status.all := status_$network_operation_not_defined_on_hardware;
    return;
  end;

  if not sock_$open(asknode_$who_socket, 16#20, 16#20, 0, 0) then begin
    status.all := status_$network_conflict_with_another_node_listing;
    return;
  end;

  sock_ec := addr(sock_$socket_ptr[asknode_$who_socket]^.ec);

  if (is_local or (net = 0)) or else (net = route_$port[0].network) then
  begin
    request.req_type := asknode_$req_who;
    if is_local then begin
      dest_node := 2;
      len := 144;
      request.hops := max_nodes - 1;
    end
    else
      request.hops := max_nodes;
  end
  else begin
    request.req_type := asknode_$req_who_remote;
    request.args.param1 := node_$me;
    request.args.param2 := route_$port[0].network;
    request.args.count := max_nodes;
    request.args.forwarded := true;
    request.args.node_id := node_id;
    request.args.param3 := 16#4000;
  end;

  pkt_id := pkt_$next_id;
  wait_val := sock_ec^.value;
  pkt_info := asknode_$pkt_info;
  pkt_info.flags := len;

  pkt_$send_internet(net, dest_node, 4, -1, node_$me, asknode_$who_socket,
                     pkt_info, pkt_id, request, 24, 0, 0, retry_hint,
                     timeout, local_status);

  if local_status.all = status_$ok then begin
    quit_val := fim_$quit_value[proc1_$as_id] + 1;
    for i := n + 1 to max_nodes do
      node_list[i] := 0;
    clock_ec := ec_$eventcount_ptr_t(addr(time_$clockh));
    while n < max_nodes do begin
      wait_val := wait_val + 1;
      which := ec_$wait(sock_ec, clock_ec, addr(fim_$quit_ec[proc1_$as_id]),
                        wait_val, time_$clockh + timeout + 16#14,
                        quit_val);
      timeout := 0;
      if which = 1 then begin
        local_status.all :=
          status_$network_waited_too_long_for_more_node_responses;
        exit;
      end;
      if which = 2 then begin
        fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
        local_status.all := status_$network_quit_fault_during_node_listing;
        exit;
      end;
      app_$receive(asknode_$who_socket, rcv, local_status);
      if local_status.all <> status_$ok then
        next;
      with pkt_$internet_hdr_ptr_t(rcv.reply)^ do begin
        dump_len := data_len;
        copy_len := min(hdr_len, 512);
        resp_id := request_id;
      end;
      os_$data_copy(pkt_$bytes_ptr_t(rcv.data)^, response,
                    copy_len);
      netbuf_$rtn_hdr(rcv.data);
      pkt_$dump_data(rcv.data_pages, dump_len);
      local_status := response.status;
      if local_status.all <> status_$ok then
        next;
      if pkt_id <> resp_id then
        next;
      if (response.response_type <> asknode_$reply_who)
         and then (response.response_type <> asknode_$reply_who_remote)
      then
        next;
      if (response.node = node_$me)
         and then (response.response_type = asknode_$reply_who) then
        exit;
      if response.flags = 16#B1FF then begin
        pos := max_nodes - response.count + 1;
        if pos = n + 1 then
          n := pos;
        if pos <= n then
          node_list[pos] := response.node;
      end
      else begin
        for i := 1 to n do
          if node_list[i] = response.node then
            goto done;
        n := n + 1;
        node_list[n] := response.node;
      end;
    end;
  end;

done:
  sock_$close(asknode_$who_socket);
  count := n;
  status := local_status;
end;
