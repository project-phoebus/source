{ MSG_$RCV - receive a message (the short SVC form).

  Image addresses:
    sau2  0x00E594F4  MSG_$RCV

  - MSG_$RCVI with locals for the results the short form does not
    return; the address record's protocol family is handed back.

  Status stored:
    msg_$rcvi's status: always
}

procedure msg_$rcv(in socket: integer;
                   out src_node: linteger;
                   out src_sock: pinteger;
                   out proto_family_ret: pinteger;
                   out msg_type: pinteger;
                   out template: univ pkt_$bytes_t;
                   in template_max: pinteger;
                   out template_len_ret: pinteger;
                   out data: univ pkt_$bytes_t;
                   in data_max: pinteger;
                   out data_len_ret: pinteger;
                   out status_ret: status_$t);
var
  unused_2: integer;                      { stand-in }
  hw_addr: msg_$hw_addr_t;
  src_net: integer32;
  dest_node: linteger;
  dest_net: integer32;
  dest_sock: pinteger;
begin
  msg_$rcvi(socket, dest_net, dest_node, dest_sock, src_net, src_node,
            src_sock, hw_addr, msg_type, template, template_max,
            template_len_ret, data, data_max, data_len_ret, status_ret);
  proto_family_ret := hw_addr.proto_family;
end;
