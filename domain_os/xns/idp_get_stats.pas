{ XNS_IDP_$GET_STATS - the IDP counters.

  Image addresses:
    sau2  0x00E18FD6  XNS_IDP_$GET_STATS

  - The packets sent, received and dropped.

  Status stored:
    status_$ok: always
}

procedure xns_idp_$get_stats(out stats: xns_$idp_stats_t;
                             out status: status_$t);
begin
  stats.packets_sent := xns_idp_$packets_sent;
  stats.packets_received := xns_idp_$packets_received;
  stats.packets_dropped := xns_idp_$packets_dropped;
  status.all := status_$ok;
end;
