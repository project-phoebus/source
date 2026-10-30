{ ring_8025_read_stats - add the adapter's error counters to a unit's
  statistics and return them.

  Image addresses:
    sau9  0x3C486F80  ring_8025_read_stats

  - Under the unit's transmit lock: the read error log command, awaited
    for 5 ticks; its counters are added to the unit's.
  - On success the unit's statistics are copied to buf^ and len is
    102.

  Status stored:
    ring_8025_wait_scb's status: the command completed or the time ran
      out
}

procedure ring_8025_read_stats(var unit: pinteger;
                               var buf: ring_8025_$stats_ptr_t;
                               out len: integer; out status: status_$t);
  internal;
var
  copy: ring_8025_$stats_t;
  u: ring_8025_$unit_ptr_t;
  st: status_$t;
begin
  u := addr(ring8025_ucb[unit]);
  ml_$exclusion_start(u^.xmit_lock);
  ring_8025_scb_cmd(u, r8025_cmd_read_error_log,
                    addr(ring8025_$aux_da.ctl[u^.cnum].error_log), 14);
  ring_8025_wait_scb(u, 5, st);
  if st.all = status_$ok then begin
    with u^, ring8025_$aux_da.ctl[u^.cnum].error_log do begin
      stats.line_errors := stats.line_errors + line_errors;
      stats.internal_errors := stats.internal_errors + internal_errors;
      stats.burst_errors := stats.burst_errors + burst_errors;
      stats.ac_errors := stats.ac_errors + ac_errors;
      stats.abort_delimiters := stats.abort_delimiters + abort_delimiters;
      stats.lost_frames := stats.lost_frames + lost_frames;
      stats.rcv_congestion := stats.rcv_congestion + rcv_congestion;
      stats.frame_copied_errors :=
        stats.frame_copied_errors + frame_copied_errors;
      stats.frequency_errors := stats.frequency_errors + frequency_errors;
      stats.token_errors := stats.token_errors + token_errors;
      stats.reserved_0b := stats.reserved_0b + reserved_0b;
      stats.dma_bus_errors := stats.dma_bus_errors + dma_bus_errors;
      stats.dma_parity_errors := stats.dma_parity_errors + dma_parity_errors;
    end;
    copy := u^.stats;
  end;
  ml_$exclusion_stop(u^.xmit_lock);
  if st.all = status_$ok then begin
    buf^ := copy;
    len := 102;
  end;
  status := st;
end;
