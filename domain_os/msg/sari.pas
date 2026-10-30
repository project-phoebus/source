{ MSG_$SARI - send a request and wait for its reply.

  Image addresses:
    sau2  0x00E59DD4  MSG_$SARI

  - On a user socket of its own, with a new request id, the request goes
    by MSG_$$SEND; then it waits on the socket, the clock (the caller's
    ticks) and the quit eventcount.
  - A message without error and with the request's id ends the wait;
    others are taken in and dropped.  The socket is closed at the end.

  Status stored:
    msg_$$rcv_internal's status: the reply came
    msg_$$send's status: the send failed
    status_$msg_no_more_sockets: no socket was left
    status_$network_remote_node_failed_to_respond: the timeout
    fault_$quit: a quit (noted as seen)
}

{ TODO(pascal) 58 frame bytes of MSG_$SARI no object explains

  Every addressed object of the SAU2 frame is accounted for, and the
  two register-held locals' slots; 52 bytes at the top (as in
  MSG_$RCVI: see the TODO(pascal) in msg/rcvi.pas) and three words
  below hold the stand-ins.  No other local is known. }

procedure msg_$sari(in timeout: integer;
                    in routing_key: integer32;
                    in dest_node: linteger;
                    in dest_sock: pinteger;
                    in pkt_info: msg_$template_t;
                    in send_template: univ pkt_$bytes_t;
                    in send_template_len: pinteger;
                    in send_data: univ pkt_$bytes_t;
                    in send_data_len: pinteger;
                    out xmit_status_ret: msg_$xmit_flags_t;
                    out hw_addr: msg_$hw_addr_t;
                    out rcv_template: univ pkt_$bytes_t;
                    in rcv_template_max: pinteger;
                    out rcv_template_len_ret: pinteger;
                    out rcv_data: univ pkt_$bytes_t;
                    in rcv_data_max: pinteger;
                    out rcv_data_len_ret: pinteger;
                    out status_ret: status_$t);
var
  unused_30: array[1..48] of char;        { stand-in }
  unused_34: integer32;
  send_info: msg_$send_info_t;
  rcv_src_node: linteger;
  rcv_src_net: integer32;
  rcv_dest_node: linteger;
  rcv_dest_net: integer32;
  wait_val: integer32;
  quit_val: integer32;
  deadline: integer32;
  request_id: pinteger;
  unused_58: integer;                     { stand-in }
  ec_param2: pinteger;
  ec_param1: integer;
  rcv_src_sock: pinteger;
  rcv_dest_sock: pinteger;
  unused_62: integer;                     { stand-in }
  sock_num: pinteger;                     { held, with its home slot }
  unused_66: integer;                     { stand-in }
  rcv_msg_type: pinteger;
  sock_ec: ec_$eventcount_ptr_t;
begin
  if not sock_$allocate_user(sock_num, 1, 1, 1, 16#400) then begin
    status_ret.all := status_$msg_no_more_sockets;
    return;
  end;

  { the request }
  sock_ec := addr(sock_$socket_ptr[sock_num]^.ec);
  request_id := pkt_$next_id;
  wait_val := sock_ec^.value;
  quit_val := fim_$quit_value[proc1_$as_id] + 1;
  msg_$$send(-1, routing_key, dest_node, dest_sock, -1, node_$me,
             sock_num, pkt_info, request_id, send_template,
             send_template_len, send_data, send_data_len, send_info,
             status_ret);
  xmit_status_ret := send_info.xmit;
  deadline := time_$clockh + timeout;

  { the wait }
  if status_ret.all = status_$ok then
    repeat
      wait_val := wait_val + 1;
      case ec_$wait(sock_ec, ec_$eventcount_ptr_t(addr(time_$clockh)),
                    addr(fim_$quit_ec[proc1_$as_id]), wait_val,
                    deadline, quit_val) of
        0: begin
             msg_$$rcv_internal(sock_num, rcv_dest_net, rcv_dest_node,
                                rcv_dest_sock, rcv_src_net, rcv_src_node,
                                rcv_src_sock, hw_addr, rcv_msg_type,
                                rcv_template, rcv_template_max,
                                rcv_template_len_ret, rcv_data,
                                rcv_data_max, rcv_data_len_ret, ec_param1,
                                ec_param2, status_ret);
             if (status_ret.all = status_$ok)
                and then (rcv_msg_type = request_id) then
               exit;
           end;
        1: begin
             status_ret.all := status_$network_remote_node_failed_to_respond;
             exit;
           end;
        2: begin
             status_ret.all := fault_$quit;
             fim_$quit_value[proc1_$as_id] :=
               fim_$quit_ec[proc1_$as_id].value;
             exit;
           end;
      end;
    until false;

  sock_$close(sock_num);
end;
