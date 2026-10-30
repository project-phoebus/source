{ NET_$RCV - receive on a network connection.

  Image addresses:
    sau2  0x00E5A2CC  NET_$RCV

  - The driver's svc_read entry for the network and port does the work.

  Status stored:
    net_$find_handler's status: no driver entry
    the driver's status: otherwise
}

procedure net_$rcv(in net_id: integer; var port: integer;
                   var param3: univ net_$opaque_t; in param4: integer;
                   var param5: univ net_$opaque_t; var param6: univ net_$opaque_t;
                   in param7: integer; var param8: univ net_$opaque_t;
                   out status: status_$t);
var
  handler: net_$xfer_proc_t;
begin
  handler := net_$find_handler(net_id, port,
                               integer32(addr(net_io_$nil_driver.svc_read))
                               - integer32(addr(net_io_$nil_driver)), status);

  if status.all = status_$ok then
    handler^(port, param3, param4, param5, param6, param7, param8, status);
end;
