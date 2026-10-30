{ MSG_$RCV_HW - receive a message, with the header page's two
  eventcount words.

  Image addresses:
    sau2  0x00E59950  MSG_$RCV_HW

  - MSG_$RCVI's checks and receive, the two words passed back; the
    address record's protocol family is handed back on every path.

  Status stored:
    msg_$$rcv_internal's status: the socket is good
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

procedure msg_$rcv_hw(in socket: integer;
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
                      out ec_param1_ret: integer;
                      out ec_param2_ret: pinteger;
                      out status_ret: status_$t);
var
  unused_30: array[1..48] of char;        { stand-in }
  unused_32: integer;                     { stand-in }
  hw_addr: msg_$hw_addr_t;
  unused_54: integer32;                   { stand-in }
  src_net: integer32;
  dest_node: linteger;
  dest_net: integer32;
  dest_sock: pinteger;
begin
  if (socket <= 0) or else (socket > msg_max_socket) then
    status_ret.all := status_$msg_socket_out_of_range
  else if not (proc1_$as_id in msg_$ownership[socket].owners) then
    status_ret.all := status_$msg_no_owner
  else
    msg_$$rcv_internal(socket, dest_net, dest_node, dest_sock, src_net,
                       src_node, src_sock, hw_addr, msg_type, template,
                       template_max, template_len_ret, data, data_max,
                       data_len_ret, ec_param1_ret, ec_param2_ret,
                       status_ret);

  proto_family_ret := hw_addr.proto_family;
end;
