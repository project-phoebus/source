{ PKT_$SAR_INTERNET - send an internet request and wait for its reply.

  Image addresses:
    sau2  0x00E71EC4  PKT_$SAR_INTERNET

  - On a socket of its own (none crashes the system); a reply with the
    request's id has its template and data copied out, others dropped.
  - A timeout resends up to the retry limit, asking
    PKT_$LIKELY_TO_ANSWER after the second try; the node is noted as
    not answering past two.

  Status stored:
    app_$receive's status: a reply came
    pkt_$send_internet's status: a send failed
    status_$network_remote_node_failed_to_respond: the tries ran out, or
      the node is not likely to answer
    fault_$quit: a quit ended the wait
}

[section(procedure$, data$)]
procedure pkt_$sar_internet(routing_key: integer32;
                            dest_node: integer32;
                            dest_sock: integer;
                            in pkt_info: univ pkt_$info_t;
                            timeout: pinteger;
                            in req_template: univ pkt_$bytes_t;
                            req_tpl_len: pinteger;
                            in req_data: univ pkt_$bytes_t;
                            req_data_len: integer;
                            out resp_buf: pkt_$sar_result_t;
                            out resp_tpl_buf: univ pkt_$bytes_t;
                            resp_tpl_max: pinteger;
                            out resp_tpl_len: integer;
                            out resp_data_buf: univ pkt_$bytes_t;
                            resp_data_max: pinteger;
                            out resp_data_len: pinteger;
                            out status_ret: status_$t);
  options(val_param);
label
  resend, done;
var
  which: integer;
  n: pinteger;
  rec: app_$receive_rec_t;
  addr_info: pkt_$net_addr_t;
  sock_ec: ec_$eventcount_ptr_t;
  timeout_val: integer32;
  quit_val: integer32;
  request_id: pinteger;
  retry_num: integer;
  wait_val: integer32;
  recv_id: pinteger;
  delay: pinteger;
  max_retries: pinteger;
  retry_hint: integer;
  rtt_hint: pinteger;
  unused_58: integer;                     { stand-in }
  unused_5c: integer32;
  unused_5e: integer;
  sock_num: pinteger;
  unused_64: integer32;                   { stand-in }
begin
  if not sock_$allocate(sock_num, 2, 1, 1, 1024) then
    crash_system(status_$network_receive_process_failed_to_start);

  sock_ec := addr(sock_$socket_ptr[sock_num]^.ec);
  request_id := pkt_$next_id;
  wait_val := sock_ec^.value + 1;
  quit_val := fim_$quit_value[proc1_$as_id] + 1;
  addr_info.network := routing_key;
  addr_info.node := dest_node;
  retry_num := 1;
  if pkt_info.retry_limit = 0 then
    max_retries := 16#FFFF
  else
    max_retries := pkt_info.retry_limit;

  { a try }
resend:
  pkt_$send_internet(routing_key, dest_node, dest_sock, -1, node_$me,
                     sock_num, pkt_info, request_id, req_template,
                     req_tpl_len, req_data, req_data_len, retry_hint,
                     rtt_hint, status_ret);
  if status_ret.all <> status_$ok then
    goto done;
  delay := rtt_hint + timeout;
  if max_retries = 16#FFFF then
    max_retries := retry_hint;
  timeout_val := time_$clockh + delay;

  { the wait }
  repeat
    which := ec_$wait(sock_ec, ec_$eventcount_ptr_t(addr(time_$clockh)),
                      addr(fim_$quit_ec[proc1_$as_id]), wait_val,
                      timeout_val, quit_val);

    { the timeout }
    if which = 1 then begin
      if retry_num = max_retries then begin
        if retry_num > 2 then
          pkt_$note_visible(dest_node, false);
      end
      else if (retry_num <> 2) or else
              pkt_$likely_to_answer(addr_info, status_ret) then begin
        retry_num := retry_num + 1;
        goto resend;
      end;
      resp_buf.attempts := retry_num;
      status_ret.all := status_$network_remote_node_failed_to_respond;
      exit;
    end;

    { a quit }
    if which = 2 then begin
      fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
      status_ret.all := fault_$quit;
      exit;
    end;

    { a reply }
    wait_val := wait_val + 1;
    app_$receive(sock_num, rec, status_ret);
    if status_ret.all <> status_$ok then
      next;
    n := min(pkt_$internet_hdr_ptr_t(rec.reply)^.hdr_len, resp_tpl_max);
    resp_tpl_len := n;
    os_$data_copy(pkt_$bytes_ptr_t(rec.data)^, resp_tpl_buf, n);
    recv_id := pkt_$internet_hdr_ptr_t(rec.reply)^.request_id;
    netbuf_$rtn_hdr(rec.data);
    if rec.data_pages[1] <> 0 then begin
      n := min(pkt_$internet_hdr_ptr_t(rec.reply)^.data_len, resp_data_max);
      resp_data_len := n;
      pkt_$dat_copy(rec.data_pages, n, integer32(addr(resp_data_buf)));
      pkt_$dump_data(rec.data_pages,
                     pkt_$internet_hdr_ptr_t(rec.reply)^.data_len);
    end
    else
      resp_data_len := 0;
    if recv_id = request_id then
      exit;
  until false;

  if status_ret.all = status_$ok then
    pkt_$note_visible(dest_node, true);

done:
  sock_$close(sock_num);
end;
