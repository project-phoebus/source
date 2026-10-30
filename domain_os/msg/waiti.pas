{ MSG_$WAITI - wait for a message on a socket, a timeout or a quit.

  Image addresses:
    sau2  0x00E59BC0  MSG_$WAITI

  - A socket with a message queued returns at once; otherwise it waits
    on the socket, the clock (the caller's ticks) and the quit
    eventcount.

  Status stored:
    status_$ok: a message is queued, or came
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
    status_$msg_time_out: the timeout
    status_$msg_quit_fault: a quit (noted as seen)
}

procedure msg_$waiti(in socket: integer; in timeout: pinteger;
                     out status_ret: status_$t);
var
  quit_val: integer32;
  sock_val: integer32;
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
  sock_val := sock^.ec.value + 1;
  quit_val := fim_$quit_value[proc1_$as_id] + 1;

  if sock^.queue_count <> 0 then
    status_ret.all := status_$ok
  else
    case ec_$wait(addr(sock^.ec), ec_$eventcount_ptr_t(addr(time_$clockh)),
                  addr(fim_$quit_ec[proc1_$as_id]), sock_val,
                  time_$clockh + timeout, quit_val) of
      0: begin
        status_ret.all := status_$ok;
      end;
      1: begin
        status_ret.all := status_$msg_time_out;
      end;
      2: begin
           fim_$quit_value[proc1_$as_id] :=
             fim_$quit_ec[proc1_$as_id].value;
           status_ret.all := status_$msg_quit_fault;
         end;
    end;
end;
