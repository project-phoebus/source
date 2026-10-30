{ MSG_$SAR - send a request and wait for its reply, with MSG's template
  (the short SVC form).

  Image addresses:
    sau2  0x00E59D52  MSG_$SAR

  - MSG_$SARI with MSG's 30-byte packet info template (the caller's
    flags on top), routing key -1 and a local address record, whose
    protocol family is handed back.

  Status stored:
    msg_$sari's status: always
}

procedure msg_$sar(in timeout: integer;
                   in dest_node: linteger;
                   in dest_sock: pinteger;
                   in flags: msg_$info_flags_t;
                   in send_template: univ pkt_$bytes_t;
                   in send_template_len: pinteger;
                   in send_data: univ pkt_$bytes_t;
                   in send_data_len: pinteger;
                   out xmit_status_ret: msg_$xmit_flags_t;
                   out proto_family_ret: pinteger;
                   out rcv_template: univ pkt_$bytes_t;
                   in rcv_template_max: pinteger;
                   out rcv_template_len_ret: pinteger;
                   out rcv_data: univ pkt_$bytes_t;
                   in rcv_data_max: pinteger;
                   out rcv_data_len_ret: pinteger;
                   out status_ret: status_$t);
var
  unused_2: integer;                      { stand-in }
  hw_addr: msg_$hw_addr_t;
  unused_22: integer;                     { stand-in }
  info: msg_$template_t;
begin
  info := msg_$send_template;
  info.flags := flags;
  msg_$sari(timeout, -1, dest_node, dest_sock, info, send_template,
            send_template_len, send_data, send_data_len, xmit_status_ret,
            hw_addr, rcv_template, rcv_template_max, rcv_template_len_ret,
            rcv_data, rcv_data_max, rcv_data_len_ret, status_ret);
  proto_family_ret := hw_addr.proto_family;
end;
