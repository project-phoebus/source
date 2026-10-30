{ MSG_$OPENI - open a socket by number.

  Image addresses:
    sau2  0x00E591B4  MSG_$OPENI

  - Under msg_$sock_lock the caller's address space becomes the
    socket's one owner, the depth is noted, the cleanup bit (7) set, the
    routing service added and user sockets marked open.
  - Socket 224 is refused.

  Status stored:
    status_$ok: the socket was opened
    status_$msg_socket_out_of_range: a socket outside 1..223
    status_$msg_too_deep: a depth over 32
    status_$msg_socket_in_use: an address space owns it, or SOCK_$OPEN
      refuses it
}

procedure msg_$openi(in socket: integer; in depth: integer;
                     out status_ret: status_$t);
var
  value: network_$service_t;
  net_status: status_$t;
begin
  if (socket <= 0) or else (socket >= msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;
  if depth > msg_max_depth then begin
    status_ret.all := status_$msg_too_deep;
    return;
  end;

  ml_$exclusion_start(msg_$sock_lock);
  with msg_$ownership[socket] do begin
    if (owners <> [])
       or else not sock_$open(socket, depth, depth, depth, 16#400) then begin
      status_ret.all := status_$msg_socket_in_use;
      ml_$exclusion_stop(msg_$sock_lock);
      return;
    end;
    owners := [proc1_$as_id];
  end;

  msg_$depth[socket] := depth;
  msg_$open_count := msg_$open_count + 1;
  proc2_$set_cleanup(7);
  value.service := [network_service_routing];
  value.remote_pool := 0;
  network_$set_service(network_op_or_bits, value, net_status);
  network_$user_sock_open := true;
  ml_$exclusion_stop(msg_$sock_lock);
  status_ret.all := status_$ok;
end;
