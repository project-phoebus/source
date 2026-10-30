{ MSG_$CLOSE - close a socket (the one-argument SVC form).

  Image addresses:
    sau2  0x00E593D2  MSG_$CLOSE

  - MSG_$CLOSEI with a status of its own, never looked at.

  Status stored: none.
}

procedure msg_$close(in socket: integer);
var
  status: status_$t;
begin
  msg_$closei(socket, status);
end;
