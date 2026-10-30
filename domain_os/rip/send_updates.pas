{ RIP_$SEND_UPDATES - broadcast the routing table if a route changed.

  Image addresses:
    sau2  0x00E6887A  RIP_$SEND_UPDATES

  - For the standard routing (is_std) or the Domain internet, with more
    than one routing port of that kind and a changed route, the change
    flag is cleared and RIP_$BROADCAST sends the table.

  Status stored: none.
}

procedure rip_$send_updates(is_std: boolean);
begin
  if is_std then begin
    if (route_$std_n_routing_ports > 1)
       and then rip_$std_recent_changes then begin
      rip_$std_recent_changes := false;
      rip_$broadcast(true);
    end;
  end
  else
    if (route_$n_routing_ports > 1) and then rip_$recent_changes then begin
      rip_$recent_changes := false;
      rip_$broadcast(false);
    end;
end;
