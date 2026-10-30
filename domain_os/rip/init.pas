{ RIP_$INIT - set up RIP's locks and, on a diskless node, learn the
  node's network from its mother node.

  Image addresses:
    sau2  0x00E2FBD0  RIP_$INIT

  - The RIP lock, ROUTE's service lock and XNS_ERROR's client lock are
    initialized.
  - A diskless node asks its mother node for its network on a socket of
    its own, until the timeout; the answer is port 0's network and RIP's
    own, and goes into both routings' tables as a direct route.
  - The loop does not advance the value it waits for.

  Status stored: none.
}

{ TODO(pascal) 32 frame bytes of RIP_$INIT hold nothing

  With rcv and ctl at multiples of 8 (4 open bytes
  above rcv, 2 below ctl's end), the addressed locals and the slots of
  the three register-held ones (route_port, pkt_id, reply_id) leave 32
  bytes of the frame that nothing addresses, in three runs.  dpc does
  not 8-align: the stand-ins unused_68 (20 bytes), unused_84 and
  unused_90 are sized for its layout, which then gives the image's
  offsets from wait_val down and the frame's 0x90 bytes (dpc
  --dump-locals; rcv, ctl, hdr_va and route_port come out 4..6 bytes
  higher). }

[section(os_init_proc, os_init_data)]
procedure rip_$init;
var
  request: static integer := 0;           { the OS_INIT_DATA block }
  rcv: app_$receive_rec_t;
  ctl: rip_$template_t;
  hdr_va: integer32;
  route_port: integer32;
  unused_68: array[1..5] of integer32;    { stand-in, see the TODO }
  wait_val: integer32;
  deadline: integer32;
  status: status_$t;
  data_len: integer;
  pkt_id: pinteger;
  reply_id: pinteger;
  unused_84: array[1..5] of integer;      { stand-in, see the TODO }
  timeout: pinteger;
  retry_hint: integer;
  sock_num: pinteger;
  unused_90: array[1..3] of integer;      { stand-in, see the TODO }
begin
  ml_$exclusion_init(rip_$exclusion);
  ml_$exclusion_init(route_$service_mutex);
  ml_$exclusion_init(xns_error_$client_mutex);

  if not network_$diskless then
    return;

  ctl := rip_$bcast_control;
  ctl.flags := ctl.flags - [7];
  if not sock_$allocate(sock_num, 1, 1, 1, 16#400) then
    return;

  wait_val := ec_$read(sock_$socket_ptr[sock_num]^.ec) + 1;
  pkt_id := pkt_$next_id;

  pkt_$send_internet(0, network_$mother_node, 1, 0, node_$me, sock_num,
                     ctl, pkt_id, request, 2, 0, 0, retry_hint, timeout,
                     status);

  if status.all = status_$ok then begin
    deadline := ec_$read(ec_$eventcount_ptr_t(addr(time_$clockh))^)
                + timeout + 1;
    while ec_$wait(addr(sock_$socket_ptr[sock_num]^.ec),
                   ec_$eventcount_ptr_t(addr(time_$clockh)),
                   addr(ec_$nil_ec), wait_val, deadline, 1) = 0 do begin
      app_$receive(sock_num, rcv, status);
      route_port := rcv.hdr_f06;
      data_len := pkt_$internet_hdr_ptr_t(rcv.reply)^.data_len;
      reply_id := pkt_$internet_hdr_ptr_t(rcv.reply)^.request_id;
      hdr_va := rcv.data & (-16#400);
      netbuf_$rtn_hdr(hdr_va);
      if status.all <> status_$ok then
        exit;
      if rcv.data_pages[1] <> 0 then
        pkt_$dump_data(rcv.data_pages, data_len);
      if reply_id = pkt_id then begin
        route_$port[0].network := route_port;
        rip_$route_port.network := route_port;
        rip_$update_int(route_port, rip_$route_port, 0, 0, false, status);
        rip_$update_int(route_port, rip_$route_port, 0, 0, true, status);
        exit;
      end;
    end;
  end;

  sock_$close(sock_num);
end;
