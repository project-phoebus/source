{ MSG_$RCV_CONTIG - receive a message into one buffer (the short SVC
  form).

  Image addresses:
    sau2  0x00E59756  MSG_$RCV_CONTIG

  - MSG_$RCV_CONTIGI into the buffer the caller's pointer points at,
    with locals for the results the short form does not return.

  Status stored:
    msg_$rcv_contigi's status: always
}

procedure msg_$rcv_contig(in socket: integer;
                          out src_node: linteger;
                          out src_sock: pinteger;
                          out proto_family_ret: pinteger;
                          out msg_type: pinteger;
                          data_buf: pkt_$bytes_ptr_t;
                          in max_len: pinteger;
                          out data_len: pinteger;
                          out status_ret: status_$t);
var
  hw_addr: msg_$hw_addr_t;
  src_net: integer32;
  dest_node: linteger;
  dest_net: integer32;
  dest_sock: pinteger;
begin
  msg_$rcv_contigi(socket, dest_net, dest_node, dest_sock, src_net,
                   src_node, src_sock, hw_addr, msg_type, data_buf^,
                   max_len, data_len, status_ret);
  proto_family_ret := hw_addr.proto_family;
end;
