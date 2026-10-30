{ MSG_$GET_EC - a level-2 eventcount for a socket's messages.

  Image addresses:
    sau2  0x00E59CDA  MSG_$GET_EC

  - EC2_$REGISTER_EC1 registers the socket's eventcount; its handle is
    handed back.

  Status stored:
    ec2_$register_ec1's status: the socket is good
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

procedure msg_$get_ec(in socket: integer; out ec: ec2_$ptr_t;
                      out status_ret: status_$t);
begin
  if (socket <= 0) or else (socket > msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;
  if not (proc1_$as_id in msg_$ownership[socket].owners) then begin
    status_ret.all := status_$msg_no_owner;
    return;
  end;

  ec := ec2_$register_ec1(addr(sock_$socket_ptr[socket]^.ec), status_ret);
end;
