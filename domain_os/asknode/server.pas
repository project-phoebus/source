{ ASKNODE_$SERVER - answer one node query received on socket 4.

  Image addresses:
    sau2  0x00E6597A  ASKNODE_$SERVER

  - The who requests 0 and 16#2D and the time request 16#45 have their
    own arms, 39 types go through ASKNODE_$INTERNET_INFO, 16#E records a
    failure (no answer), 16#31 answers with the log in a data page.
  - A request to be passed on (0 and 16#2D whose count is not spent,
    16#45) is written into ctx for NETWORK_$REQUEST_SERVER.
  - Only request 16#31 assigns data_p; the other sends pass it with a
    data length of 0.

  Status stored: none.
}

procedure asknode_$server(var ctx: asknode_$server_ctx_t;
                          var routing: integer32);
type
  { The request ASKNODE_$SERVER copies out of the packet, 0x18 bytes:
    the version, compared and copied as a word; the type, the jump
    table's selector, a word incremented, passed by address to
    INTERNET_INFO; then the views of +0x04:
    - args, the context's five longwords (asknode/asknode.ins.pas),
      copied whole;
    - param, INTERNET_INFO's parameter block, and request 16#31's log
      word and offset (asknode_$param_t's 16#31 view);
    - hops, request 0's hop count, the word at +0x08, copied, compared
      signed and decremented: integer. }
  request_t = record
    version: integer;                     { 0x00 }
    req_type: integer;                    { 0x02 }
    case integer of
      1: (args: asknode_$server_args_t);  { 0x04..0x17 }
      2: (param: asknode_$param_t);       { 0x04.. }
      3: (unused_04: linteger;            { 0x04 }
          hops: integer);                 { 0x08 }
  end;

  { The reply ASKNODE_$SERVER sends, 0x200 bytes (the send's template;
    INTERNET_INFO fills it as its result, its own view
    asknode/asknode_info.ins.pas asknode_$info_reply_t).  version and
    response_type words, pinteger as the INTERNET_INFO view; the status
    a longword, status_$t, its low word (the code field) stored alone by
    request 16#31.  The who-answers' head: the node, linteger as
    node_$me; the flags word 16#B1FF, pinteger; the count, copied from
    the request's integer words, integer.  Request 16#31's view: the
    length LOG_$READ and _$READ2 write, pinteger as their formal, read
    as a word, and the end of the template at +0x0A. }
  reply_t = record
    version: pinteger;                    { 0x00 }
    response_type: pinteger;              { 0x02 }
    status: status_$t;                    { 0x04 }
    case integer of
      0: (raw: array[1..504] of char); { 0x08..0x1FF }
      1: (node: linteger;                 { 0x08 }
          flags: pinteger;                { 0x0C }
          count: integer);                { 0x0E }
      2: (log_len: pinteger;              { 0x08 }
          log_data: char);                { 0x0A }
  end;

var
  rcv: app_$receive_rec_t;
  pkt_info: asknode_$template_t;
  reply: reply_t;
  request: request_t;
  log_status: status_$t;
  log_va: integer32;
  log_ppn: integer32;
  status: status_$t;
  routing_key: integer32;
  timeout: pinteger;
  retry_hint: integer;
  log_len: pinteger;
  template_len: pinteger;
  data_len: integer;
  req_id: pinteger;
  src_socket: pinteger;
  is_local: boolean;
  src_node_or: integer32;
  rx_flags: integer;
  sender_node: integer32;
  peer_node: integer32;
  dat: integer32;
  copy_len: pinteger;
  propagate: boolean;
  data_p: pkt_$bytes_ptr_t;
begin
  app_$receive(4, rcv, status);
  if status.all <> status_$ok then
    return;

  pkt_$dump_data(rcv.data_pages,
                 pkt_$internet_hdr_ptr_t(rcv.reply)^.data_len);

  src_node_or := rcv.hdr_f06;
  routing_key := rcv.hdr_f12;
  with pkt_$internet_hdr_ptr_t(rcv.reply)^ do begin
    sender_node := dest_node;
    peer_node := src_node;
    src_socket := src_sock;
    rx_flags := flags;
    req_id := request_id;
    copy_len := 24;
    if hdr_len < copy_len then
      copy_len := hdr_len;
  end;

  os_$data_copy(pkt_$bytes_ptr_t(rcv.data)^, request, copy_len);
  netbuf_$rtn_hdr(rcv.data);

  reply.response_type := request.req_type + 1;
  if request.version = 2 then
    reply.version := 2
  else
    reply.version := 3;
  dat := 0;
  data_len := 0;
  template_len := 512;
  propagate := false;

  case request.req_type of
    asknode_$req_who: begin
      if rcv.hdr_flag then
        return;
      reply.node := node_$me;
      reply.count := request.hops;
      peer_node := request.args.node_id;
      request.hops := request.hops - 1;
      ctx.clock.low32 := 16#1000;
      reply.flags := 16#B1FF;
      if src_node_or = 0 then
        routing := routing_key
      else
        routing := src_node_or;
      reply.status.all := status_$ok;
      case route_$validate_port(routing, true) of
        2: reply.status.all :=
             status_$network_operation_not_defined_on_hardware;
        0: reply.status.all := status_$network_unknown_network;
      end;
      propagate := (reply.status.all = status_$ok)
                   and (request.hops > 0)
                   and (peer_node <> node_$me)
                   and ((rx_flags & 4) = 0);
      ctx.request_type := asknode_$req_who;
    end;

    asknode_$req_who_remote: begin
      if rcv.hdr_flag then
        return;
      if not request.args.forwarded and then
         (request.args.node_id = node_$me) then begin
        reply.node := request.args.param1;
        reply.response_type := asknode_$reply_who;
      end
      else begin
        reply.response_type := asknode_$reply_who_remote;
        reply.node := node_$me;
      end;
      reply.flags := 16#B1FF;
      if src_node_or = 0 then
        routing := routing_key
      else
        routing := src_node_or;
      is_local := (sender_node = 0)
                  or (sender_node = node_$me);
      reply.status.all := status_$ok;
      case route_$validate_port(routing, is_local) of
        2: reply.status.all :=
             status_$network_operation_not_defined_on_hardware;
        0: reply.status.all := status_$network_unknown_network;
      end;
      reply.count := request.args.count;
      peer_node := request.args.param1;
      routing_key := request.args.param2;
      request.args.count := request.args.count - 1;
      ctx.clock.low32 := request.args.param3;
      propagate := (reply.status.all = status_$ok)
                   and (request.args.count > 0)
                   and ((request.args.node_id <> node_$me)
                        or request.args.forwarded)
                   and ((rx_flags & 4) = 0);
      ctx.request_type := asknode_$req_who_remote;
    end;

    asknode_$req_time_sync: begin
      reply.response_type := asknode_$reply_time_sync;
      reply.node := node_$me;
      reply.status.all := status_$ok;
      reply.flags := 16#B1FF;
      if src_node_or = 0 then
        routing := routing_key
      else
        routing := src_node_or;
      time_$clock(ctx.clock);
      ctx.clock.high16 := 0;
      ctx.clock.low32 := (ctx.clock.low32 & 16#7FFFFFFF)
                         * request.args.param3;
      propagate := true;
      ctx.request_type := asknode_$reply_time_sync;
    end;

    asknode_$req_boot_time, asknode_$req_node_uid, asknode_$req_stats,
    asknode_$req_timezone, asknode_$req_volume_info, asknode_$req_paging_info,
    asknode_$req_disk_stats, asknode_$req_proc_list, asknode_$req_proc_info,
    asknode_$req_signal, asknode_$req_root_uid, asknode_$req_build_time,
    asknode_$req_uids, asknode_$req_proc_info2, asknode_$req_proc_upids,
    asknode_$req_log_control, asknode_$req_system_info,
    asknode_$req_net_stats, asknode_$req_proc_pid, asknode_$req_failure_rec,
    asknode_$req_proc1_list, asknode_$req_signal2, asknode_$req_route_port,
    asknode_$req_port_list, asknode_$req_port_info, asknode_$req_device_stat,
    asknode_$req_route_stats, asknode_$req_net_route,
    asknode_$req_queue_depth, asknode_$req_boot_device, asknode_$req_loadav,
    asknode_$req_proc_ws_info, asknode_$req_rev_info,
    asknode_$req_zombie_list, asknode_$req_disk_info,
    asknode_$req_display_list, asknode_$req_proc_list2,
    asknode_$req_zombie_list2, asknode_$req_device_stat2: begin
      asknode_$internet_info(request.req_type, node_$me, 0, request.param,
                             512, reply, status);
    end;

    asknode_$req_record_failure: begin
      network_$failure_rec.flag := true;
      network_$failure_rec.node_id := peer_node;
      network_$failure_rec.timestamp := time_$current_clockh;
      network_$failure_rec.failure_type := request.args.node_id;
      return;
    end;

    asknode_$req_log_read: begin
      netbuf_$get_dat(log_ppn);
      dat := log_ppn;
      netbuf_$getva(dat, log_va, log_status);
      data_p := pkt_$bytes_ptr_t(log_va);
      reply.status := log_status;
      if reply.status.all = status_$ok then begin
        if 0 in request.param.log.flags then begin
          log_$read2(data_p^, request.param.log.offset, 16#400,
                     reply.log_len);
          reply.status.code := -1;
        end
        else begin
          log_len := min(request.param.log.max_len, 16#400);
          log_$read(data_p^, log_len, reply.log_len);
        end;
        template_len := integer32(addr(reply.log_data))
                        - integer32(addr(reply));
        data_len := reply.log_len;
      end;
    end;

    otherwise begin
      reply.response_type := 0;
      reply.status.all := status_$network_unknown_request_type;
    end;
  end;

  if request.req_type = asknode_$req_time_sync then
    status.all := status_$ok
  else begin
    pkt_info := asknode_$pkt_info;
    pkt_info.flags := 16#20;
    pkt_info.retry_limit := 1;
    pkt_$send_internet(routing_key, peer_node, src_socket, src_node_or,
                       sender_node, 4, pkt_info, req_id, reply,
                       template_len, data_p^, data_len, retry_hint,
                       timeout, status);
  end;

  if dat <> 0 then
    netbuf_$rtn_dat(netbuf_$rtnva(log_va));

  if propagate and then (status.all = status_$ok) then begin
    if request.req_type = asknode_$req_who_remote then
      request.args.forwarded := false;
    ctx.version := request.version;
    ctx.args := request.args;
    ctx.request_id := req_id;
    ctx.socket := src_socket;
  end;
end;
