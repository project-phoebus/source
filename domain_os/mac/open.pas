{ MAC_$OPEN - open a MAC channel on a port.

  Image addresses:
    sau2  0x00E0B8BE  MAC_$OPEN

  - A user socket is allocated and MAC_OS_$OPEN opens the channel with
    the caller's packet-type ranges and MAC_$DEMUX as the callback (the
    socket closed again on a failure).
  - The channel gets the socket and the promiscuous flag, and the
    socket's eventcount is registered at level 2.  The results (the EC2
    handle, the MTU, the channel) overwrite the caller's first ranges.

  Status stored:
    status_$ok: the channel was opened
    status_$mac_invalid_port: a port outside 0..7
    status_$internet_network_port_not_open: the routing port is not open
    status_$mac_invalid_packet_type_count: not 1..10 ranges
    status_$mac_invalid_packet_type: a range's low end above its high
    status_$mac_no_socket_allocated: a socket count of 0
    status_$mac_no_os_sockets_available: no user socket
    mac_os_$open's or ec2_$register_ec1's status: those failed
}

procedure mac_$open(in port_num: integer;
                    in out params: mac_$open_params_t;
                    out status: status_$t);
var
  port: integer;
  os_params: mac_os_$open_params_t;
  os_status: status_$t;
  num_types: integer;
  sock_num: pinteger;                     { passed by address, then held }
  i: integer;
  channel_num: pinteger;
  sock_ptr: sock_$sock_ptr_t;
begin
  { the port }
  status.all := status_$ok;
  port := port_num;
  if (port < 0) or else (port > mac_max_port) then begin
    status.all := status_$mac_invalid_port;
    return;
  end;
  if route_$port[port].active in [0, 1] then begin
    status.all := status_$internet_network_port_not_open;
    return;
  end;

  { the packet-type ranges }
  num_types := params.num_packet_types;
  if (num_types < 1) or else (num_types > mac_max_packet_types) then begin
    status.all := status_$mac_invalid_packet_type_count;
    return;
  end;
  for i := 0 to num_types - 1 do
    with params.packet_types[i] do
      if range_low > range_high then begin
        status.all := status_$mac_invalid_packet_type;
        return;
      end;

  { the socket }
  if params.socket_count = 0 then begin
    status.all := status_$mac_no_socket_allocated;
    return;
  end;
  if not sock_$allocate_user(sock_num, params.socket_count,
                             params.socket_count, params.socket_count,
                             mac_socket_max_data_len) then begin
    status.all := status_$mac_no_os_sockets_available;
    return;
  end;
  sock_ptr := sock_$socket_ptr[sock_num];
  sock_ptr^.flags.open := false;

  { MAC_OS's channel }
  os_params.callback := addr(mac_$demux);
  os_params.num_pkt_types := params.num_packet_types;
  for i := 0 to num_types - 1 do
    os_params.pkt_types[i] := params.packet_types[i];
  mac_os_$open(port_num, os_params, os_status);
  status := os_status;
  if os_status.all <> status_$ok then begin
    sock_$close(sock_num);
    return;
  end;

  channel_num := os_params.channel;
  proc2_$set_cleanup(mac_cleanup_handler_bit);
  ml_$exclusion_start(mac_os_$exclusion);
  mac_os_$channel_table[channel_num].socket := sock_num;
  mac_os_$channel_table[channel_num].bits.promiscuous := params.flags;
  ml_$exclusion_stop(mac_os_$exclusion);

  { the results }
  sock_ptr := sock_$socket_ptr[sock_num];
  params.ec2_handle := ec2_$register_ec1(addr(sock_ptr^.ec), status);
  params.mtu := os_params.mtu;
  params.channel_num := channel_num;
end;
