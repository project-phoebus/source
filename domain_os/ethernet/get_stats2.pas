{ ETHERNET_$GET_STATS2 - return a unit's statistics, the second form.

  Image addresses:
    sau8  0x03C86B4A  ETHERNET_$GET_STATS2
    sau9  0x3C48274A  ETHERNET_$GET_STATS2

  - The driver record's get_stats2 entry: ETHERNET_$GET_STATS for a unit
    that is on line, whether or not it takes Domain packets; the length
    is 0 when nothing was copied.

  Status stored:
    status_$eth_invalid_unit_num: socket is not unit 0 or 1
    status_$eth_device_offline: the unit is not on line
    status_$eth_invalid_stats_block: max_len is less than 42
    ethernet_read_stats's status: otherwise
}

procedure ethernet_$get_stats2(var socket: univ pinteger; stats_buf: univ_ptr;
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
  if not (eth_unit_online in u^.flags) then begin
    status_ret.all := status_$eth_device_offline;
    return;
  end;
  if max_len < 42 then begin
    length_ret := 0;
    status_ret.all := status_$eth_invalid_stats_block;
    return;
  end;
  buf := stats_buf;
  ethernet_read_stats(socket, buf, length_ret, status_ret);
  if status_ret.all <> status_$ok then begin
    length_ret := 0;
    with u^ do
      stats.counts[7] := stats.counts[7] + 1;
  end;
end;
