{ MSG_$ALLOCATE - allocate a user socket (the two-argument SVC form).

  Image addresses:
    sau2  0x00E592CA  MSG_$ALLOCATE

  - MSG_$ALLOCATEI with a status of its own; the result is whether it is
    status_$ok.

  Status stored: none.
}

function msg_$allocate(out socket: pinteger; in depth: integer): boolean;
var
  status: status_$t;
begin
  msg_$allocatei(socket, depth, status);
  msg_$allocate := status.all = status_$ok;
end;
