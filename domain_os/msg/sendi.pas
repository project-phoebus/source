{ MSG_$SENDI - send a message with the caller's addresses and template.

  Image addresses:
    sau2  0x00E59AA6  MSG_$SENDI

  - MSG_$$SEND through the port the header builder chooses, every
    argument the caller's; the transmit status word is handed back.

  Status stored:
    msg_$$send's status: always
}

procedure msg_$sendi(in routing_key: integer32;
                     in dest_node: linteger;
                     in dest_sock: pinteger;
                     in src_node_or: integer32;
                     in src_node: linteger;
                     in src_sock: pinteger;
                     in pkt_info: msg_$template_t;
                     in request_id: pinteger;
                     in template: univ pkt_$bytes_t;
                     in template_len: pinteger;
                     in data: univ pkt_$bytes_t;
                     in data_len: pinteger;
                     out xmit_status: msg_$xmit_flags_t;
                     out status_ret: status_$t);
var
  send_info: msg_$send_info_t;
begin
  msg_$$send(-1, routing_key, dest_node, dest_sock, src_node_or, src_node,
             src_sock, pkt_info, request_id, template, template_len, data,
             data_len, send_info, status_ret);
  xmit_status := send_info.xmit;
end;
