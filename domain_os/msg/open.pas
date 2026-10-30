{ MSG_$OPEN - open a socket by number (the two-argument SVC form).

  Image addresses:
    sau2  0x00E59198  MSG_$OPEN

  - MSG_$OPENI with a status of its own; the result is whether it is
    status_$ok.

  Status stored: none.
}

function msg_$open(in socket: integer; in depth: integer): boolean;
var
  status: status_$t;
begin
  msg_$openi(socket, depth, status);
  msg_$open := status.all = status_$ok;
end;
