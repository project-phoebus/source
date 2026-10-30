{ MSG_$SEND - send a message to a socket of a node with MSG's template.

  Image addresses:
    sau2  0x00E599FC  MSG_$SEND

  - MSG_$$SEND with MSG's 30-byte template (the caller's flags on top),
    from this node, through the port the header builder chooses; the
    transmit status word is handed back.

  Status stored:
    msg_$$send's status: always
}

procedure msg_$send(dest_node: linteger;
                    dest_sock: pinteger;
                    src_sock: pinteger;
                    info_flags: msg_$info_flags_t;
                    request_id: pinteger;
                    in template: univ pkt_$bytes_t;
                    template_len: pinteger;
                    in data: univ pkt_$bytes_t;
                    data_len: pinteger;
                    out xmit_status: msg_$xmit_flags_t;
                    out status_ret: status_$t);
var
  info: msg_$template_t;
  send_info: msg_$send_info_t;
begin
  info := msg_$send_template;
  info.flags := info_flags;
  msg_$$send(-1, 0, dest_node, dest_sock, 0, node_$me, src_sock, info,
             request_id, template, template_len, data, data_len,
             send_info, status_ret);
  xmit_status := send_info.xmit;
end;
