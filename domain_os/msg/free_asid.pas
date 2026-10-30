{ MSG_$FREE_ASID - close an address space's share of every socket.

  Image addresses:
    sau2  0x00E74E2C  MSG_$FREE_ASID
    sau9  0x3C47C9C4  MSG_$FREE_ASID

  - MSG_$CLOSEI for every socket the address space owns, its status not
    looked at.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure msg_$free_asid(in asid: integer);
var
  status: status_$t;
  sock: integer;
  i: integer;
begin
  for i := 1 to msg_max_socket do
    with msg_$ownership[i] do
      if asid in owners then begin
        sock := i;
        msg_$closei(sock, status);
      end;
end;
