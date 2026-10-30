{ MSG_$INIT - set up MSG at boot: the bounce page, the socket lock and
  the reserved sockets' owner.

  Image addresses:
    sau2  0x00E31B84  MSG_$INIT

  - A data page is taken and mapped as the bounce page (a failure
    crashes the system), msg_$sock_lock initialized, and address space
    58 made the owner of sockets 1, 2, 4, 5 and 6.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure msg_$init;
var
  status: status_$t;
begin
  { the bounce page }
  netbuf_$get_dat(dpage_pa);
  netbuf_$getva(dpage_pa, dpage_va, status);
  if status.all <> status_$ok then
    crash_system(status);

  ml_$exclusion_init(msg_$sock_lock);
  msg_$ownership[1].owners := [58];
  msg_$ownership[2].owners := [58];
  msg_$ownership[4].owners := [58];
  msg_$ownership[5].owners := [58];
  msg_$ownership[6].owners := [58];
end;
