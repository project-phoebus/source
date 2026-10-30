{ NET_IO_$CLEANUP_NIL - close a local port its address space created.

  Image addresses:
    sau2  0x00E74EC8  NET_IO_$CLEANUP_NIL

  - NET_IO_$NIL_DRIVER's proc2_cleanup entry: a local port the dying
    address space created (its socket word the port's number) is closed
    through ROUTE_$SERVICE.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure net_io_$cleanup_nil(var socket: pinteger; asid: integer);
  options(val_param);
var
  short_port: route_$short_port_t;
  status: status_$t;
begin
  if net_io_$port_asid[socket] = asid then begin
    route_$short_port(route_$portp[socket]^, short_port);
    route_$service([3], short_port, status);
  end;
end;
