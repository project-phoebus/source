{ rem_file_$send_request - send one remote file request and wait for its
  reply.

  Image addresses:
    sau2  0x00E60FD8  rem_file_$send_request (module-local)

  - The transport every REM_FILE_ client stub goes through.  A server
    process (type 9) may not send; without the network's paging bit only
    the local node may be addressed.
  - A request longer than 512 bytes is split, its tail riding as the
    packet's data.  A busy server is waited out and the request sent
    again; replies to other requests are discarded.
  - A timeout adds 12 to the retry count (a busy reply 1): past 60 the
    node is given up on, except the diskless node's mother.
  - A failed socket allocation crashes the system.

  Status stored:
    the reply's status: a reply came
    file_$object_not_found: the caller is a server process
    file_$comms_problem_with_remote_node: a remote node without the
      paging bit, a failed send, or the node given up on
    file_$bad_reply_received_from_remote_node: the reply's opcode is
      wrong
    fault_$quit, its fail bit set: a quit
    status_$network_remote_node_failed_to_respond: no answer at all
    pkt_$likely_to_answer's status: the node answers nothing
}

procedure rem_file_$send_request(in addr_info: univ pkt_$net_addr_t;
                                 var request: univ rem_file_$request_hdr_t;
                                 request_len: integer;
                                 in extra_data: univ pkt_$bytes_t;
                                 extra_len: integer;
                                 var response: univ rem_file_$response_t;
                                 response_max: integer;
                                 out received_len: integer;
                                 var bulk_data: univ pkt_$bytes_t;
                                 bulk_max: integer;
                                 out bulk_len: integer;
                                 out packet_id: pinteger;
                                 out status_ret: status_$t);
  internal;
label
  10, 20, 30, 40;
var
  rcv: app_$receive_rec_t;
  unused_70: array[1..64] of char;     { stand-in }
  cleanup_rec: fim_$cleanup_rec_t;
  unused_94: array[1..12] of char;        { stand-in }
  bulk_handle: integer32;
  hdr_va: integer32;
  bulk_dest: pkt_$bytes_ptr_t;
  bulk_va: integer32;
  send_data_ptr: pkt_$bytes_ptr_t;
  sock_ec: ec_$eventcount_ptr_t;
  local_status: status_$t;
  deadline: integer32;
  quit_saved: integer32;
  sock_wait_val: integer32;
  conn_state: integer;
  want_data_page: integer;
  timeout_out: pinteger;
  retry_hint: integer;
  send_data_len: integer;
  template_len: integer;
  retry_count: integer;
  reply_id: pinteger;
  pkt_id: pinteger;
  sock_num: pinteger;
  hdr_len32: integer32;
  which: integer;
  rest: integer32;
  copy_len: integer32;
  len: integer32;
begin
  if proc1_$type[proc1_$current] = 9 then begin
    status_ret.all := file_$object_not_found;
    return;
  end;

  if not (network_service_paging in network_$allowed_service.service)
     and then (addr_info.node <> node_$me) then begin
    status_ret.all := file_$comms_problem_with_remote_node;
    return;
  end;

  if network_$diskless and then (addr_info.node = network_$mother_node)
  then
    conn_state := 2
  else
    conn_state := 0;

  request.msg_type := 1;

  if (bulk_max <> 0) or else (response_max > 512) then
    want_data_page := 1
  else
    want_data_page := 0;

  if not sock_$allocate(sock_num, 3, 1, want_data_page, 1024) then
    crash_system(status_$network_receive_process_failed_to_start);

  sock_ec := addr(sock_$socket_ptr[sock_num]^.ec);
  sock_wait_val := sock_ec^.value + 1;

  quit_saved := fim_$quit_value[proc1_$as_id];
  pkt_id := pkt_$next_id;
  retry_count := 0;

  { a request longer than the template is split }
  if request_len > 512 then begin
    if extra_len <> 0 then
      crash_system(status_$network_buffer_error);
    template_len := 512;
    send_data_len := request_len - 512;
    send_data_ptr := pkt_$bytes_ptr_t(integer32(addr(request)) + 512);
  end
  else begin
    template_len := request_len;
    send_data_len := extra_len;
    send_data_ptr := addr(extra_data);
  end;

  { out of retries }
10:
  if (retry_count > 60) and then (conn_state <> 2) then begin
    pkt_$note_visible(addr_info.node, false);
    status_ret.all := file_$comms_problem_with_remote_node;
    goto 40;
  end;

  pkt_$send_internet(addr_info.network, addr_info.node, 2, -1, node_$me,
                     sock_num, rem_file_$pkt_info, pkt_id, request,
                     template_len, send_data_ptr^, send_data_len,
                     retry_hint, timeout_out, local_status);

  if local_status.all <> status_$ok then begin
    if conn_state = 2 then
      goto 10;
    status_ret.all := file_$comms_problem_with_remote_node;
    goto 40;
  end;

  deadline := timeout_out + rem_file_$completion_time + time_$clockh;

  { the socket, the clock, or wait again }
20:
  repeat
    which := ec_$wait(sock_ec, addr(time_$clockh_ec), addr(ec_$nil_ec),
                      sock_wait_val, deadline, 0);
    if which = 0 then
      exit;
    if which = 1 then
      goto 30;
  until false;

  { the reply }
  sock_wait_val := sock_wait_val + 1;
  app_$receive(sock_num, rcv, local_status);
  if local_status.all = status_$network_buffer_queue_is_empty then
    goto 20;
  if local_status.all <> status_$ok then begin
    if bulk_handle <> 0 then
      netbuf_$rtn_dat(bulk_handle);
    retry_count := retry_count + 12;
    goto 10;
  end;

  with pkt_$internet_hdr_ptr_t(rcv.reply)^ do begin
    bulk_len := data_len;
    reply_id := request_id;
    hdr_len32 := hdr_len;
  end;

  { the header part }
  rest := response_max;
  copy_len := min(hdr_len32, rest);
  received_len := copy_len;
  len := received_len;
  os_$data_copy(pkt_$bytes_ptr_t(rcv.data)^, response, len);

  hdr_va := rcv.data & (-16#400);
  netbuf_$rtn_hdr(hdr_va);

  if bulk_len > 1024 then begin
    local_status.all := status_$network_data_length_too_large;
    pkt_$dump_data(rcv.data_pages, bulk_len);
    goto 20;
  end;

  { the bulk payload }
  bulk_handle := rcv.data_pages[1];
  if bulk_handle <> 0 then begin
    netbuf_$getva(bulk_handle, bulk_va, local_status);
    if local_status.all <> status_$ok then
      crash_system(local_status);
    if bulk_max = 0 then begin
      bulk_dest := pkt_$bytes_ptr_t(len + integer32(addr(response)));
      rest := rest - len;
      bulk_len := min(rest, bulk_len);
    end
    else begin
      bulk_dest := addr(bulk_data);
      bulk_len := min(bulk_len, bulk_max);
    end;
    if bulk_len > 0 then begin
      local_status := fim_$cleanup(cleanup_rec);
      if local_status.all = fault_$cleanup_set then begin
        os_$data_copy(pkt_$bytes_ptr_t(bulk_va)^, bulk_dest^, bulk_len);
        fim_$rls_cleanup(cleanup_rec);
      end
      else begin
        netbuf_$rtn_dat(netbuf_$rtnva(bulk_va));
        fim_$signal(local_status);
      end;
    end;
    if bulk_max = 0 then
      bulk_len := 0;
    netbuf_$rtn_dat(netbuf_$rtnva(bulk_va));
  end;

  { another request's reply }
  if pkt_id <> reply_id then
    goto 20;

  if (conn_state = 1) or else (conn_state = 0) then begin
    conn_state := 3;
    pkt_$note_visible(addr_info.node, true);
  end;

  { the server is busy }
  if response.pkt_flag = -1 then begin
    rem_file_$busy_retry_count := rem_file_$busy_retry_count + 1;
    discard(ec_$wait(addr(time_$clockh_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), time_$clockh + 2, 0, 0));
    retry_count := retry_count + 1;
    goto 10;
  end;

  if response.opcode = request.opcode + 1 then
    status_ret := response.status
  else
    status_ret.all := file_$bad_reply_received_from_remote_node;
  goto 40;

  { the clock, or a quit }
30:
  if quit_saved <> fim_$quit_ec[proc1_$as_id].value then begin
    status_ret.all := fault_$quit;
    status_ret.fail := true;
    fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
    goto 40;
  end;

  retry_count := retry_count + 12;
  case conn_state of
    0: conn_state := 1;
    1: if pkt_$likely_to_answer(addr_info, status_ret) then
         conn_state := 3
       else begin
         status_ret.all := status_$network_remote_node_failed_to_respond;
         goto 40;
       end;
  end;
  goto 10;

40:
  sock_$close(sock_num);
  packet_id := pkt_id;
end;
