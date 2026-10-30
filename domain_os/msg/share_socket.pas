{ MSG_$SHARE_SOCKET - add a process's address space to a socket's
  owners, or take it away.

  Image addresses:
    sau2  0x00E5A02C  MSG_$SHARE_SOCKET

  - Under msg_$sock_lock (taken before the checks), PROC2_$GET_ASID finds
    the process's address space; add_remove 0 takes it out of the
    owners, any other value adds it.

  Status stored:
    proc2_$get_asid's status: the caller owns the socket
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

procedure msg_$share_socket(in socket: integer; in proc_uid: uid_$t;
                            in add_remove: integer;
                            out status_ret: status_$t);
var
  asid: integer;
begin
  ml_$exclusion_start(msg_$sock_lock);

  if (socket <= 0) or else (socket > msg_max_socket) then
    status_ret.all := status_$msg_socket_out_of_range
  else if not (proc1_$as_id in msg_$ownership[socket].owners) then
    status_ret.all := status_$msg_no_owner
  else begin
    asid := proc2_$get_asid(proc_uid, status_ret);
    if status_ret.all = status_$ok then
      if add_remove = 0 then
        msg_$ownership[socket].owners :=
          msg_$ownership[socket].owners - [asid]
      else
        msg_$ownership[socket].owners :=
          [asid] + msg_$ownership[socket].owners;
  end;

  ml_$exclusion_stop(msg_$sock_lock);
end;
