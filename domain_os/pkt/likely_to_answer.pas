{ PKT_$LIKELY_TO_ANSWER - is a node likely to answer a request?

  Image addresses:
    sau2  0x00E1299E  PKT_$LIKELY_TO_ANSWER

  - A node reached directly through a port of type 4 is pinged on a
    socket of its own, up to three times, and the outcome noted
    (PKT_$NOTE_VISIBLE); the result is whether it answered.
  - Any other node: whether it is missing from the list of nodes that
    failed to answer.

  Status stored:
    status_$network_remote_node_failed_to_respond: not pinged, or no
      reply
    status_$ok: a reply came
    rip_$find_nexthop's status: no route
    status_$network_no_more_free_sockets: no socket for the ping
    pkt_$send_internet's or app_$receive's status: a ping failed
}

{ TODO(pascal) 30 frame bytes of PKT_$LIKELY_TO_ANSWER hold nothing

  The addressed locals, the slots of the register-held ones (hops,
  need_ping, got_response, request_id, resp_id, wait_val, i, and
  sock_num's and port's homes), the result variable and the 4-byte
  temporary leave 30 bytes of the frame that no instruction addresses,
  held by stand-ins.  The locals one might declare (an eventcount slot, a
  request header, a retry count) are not enough to fill them by size;
  `with' temporaries do not occur here.  Not settled. }

function pkt_$likely_to_answer(in addr_info: univ pkt_$net_addr_t;
                               out status_ret: status_$t): boolean;
var
  hops: integer;
  need_ping: boolean;
  got_response: boolean;
  nexthop: rip_$nexthop_t;
  request_id: pinteger;
  resp_id: pinteger;
  dest: rip_$dest_addr_t;
  wait_val: integer32;
  recv: app_$receive_rec_t;
  hdr_va: integer32;
  unused_58: integer32;                   { stand-in }
  deadline: integer32;
  unused_64: array[1..8] of char;         { stand-in }
  resp_timeout: pinteger;
  retry_hint: integer;
  i: integer;                             { the loop's count only }
  unused_6c: integer;                     { stand-in }
  data_len: integer;
  sock_num: pinteger;
  port: integer;
  unused_82: array[1..16] of char;        { stand-in }
begin
  { the route }
  dest.network := addr_info.network;
  dest.host_node := addr_info.node;
  hops := rip_$find_nexthop(dest, false, port, nexthop, status_ret);
  if status_ret.all <> status_$ok then begin
    pkt_$likely_to_answer := false;
    return;
  end;
  pkt_$likely_to_answer := true;

  need_ping := (hops = 0) and then (route_$portp[port]^.port_type = 4);
  if not need_ping then begin
    { the status store is shared with the ping arm's last statement }
    pkt_$likely_to_answer := not pkt_$recently_missing(addr_info.node);
    status_ret.all := status_$network_remote_node_failed_to_respond;
  end
  else begin
    { a socket of our own }
    if not sock_$allocate(sock_num, 2, 1, 0, 1024) then begin
      status_ret.all := status_$network_no_more_free_sockets;
      return;
    end;

    got_response := false;
    request_id := pkt_$next_id;
    wait_val := sock_$socket_ptr[sock_num]^.ec.value + 1;

    { up to three pings }
    for i := 1 to 3 do begin
      pkt_$send_internet(addr_info.network, addr_info.node, 13, -1,
                         node_$me, sock_num, pkt_$ping_template,
                         request_id, pkt_$ping_req_hdr, 2, 0, 0,
                         retry_hint, resp_timeout, status_ret);
      if status_ret.all <> status_$ok then
        exit;
      deadline := time_$clockh + resp_timeout + 1;
      while ec_$wait(addr(sock_$socket_ptr[sock_num]^.ec),
                     ec_$eventcount_ptr_t(addr(time_$clockh)),
                     addr(ec_$nil_ec), wait_val, deadline, 1) = 0 do begin
        wait_val := wait_val + 1;
        app_$receive(sock_num, recv, status_ret);
        if status_ret.all <> status_$ok then
          exit;
        data_len := pkt_$internet_hdr_ptr_t(recv.reply)^.data_len;
        resp_id := pkt_$internet_hdr_ptr_t(recv.reply)^.request_id;
        hdr_va := recv.data & (-16#400);
        netbuf_$rtn_hdr(hdr_va);
        if recv.data_pages[1] <> 0 then
          pkt_$dump_data(recv.data_pages, data_len);
        if request_id = resp_id then begin
          got_response := true;
          exit;
        end;
      end;
      if got_response then
        exit;
    end;

    sock_$close(sock_num);
    pkt_$note_visible(addr_info.node, got_response);
    pkt_$likely_to_answer := got_response;
    if (status_ret.all = status_$ok) and (not got_response) then
      status_ret.all := status_$network_remote_node_failed_to_respond;
  end;
end;
