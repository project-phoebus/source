{ NET_IO_$CLEANUP_USER - close a user port its address space created.

  Image addresses:
    sau2  0x00E74F1E  NET_IO_$CLEANUP_USER

  - NET_IO_$USER_DRIVER's proc2_cleanup entry: a user port (type 2) the
    dying address space created is closed through ROUTE_$SERVICE.
  - net_io_$port_asid is indexed with the SOCK socket number.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure net_io_$cleanup_user(var socket: pinteger; asid: integer);
  options(val_param);
var
  short_port: route_$short_port_t;
  port: route_$port_ptr_t;
  status: status_$t;
begin
  if net_io_$port_asid[socket] = asid then begin
    port := route_$find_portp(route_$port_type_routing, socket);
    route_$short_port(port^, short_port);
    route_$service([3], short_port, status);
  end;
end;
