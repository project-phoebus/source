{ NET_$OPEN - open a network connection.

  Image addresses:
    sau2  0x00E5A1A4  NET_$OPEN

  - The driver's svc_open entry for the network and port does the work;
    a successful open registers the process cleanup handler 10.

  Status stored:
    net_$find_handler's status: no driver entry
    the driver's status: otherwise
}

procedure net_$open(in net_id: integer; var port: integer;
                    var param3: univ net_$opaque_t; in param4: integer;
                    var param5: univ net_$opaque_t; out status: status_$t);
var
  handler: net_$ctl_proc_t;
begin
  handler := net_$find_handler(net_id, port,
                               integer32(addr(net_io_$nil_driver.svc_open))
                               - integer32(addr(net_io_$nil_driver)), status);

  if status.all = status_$ok then begin
    handler^(port, param3, param4, param5, status);
    if status.all = status_$ok then
      proc2_$set_cleanup(10);
  end;
end;
