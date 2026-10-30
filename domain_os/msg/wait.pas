{ MSG_$WAIT - wait for a message on a socket (the two-argument SVC
  form).

  Image addresses:
    sau2  0x00E59BA4  MSG_$WAIT

  - MSG_$WAITI with a status of its own; the result is whether it is
    status_$ok.

  Status stored: none.
}

function msg_$wait(in socket: integer; in timeout: pinteger): boolean;
var
  status: status_$t;
begin
  msg_$waiti(socket, timeout, status);
  msg_$wait := status.all = status_$ok;
end;
