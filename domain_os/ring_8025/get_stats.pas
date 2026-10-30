{ RING_8025_$GET_STATS - return a unit's statistics.

  Image addresses:
    sau9  0x3C487582  RING_8025_$GET_STATS

  - The driver record's get_stats entry: for a unit that takes Domain
    packets, the adapter's counters are added in and the 102-byte block
    copied to stats_buf (ring_8025_read_stats).  A failure there counts
    as a command that did not complete.

  Status stored:
    status_$r8025_invalid_unit_num: socket is not unit 0 or 1
    status_$r8025_device_offline: the unit does not take Domain packets
    status_$r8025_invalid_stats_block: max_len is less than 102
    ring_8025_read_stats's status: otherwise
}

procedure ring_8025_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                               max_len: integer; out length_ret: integer;
                               out status_ret: status_$t);
  options(val_param);
var
  buf: ring_8025_$stats_ptr_t;
  u: ring_8025_$unit_ptr_t;
begin
  if socket > r8025_max_unit then begin
    status_ret.all := status_$r8025_invalid_unit_num;
    return;
  end;
  u := addr(ring8025_ucb[socket]);
  if not (r8025_unit_domain in u^.flags) then begin
    status_ret.all := status_$r8025_device_offline;
    return;
  end;
  if max_len < 102 then begin
    status_ret.all := status_$r8025_invalid_stats_block;
    return;
  end;
  buf := stats_buf;
  ring_8025_read_stats(socket, buf, length_ret, status_ret);
  if status_ret.all <> status_$ok then
    with u^ do
      stats.cmd_failures := stats.cmd_failures + 1;
end;
