{ MSG_$TEST_FOR_MESSAGE - whether a socket has a message queued.

  Image addresses:
    sau2  0x00E59FB2  MSG_$TEST_FOR_MESSAGE

  - The socket eventcount's value is handed back; the result is whether
    its queue is not empty.
  - After a failed check the result is not assigned.

  Status stored:
    status_$ok: the caller owns the socket
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

function msg_$test_for_message(in socket: integer; out ec_value: integer32;
                               out status_ret: status_$t): boolean;
var
  sock: sock_$sock_ptr_t;
begin
  if (socket <= 0) or else (socket > msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;
  if not (proc1_$as_id in msg_$ownership[socket].owners) then begin
    status_ret.all := status_$msg_no_owner;
    return;
  end;

  sock := sock_$socket_ptr[socket];
  ec_value := sock^.ec.value;
  status_ret.all := status_$ok;
  msg_$test_for_message := sock^.queue_count <> 0;
end;
