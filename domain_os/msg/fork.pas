{ MSG_$FORK - give a new address space its parent's share of every
  socket.

  Image addresses:
    sau2  0x00E73F00  MSG_$FORK

  - Under msg_$sock_lock every socket the parent owns gets the child as
    an owner too; the result is whether there was one.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
function msg_$fork(in parent_asid: integer; in child_asid: integer): boolean;
var
  shared: boolean;
  i: integer;                             { not formed }
begin
  shared := false;
  ml_$exclusion_start(msg_$sock_lock);

  for i := 1 to msg_max_socket do
    with msg_$ownership[i] do
      if parent_asid in owners then begin
        shared := true;
        owners := owners + [child_asid];
      end;

  ml_$exclusion_stop(msg_$sock_lock);
  msg_$fork := shared;
end;
