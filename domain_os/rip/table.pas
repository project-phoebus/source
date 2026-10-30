{ RIP_$TABLE - read or write one standard-routing route of the table in
  the compact form.

  Image addresses:
    sau2  0x00E68F90  RIP_$TABLE

  - Reading gives the Domain internet's route from RIP_$TABLE_D: the
    network, the next hop's 20-bit node, the expiration, the port's
    index, the hop count and the state.
  - Writing, for a port index up to 7, has RIP_$TABLE_D write the route;
    a larger port index is ignored.

  Status stored: none.
}

procedure rip_$table(in op_flag: boolean; var index: integer;
                     var buffer: rip_$table_buf_t);
var
  d_buf: rip_$table_d_buf_t;
  status: status_$t;
  port: route_$port_ptr_t;
begin
  if op_flag then begin
    rip_$table_d(op_flag, false, index, d_buf, status);
    buffer.dest_network := d_buf.dest_network;
    buffer.nexthop_host_low := d_buf.nexthop.host_bits.host_node;
    buffer.expiration := d_buf.expiration;
    buffer.port_index := route_$find_port(d_buf.port_type,
                                          d_buf.port_socket);
    buffer.metric := d_buf.metric;
    buffer.flags.state := d_buf.state;
  end
  else if buffer.port_index <= 7 then begin
    d_buf.expiration := buffer.expiration;
    d_buf.dest_network := buffer.dest_network;
    d_buf.nexthop.host_bits.host_node := buffer.nexthop_host_low;
    d_buf.metric := buffer.metric;
    d_buf.state := buffer.flags.state;
    port := addr(route_$port[buffer.port_index]);
    d_buf.nexthop.network := port^.network;
    d_buf.port_type := port^.port_type;
    d_buf.port_socket := port^.socket;
    rip_$table_d(op_flag, false, index, d_buf, status);
  end;
end;
