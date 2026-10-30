{ MSG_$SEND_HW - send a message through the port of a given network and
  socket.

  Image addresses:
    sau2  0x00E59B14  MSG_$SEND_HW

  - ROUTE_$FIND_PORT finds the port the address record's proto_subtype
    and reserved1 give; MSG_$$SEND sends through it.

  Status stored:
    msg_$$send's status: a port was found
    status_$internet_unknown_network_port: none was
}

procedure msg_$send_hw(in hw_addr: msg_$hw_addr_t;
                       in routing_key: integer32;
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
                       out send_info: msg_$send_info_t;
                       out status_ret: status_$t);
var
  port: integer;
begin
  port := route_$find_port(hw_addr.proto_subtype, hw_addr.reserved1);
  if port = -1 then
    status_ret.all := status_$internet_unknown_network_port
  else
    msg_$$send(port, routing_key, dest_node, dest_sock, src_node_or,
               src_node, src_sock, pkt_info, request_id, template,
               template_len, data, data_len, send_info, status_ret);
end;
