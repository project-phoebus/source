{ MSG_$RCVI - receive a message.

  Image addresses:
    sau2  0x00E596B2  MSG_$RCVI

  - msg_$$rcv_internal into the caller's results, with locals for the
    two eventcount words.

  Status stored:
    msg_$$rcv_internal's status: the socket is good
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

{ TODO(pascal) 52 frame bytes of MSG_$RCVI no object explains

  The two eventcount words at the bottom are the only bytes of the SAU2
  frame addressed; the 52 above them hold the stand-ins unused_30 (48
  bytes, at a multiple of 8 from A6) and unused_34 (a longword): one
  52-byte object would be placed at a multiple of 8 and lengthen the
  frame.
  MSG_$SARI (msg/sari.pas) has 52 unaddressed bytes at the top of its
  frame too, and MSG_$RCV_HW (msg/rcv_hw.pas) 48 above its address
  record and 4 below it: the three callers of msg_$$rcv_internal.  No
  locals but the two words are known. }

procedure msg_$rcvi(in socket: integer;
                    out dest_net: integer32;
                    out dest_node: linteger;
                    out dest_sock: pinteger;
                    out src_net: integer32;
                    out src_node: linteger;
                    out src_sock: pinteger;
                    out hw_addr: msg_$hw_addr_t;
                    out msg_type: pinteger;
                    out template: univ pkt_$bytes_t;
                    in template_max: pinteger;
                    out template_len_ret: pinteger;
                    out data: univ pkt_$bytes_t;
                    in data_max: pinteger;
                    out data_len_ret: pinteger;
                    out status_ret: status_$t);
var
  unused_30: array[1..48] of char;        { stand-in }
  unused_34: integer32;
  ec_param2: pinteger;
  ec_param1: integer;
begin
  if (socket <= 0) or else (socket > msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;
  if not (proc1_$as_id in msg_$ownership[socket].owners) then begin
    status_ret.all := status_$msg_no_owner;
    return;
  end;

  msg_$$rcv_internal(socket, dest_net, dest_node, dest_sock, src_net,
                     src_node, src_sock, hw_addr, msg_type, template,
                     template_max, template_len_ret, data, data_max,
                     data_len_ret, ec_param1, ec_param2, status_ret);
end;
