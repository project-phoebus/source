{ MSG_$ALLOCATEI - allocate a user socket.

  Image addresses:
    sau2  0x00E592E6  MSG_$ALLOCATEI

  - Under msg_$sock_lock, SOCK_$ALLOCATE_USER gives a socket of the
    depth; the caller's address space becomes its one owner, and as in
    MSG_$OPENI the cleanup bit (7) is set and the routing service added.

  Status stored:
    status_$ok: a socket was allocated
    status_$msg_too_deep: a depth over 32
    status_$msg_no_more_sockets: none was free
}

procedure msg_$allocatei(out socket: pinteger; in depth: integer;
                         out status_ret: status_$t);
var
  net_status: status_$t;
  value: network_$service_t;
begin
  if depth > msg_max_depth then begin
    status_ret.all := status_$msg_too_deep;
    return;
  end;

  ml_$exclusion_start(msg_$sock_lock);
  if sock_$allocate_user(socket, depth, depth, depth, 16#400) then begin
    msg_$ownership[socket].owners := [proc1_$as_id];
    msg_$depth[socket] := depth;
    msg_$open_count := msg_$open_count + 1;
    proc2_$set_cleanup(7);
    value.service := [network_service_routing];
    value.remote_pool := 0;
    network_$set_service(network_op_or_bits, value, net_status);
    network_$user_sock_open := true;
    ml_$exclusion_stop(msg_$sock_lock);
    status_ret.all := status_$ok;
  end
  else begin
    ml_$exclusion_stop(msg_$sock_lock);
    status_ret.all := status_$msg_no_more_sockets;
  end;
end;
