{ PKT_$INIT - start the ping server.

  Image addresses:
    sau2  0x00E2F84C  PKT_$INIT

  - The ping server process is created; a failure crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure pkt_$init;
var
  status: status_$t;
begin
  discard(proc1_$create_p(addr(pkt_$ping_server), 16#0800000F, status));
  if status.all <> status_$ok then
    crash_system(status);
end;
