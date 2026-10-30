{ ROUTE_$READ_USER_STATS - a user routing port's statistics.

  Image addresses:
    sau2  0x00E6A65E  ROUTE_$READ_USER_STATS

  - The port's in-use byte, its two counters and as many queue-depth
    buckets as its queue length plus one go to the caller's buffer;
    length_ret is the length copied (0 for an unknown port).  The third
    argument, NET_IO's maximum, is never read.

  Status stored:
    status_$ok: the statistics were copied
    status_$internet_unknown_network_port: no user port (type 2) of the
      socket
}

procedure route_$read_user_stats(var socket: univ pinteger;
                                 stats_buf: univ_ptr;
                                 max_len: integer;
                                 out length_ret: integer;
                                 out status_ret: status_$t);
var
  index: integer;
  port: route_$port_ptr_t;
  stats: route_$user_stat_ptr_t;
  buf: route_$user_stat_ptr_t;
  i: integer;
begin
  index := route_$find_port(route_$port_type_routing, socket);
  if index = -1 then begin
    length_ret := 0;
    status_ret.all := status_$internet_unknown_network_port;
    return;
  end;

  port := addr(route_$port[index]);
  buf := stats_buf;
  stats := port^.part_34.driver_stats;
  buf^.in_use := stats^.in_use;
  buf^.counts := stats^.counts;

  for i := 0 to port^.part_34.queue_length do
    buf^.queue_depth[i] := stats^.queue_depth[i];

  length_ret := integer32(addr(buf^.queue_depth[port^.part_34.queue_len
                                                + 1]))
                - integer32(buf);
  status_ret.all := status_$ok;
end;
