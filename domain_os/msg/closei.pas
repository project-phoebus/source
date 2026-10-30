{ MSG_$CLOSEI - give up the calling address space's share of a socket.

  Image addresses:
    sau2  0x00E593E4  MSG_$CLOSEI
    sau9  0x3C460780  MSG_$CLOSEI

  - Under msg_$sock_lock the address space leaves the owners; with none
    left the socket is closed, and with no socket open the routing
    service is taken away again.

  Status stored:
    status_$ok: the share was given up
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the address space does not own it
}

procedure msg_$closei(in socket: integer; out status_ret: status_$t);
var
  net_status: status_$t;
  value: network_$service_t;
begin
  if (socket <= 0) or else (socket > msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;

  ml_$exclusion_start(msg_$sock_lock);
  if not (proc1_$as_id in msg_$ownership[socket].owners) then begin
    status_ret.all := status_$msg_no_owner;
    ml_$exclusion_stop(msg_$sock_lock);
    return;
  end;

  msg_$ownership[socket].owners :=
    msg_$ownership[socket].owners - [proc1_$as_id];
  if msg_$ownership[socket].owners = [] then begin
    msg_$open_count := msg_$open_count - 1;
    sock_$close(socket);
    if msg_$open_count = 0 then begin
      network_$user_sock_open := false;
      value.service := [network_service_routing];
      value.remote_pool := 0;
      network_$set_service(network_op_and_not_bits, value, net_status);
    end;
  end;

  ml_$exclusion_stop(msg_$sock_lock);
  status_ret.all := status_$ok;
end;
