{ RIP_$TABLE_D - read or write one route of a routing table entry.

  Image addresses:
    sau2  0x00E68E2C  RIP_$TABLE_D

  - The index is masked to the table's 64 entries in place.  Reading
    gives the entry's network and the route's next hop, expiration, hop
    count, state, and its port's type and socket.
  - Writing builds the entry in a local, the route's port the one of the
    given type and socket, and stores it in the table.

  Status stored:
    status_$ok: the route was read or written
    status_$internet_unknown_network_port: no port of that type and
      socket
}

procedure rip_$table_d(in op_flag: boolean; in route_type: boolean;
                       in out index: integer;
                       var buffer: rip_$table_d_buf_t;
                       out status_ret: status_$t);
var
  route: rip_$route_ptr_t;
  entry: rip_$entry_t;
  port: route_$port_ptr_t;
begin
  status_ret.all := status_$ok;

  if op_flag then begin
    index := index & 16#3F;
    entry := rip_$info[index];
    buffer.dest_network := entry.network;
    if route_type then
      route := addr(entry.routes[1])
    else
      route := addr(entry.routes[0]);
    buffer.nexthop := route^.nexthop;
    buffer.expiration := route^.expiration;
    buffer.metric := route^.metric;
    buffer.state := route^.flags.state;
    if route^.port <= 7 then begin
      port := route_$portp[route^.port];
      buffer.port_type := port^.port_type;
      buffer.port_socket := port^.socket;
    end
    else begin
      buffer.port_type := route_$port_type_local;
      buffer.port_socket := 0;
    end;
  end
  else begin
    if route_type then begin
      if index >= 64 then
        entry.routes[0].flags.state := rip_state_unused;
      route := addr(entry.routes[1]);
    end
    else begin
      if index >= 64 then
        entry.routes[1].flags.state := rip_state_unused;
      route := addr(entry.routes[0]);
    end;

    route^.port := route_$find_port(buffer.port_type, buffer.port_socket);
    if route^.port = 16#FF then
      status_ret.all := status_$internet_unknown_network_port
    else begin
      entry.network := buffer.dest_network;
      route^.nexthop := buffer.nexthop;
      route^.expiration := buffer.expiration;
      route^.metric := buffer.metric;
      route^.flags.state := buffer.state;
      index := index & 16#3F;
      rip_$info[index] := entry;
    end;
  end;
end;
