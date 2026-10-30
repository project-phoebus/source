{ MSG_$SET_HPIPC - check that the calling address space owns a socket.

  Image addresses:
    sau2  0x00E59140  MSG_$SET_HPIPC

  - The second argument is not read.

  Status stored:
    status_$ok: the caller owns the socket
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

procedure msg_$set_hpipc(in socket: integer; var param2: integer32;
                         out status_ret: status_$t);
begin
  if (socket <= 0) or else (socket > msg_max_socket) then
    status_ret.all := status_$msg_socket_out_of_range
  else if not (proc1_$as_id in msg_$ownership[socket].owners) then
    status_ret.all := status_$msg_no_owner
  else
    status_ret.all := status_$ok;
end;
