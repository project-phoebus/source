{ net_$find_handler - a network port's driver entry point.

  Image addresses:
    sau2  0x00E5A128  net_$find_handler (module-local)

  - handler_off is the entry's offset in the port's driver record; the
    result is nil on both errors.

  Status stored:
    status_$ok: the entry was found
    status_$internet_unknown_network_port: ROUTE_$FIND_PORTP knows no
      such port
    status_$network_operation_not_defined_on_hardware: the driver has no
      such entry
}

function net_$find_handler(net_id: integer; port: pinteger;
                           handler_off: pinteger;
                           out status: status_$t): univ_ptr;
  internal;
type
  net_$entry_ptr_t = ^univ_ptr;
var
  slot: integer32;
  p: route_$port_ptr_t;
begin
  p := route_$find_portp(net_id, port);

  if p = nil then begin
    status.all := status_$internet_unknown_network_port;
    net_$find_handler := nil;
  end
  else begin
    slot := handler_off + p^.driver_info;
    if net_$entry_ptr_t(slot)^ = nil then begin
      status.all := status_$network_operation_not_defined_on_hardware;
      net_$find_handler := nil;
    end
    else begin
      status.all := status_$ok;
      net_$find_handler := net_$entry_ptr_t(slot)^;
    end;
  end;
end;
