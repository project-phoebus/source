{ NET_IO_$INIT - bring up the primary network port.

  Image addresses:
    sau2  0x00E31C98  NET_IO_$INIT

  - An active port 0's driver start entry is called (a bad status
    crashes the system) and the port marked active as 2.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure net_io_$init;
var
  status: status_$t;
  port: route_$port_ptr_t;
  driver: net_io_$driver_ptr_t;
begin
  port := route_$portp[0];
  if port^.active <> 0 then begin
    driver := net_io_$driver_ptr_t(port^.driver_info);
    if driver^.start <> nil then
      driver^.start^(port^.socket, status);
    if status.all <> status_$ok then
      crash_system(status);
    port^.active := 2;
  end;
end;
