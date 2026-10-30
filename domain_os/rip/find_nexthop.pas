{ RIP_$FIND_NEXTHOP - the next hop and port towards a destination.

  Image addresses:
    sau2  0x00E15696  RIP_$FIND_NEXTHOP

  - A destination on network 0, or on a network of one of this node's
    routing ports, is direct: the next hop is the destination, the port
    that port, hop count 0.
  - Otherwise, holding the table's exclusion record, the network's route
    of the asked-for routing (valid or aging, under 16 hops) gives the
    port, the hop count and the next hop.  The result is the hop count.

  Status stored:
    status_$ok: a next hop was found
    rip_$status_no_route: no usable route ("network unreachable")
}

{ TODO(pascal) 8 frame bytes of RIP_$FIND_NEXTHOP hold nothing

  Nothing addresses the frame; the slots of i, entry and route and the
  word result take 14 of its 24 bytes with i's rounding
  A destination network and a state local,
  which the image keeps in no register of its own (the network is read
  through its pointer each time), would take 4 + 2 bytes and leave 2.
  The stand-ins unused_10 and unused_14, two longwords, hold the 8 (dpc
  --dump-locals then gives the image's frame): the bytes do not start
  at a multiple of 8 from A6, where an object of 8 bytes or more is
  placed, so the original's objects there were smaller. }

function rip_$find_nexthop(in addr_info: univ rip_$dest_addr_t;
                           flags: boolean;
                           out port_ret: integer;
                           out nexthop: rip_$nexthop_t;
                           out status_ret: status_$t): integer;
var
  i: integer;
  entry: rip_$entry_ptr_t;
  route: rip_$route_ptr_t;
  unused_10: integer32;                   { stand-ins, see the TODO }
  unused_14: integer32;
begin
  rip_$find_nexthop := 0;
  port_ret := 0;
  nexthop := rip_$nexthop_ptr_t(addr(addr_info))^;
  status_ret.all := status_$ok;

  if addr_info.network = 0 then begin
    rip_$stats.local_net_pkts := rip_$stats.local_net_pkts + 1;
    return;
  end;

  for i := 0 to 7 do
    if (route_$port[i].active in [2..5])
       and then (route_$port[i].network = addr_info.network) then begin
      rip_$stats.local_net_pkts := rip_$stats.local_net_pkts + 1;
      port_ret := i;
      return;
    end;

  ml_$exclusion_start(rip_$exclusion);
  entry := rip_$entry_ptr_t(rip_$net_lookup(addr_info.network, true,
                                            false));
  if entry = nil then
    status_ret.all := rip_$status_no_route
  else begin
    if flags then
      route := addr(entry^.routes[1])
    else
      route := addr(entry^.routes[0]);
    if (route^.metric >= 16)
       or else ((route^.flags.state <> rip_state_valid)
                and then (route^.flags.state <> rip_state_aging)) then
      status_ret.all := rip_$status_no_route
    else begin
      port_ret := route^.port;
      rip_$find_nexthop := route^.metric;
      if route^.metric <> 0 then
        nexthop := route^.nexthop;
    end;
  end;
  ml_$exclusion_stop(rip_$exclusion);
end;
