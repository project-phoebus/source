{ RIP_$UPDATE_D - take a route through a port named by its type and
  socket into the routing table.

  Image addresses:
    sau2  0x00E69084  RIP_$UPDATE_D

  - The port is the one of the summary's type and socket (the word at +6
    its type); RIP_$UPDATE_INT takes the route through its index.

  Status stored:
    rip_$update_int's status: the port was found
    status_$internet_unknown_network_port: no such port
}

procedure rip_$update_d(in network: integer32;
                        in source: univ rip_$dest_addr_t;
                        in hop_count: integer;
                        in port_info: route_$short_port_t;
                        in flags: boolean;
                        out status_ret: status_$t);
var
  status: status_$t;
  port_index: integer;
begin
  port_index := route_$find_port(port_info.port_type, port_info.socket);
  if port_index = -1 then
    status.all := status_$internet_unknown_network_port
  else
    rip_$update_int(network, source, hop_count, port_index, flags, status);

  status_ret := status;
end;
