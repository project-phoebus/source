{ ROUTE_$SHUTDOWN - close or take down every open routing port.

  Image addresses:
    sau2  0x00E6A5DC  ROUTE_$SHUTDOWN

  - A user or local port (type 2 or 1) is closed through ROUTE_$SERVICE;
    any other gets a new status, 2 for port 0 and 1 for the others.
    ROUTE_$SERVICE's statuses are ignored.

  Status stored: none.
}

procedure route_$shutdown;
var
  short_info: route_$short_port_t;
  status: status_$t;
  i: integer;
begin
  for i := 0 to 7 do
    if route_$port[i].active <> 0 then begin
      route_$short_port(route_$port[i], short_info);
      if (route_$port[i].port_type = route_$port_type_routing)
         or else (route_$port[i].port_type = route_$port_type_local) then
        route_$service([service_op_close_port], short_info, status)
      else begin
        if i = 0 then
          short_info.status := 2
        else
          short_info.status := 1;
        route_$service([service_op_set_status], short_info, status);
      end;
    end;
end;
