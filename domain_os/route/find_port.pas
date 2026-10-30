{ ROUTE_$FIND_PORT - the index of the open port of a type and socket.

  Image addresses:
    sau2  0x00E15AF8  ROUTE_$FIND_PORT

  - The first of the eight ports that is open (its active word not 0)
    with the type and socket asked for; -1 for none.

  Status stored: none.
}

function route_$find_port(port_type: integer; socket: integer32): integer;
var
  i: integer;
  port: route_$port_ptr_t;
begin
  for i := 0 to 7 do begin
    port := route_$portp[i];
    if (port^.active <> 0)
       and then (port_type = port^.port_type)
       and then (port^.socket = socket) then begin
      route_$find_port := i;
      return;
    end;
  end;

  route_$find_port := -1;
end;
