{ ETHERNET_$GET_STATS - return a unit's statistics.

  Image addresses:
    sau6  0x78088C10  ETHERNET_$GET_STATS
    sau7  0x3C4932CA  ETHERNET_$GET_STATS
    sau8  0x03C86AC6  ETHERNET_$GET_STATS
    sau9  0x3C4826C6  ETHERNET_$GET_STATS

  - The driver record's get_stats entry: for a unit that takes Domain
    packets, the adapter's counts are added in and the statistics block
    copied to stats_buf (ethernet_read_stats).  A failure there counts in
    the unit's eth_stat_errors count.

  Status stored:
    status_$eth_invalid_unit_num: socket is not unit 0 or 1
    status_$eth_device_offline: the unit does not take Domain packets
    status_$eth_invalid_stats_block: max_len is less than
      eth_stats_len (42, with `ethernet_vme' 50)
    ethernet_read_stats's status: otherwise
}

procedure ethernet_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                              max_len: integer; out length_ret: integer;
                              out status_ret: status_$t);
  options(val_param);
var
  buf: ethernet_$stats_ptr_t;
  u: ethernet_$unit_ptr_t;
begin
  if socket > eth_max_unit then begin
    status_ret.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[socket]);
  if not (eth_unit_domain in u^.flags) then begin
    status_ret.all := status_$eth_device_offline;
    return;
  end;
  if max_len < eth_stats_len then begin
    status_ret.all := status_$eth_invalid_stats_block;
    return;
  end;
  buf := stats_buf;
  ethernet_read_stats(socket, buf, length_ret, status_ret);
  if status_ret.all <> status_$ok then
    with u^ do
      stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
end;
