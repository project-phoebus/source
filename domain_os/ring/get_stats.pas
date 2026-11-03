{ RING_$GET_STATS - copy out a unit's statistics.

  Image addresses:
    sau2  0x00E76950  RING_$GET_STATS
    sau3  0x00E78140  RING_$GET_STATS
    sau8  0x03C83236  RING_$GET_STATS

  Status stored:
    status_$ok: unit 0 or 1, initialized: its 60-byte statistics record
      was copied
    status_$internet_unknown_network_port: any other (length 0)
}

procedure ring_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                          max_len: integer; out length_ret: integer;
                          out status_ret: status_$t);
  options(val_param);
begin
  if (socket <= 1) and then ring_$ctl[socket].initialized then begin
    ring_$stats_ptr_t(stats_buf)^ := ring_$data[socket];
    length_ret := 60;
    status_ret.all := 0;
  end
  else begin
    length_ret := 0;
    status_ret.all := status_$internet_unknown_network_port;
  end;
end;
