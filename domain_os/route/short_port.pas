{ ROUTE_$SHORT_PORT - the 12-byte summary of a routing port.

  Image addresses:
    sau2  0x00E69C08  ROUTE_$SHORT_PORT

  - The port's network, its active and type words, its socket and its
    queue length.

  Status stored: none.
}

procedure route_$short_port(in port: route_$port_t;
                            out short_info: route_$short_port_t);
begin
  short_info.network := port.network;
  short_info.status := port.active;
  short_info.port_type := port.port_type;
  short_info.socket := port.socket;
  short_info.queue_length := port.part_34.queue_length;
end;
