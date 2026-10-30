{ RIP_$ANNOUNCE_NS - announce this node as a name server.

  Image addresses:
    sau2  0x00E6914E  RIP_$ANNOUNCE_NS

  - Port 0's network and this node are registered with the name service,
    and RIP's 2-byte name-server announcement is broadcast on the RIP
    socket to every node of the network.

  Status stored: none.
}

procedure rip_$announce_ns;
var
  status: status_$t;
  timeout: pinteger;
  retry_hint: integer;
  pkt_id: pinteger;
begin
  rem_name_$register_server(route_$port[0].network, node_$me);

  pkt_id := pkt_$next_id;

  pkt_$send_internet(0, 16#FFFFF, rip_socket, route_$port[0].network,
                     node_$me, -1, rip_$bcast_control, pkt_id,
                     rip_$ns_announcement, 2, 0, 0, retry_hint, timeout,
                     status);
end;
