{ RIP_$UPDATE_INT - take a route to a network into the routing table.

  Image addresses:
    sau2  0x00E15922  RIP_$UPDATE_INT
    sau2  0x00E15830  rip_$compare_source (nested)
    sau2  0x00E15888  rip_$apply_update (nested)

  - For network 0 nothing is done; the hop count is held to at most 17.
  - Under the RIP lock, for network -1 every route of the routing from
    the same source is updated; another network's entry is looked up or
    created, its route updated from its source, or a shorter one.
  - A valid direct route updated to 16 or more hops ages instead; any
    other update makes the route valid with the source, port and count.

  Status stored:
    status_$ok: the route was taken, or nothing was to be done
    status_$network_too_many_networks_in_internet: no entry free
}

{ TODO(pascal) 6 frame bytes of RIP_$UPDATE_INT hold nothing

  metric is in the frame; with the slots of the register-held i,
  entry and route and their roundings that is 16 of the frame's 24
  bytes, and nothing else addresses the frame.  A state byte and a
  boolean (2 + 2 bytes) would leave 2.  The stand-in unused_16 holds the
  6 (dpc --dump-locals then gives metric's place and the frame's size). }

procedure rip_$update_int(network: integer32;
                          in source: univ rip_$nexthop_t;
                          hop_count: pinteger;
                          port_index: integer;
                          flags: boolean;
                          out status_ret: status_$t);
var
  i: integer;
  entry: integer32;
  metric: integer;
  route: rip_$route_ptr_t;
  unused_16: array[1..3] of integer;      { stand-in, see the TODO }

  function rip_$compare_source(in route_hop: rip_$nexthop_t;
                               in source: rip_$nexthop_t;
                               flags: boolean): boolean;
  begin
    rip_$compare_source := false;
    if flags then begin
      if (route_hop.host[0] = source.host[0])
         and then (route_hop.host[1] = source.host[1])
         and then (route_hop.host[2] = source.host[2]) then
        rip_$compare_source := true;
    end
    else if route_hop.host_bits.host_node
            = source.host_bits.host_node then
      rip_$compare_source := true;
  end;

  procedure rip_$apply_update(var route: rip_$route_t);
  begin
    if route.metric <> metric then
      if flags then
        rip_$std_recent_changes := true
      else
        rip_$recent_changes := true;

    if (route.metric = 0)
       and then (route.flags.state = rip_state_valid)
       and then (metric >= 16) then begin
      route.flags.state := rip_state_aging;
      route.expiration := time_$clockh + rip_aging_timeout;
    end
    else begin
      route.nexthop := source;
      route.port := port_index;
      route.metric := metric;
      route.flags.state := rip_state_valid;
      route.expiration := time_$clockh + rip_route_timeout;
    end;
  end;

begin
  status_ret.all := status_$ok;
  if network = 0 then
    return;
  if hop_count > rip_infinity then
    hop_count := rip_infinity;
  metric := hop_count;
  rip_$lock;

  if network = -1 then begin
    for i := 0 to 63 do begin
      if flags then
        route := addr(rip_$info[i].routes[1])
      else
        route := addr(rip_$info[i].routes[0]);
      if rip_$compare_source(route^.nexthop, source, flags)
         and then (route^.flags.state <> rip_state_unused) then
        rip_$apply_update(route^);
    end;
  end
  else begin
    entry := rip_$net_lookup(network, false, true);
    if entry = 0 then
      status_ret.all := status_$network_too_many_networks_in_internet
    else begin
      if flags then
        route := addr(rip_$entry_ptr_t(entry)^.routes[1])
      else
        route := addr(rip_$entry_ptr_t(entry)^.routes[0]);
      if rip_$compare_source(route^.nexthop, source, flags)
         or else (route^.metric > metric)
         or else ((route^.flags.state <> rip_state_valid)
                  and then (metric <= 16)) then
        rip_$apply_update(route^);
    end;
  end;

  rip_$unlock;
end;
