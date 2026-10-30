{ NET_IO_$FREE_ASID - tell every open port's driver that an address
  space is going away.

  Image addresses:
    sau2  0x00E74E84  NET_IO_$FREE_ASID

  - Each of the eight active ports' driver proc2_cleanup entry, when it
    has one, with the port's socket and the address space.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure net_io_$free_asid(asid: integer);
  options(val_param);
var
  i: integer;
  port: route_$port_ptr_t;
  driver: net_io_$driver_ptr_t;
begin
  for i := 0 to 7 do begin
    port := route_$portp[i];
    if port^.active <> 0 then begin
      driver := net_io_$driver_ptr_t(port^.driver_info);
      if driver^.proc2_cleanup <> nil then
        driver^.proc2_cleanup^(port^.socket, asid);
    end;
  end;
end;
