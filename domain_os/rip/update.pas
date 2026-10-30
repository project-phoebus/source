{ RIP_$UPDATE - take a route through a port named by its index into the
  routing table, as the Domain internet's.

  Image addresses:
    sau2  0x00E690EE  RIP_$UPDATE

  - The source is the port's network and the given host's 20-bit node;
    RIP_$UPDATE_INT takes the route with the Domain internet's routing.
  - The source's host word and the node's top 12 bits are not written.

  Status stored:
    rip_$update_int's status: in either case
}

procedure rip_$update(in network: integer32; in host_id: linteger;
                      in hop_count: pinteger; in port_index: integer;
                      out status_ret: status_$t);
var
  source: rip_$nexthop_t;
  status: status_$t;
begin
  source.network := route_$port[port_index].network;
  source.host_bits.host_node := host_id;

  rip_$update_int(network, source, hop_count, port_index, false, status);
  status_ret := status;
end;
