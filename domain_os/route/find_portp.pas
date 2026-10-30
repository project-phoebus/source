{ ROUTE_$FIND_PORTP - the open port of a type and socket.

  Image addresses:
    sau2  0x00E15B46  ROUTE_$FIND_PORTP

  - ROUTE_$FIND_PORT's walk, giving the port's address, or nil.

  Status stored: none.
}

function route_$find_portp(network: integer; socket: integer32): route_$port_ptr_t;
var
  i: integer;
  port: route_$port_ptr_t;
begin
  for i := 0 to 7 do begin
    port := route_$portp[i];
    if (port^.active <> 0)
       and then (network = port^.port_type)
       and then (port^.socket = socket) then begin
      route_$find_portp := port;
      return;
    end;
  end;

  route_$find_portp := nil;
end;
