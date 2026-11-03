{ network_$do_request - send a request to a node and wait for its reply.

  Image addresses:
    sau2  0x00E0F86C  network_$do_request (module-local)
    sau8  0x03C10BA0  network_$do_request (module-local)

  - On a socket of its own (no free socket crashes the system), the
    request is sent and the reply waited for, again and again, up to the
    retry limit network_$send_request hands back.
  - A reply marks the node visible and its data pages are dumped.  The
    retry limit reached (not for the mother node) marks the node not
    visible.
  - With check_flag, the second time out asks PKT_$LIKELY_TO_ANSWER
    whether to go on.

  Status stored:
    the reply's own status: its op is the request's plus one
    status_$network_unexpected_reply_type: another reply
    status_$network_remote_node_failed_to_respond: the retry limit
    network_$send_request's status: the send failed
    pkt_$likely_to_answer's status: the node is not likely to answer
}

{ TODO(pascal) network_$do_request's frame

  The frame (0x28 bytes): the reserved slot, data_bufs (0x10),
  event_count, timeout, max_retries, rdata_len, pkt_id, sock_num.  Not
  addressed: 4 bytes below the reserved slot and 2 at the bottom
  (retry_count's slot would be a word; the longword is not
  explained). }

procedure network_$do_request(in node_addr: uid_$t;
                              in cmd_buf: univ network_$msg_hdr_t;
                              cmd_len: integer; data_pa: integer32;
                              data_len: pinteger; check_flag: boolean;
                              out resp_buf: univ network_$msg_hdr_t;
                              out resp_info: integer;
                              out status_ret: status_$t); internal;
label
  10;
var
  data_bufs: pkt_$data_pages_t;
  event_count: integer32;
  timeout: pinteger;
  max_retries: pinteger;
  rdata_len: pinteger;
  pkt_id: integer;
  sock_num: integer;
  retry_count: integer;
begin
  retry_count := 0;
  if not sock_$allocate(sock_num, 2, 0, 0, 16#400) then
    crash_system(status_$network_receive_process_failed_to_start);

  event_count := sock_$socket_ptr[sock_num]^.ec.value + 1;
  pkt_id := pkt_$next_id;

  repeat
    network_$send_request(node_addr, sock_num, pkt_id, cmd_buf, cmd_len,
                          data_pa, data_len, max_retries, timeout,
                          status_ret);
    if status_ret.all <> status_$ok then
      goto 10;

    if network_$wait_response(sock_num, pkt_id,
                              network_$service_time + timeout, event_count,
                              resp_buf, resp_info, data_bufs,
                              rdata_len) then begin
      pkt_$note_visible(node_addr.low, true);
      exit;
    end;

    retry_count := retry_count + 1;
    if (retry_count >= max_retries) and then
       (node_addr.low <> network_$mother_node) then begin
      status_ret.all := status_$network_remote_node_failed_to_respond;
      pkt_$note_visible(node_addr.low, false);
      goto 10;
    end;

    if check_flag and then (retry_count = 2) and then
       (node_addr.low <> network_$mother_node) then
      if not pkt_$likely_to_answer(node_addr, status_ret) then
        goto 10;
  until false;

  if data_bufs[1] <> 0 then
    pkt_$dump_data(data_bufs, rdata_len);
  if resp_buf.op <> cmd_buf.op + 1 then
    status_ret.all := status_$network_unexpected_reply_type
  else
    status_ret := resp_buf.status;

10:
  sock_$close(sock_num);
end;
