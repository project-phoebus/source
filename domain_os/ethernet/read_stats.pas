{ ethernet_read_stats - add the adapter's network statistics to a unit's
  counts and return them.

  Image addresses:
    sau6  0x7808867E  ethernet_read_stats
    sau7  0x3C492ACE  ethernet_read_stats
    sau8  0x03C862CA  ethernet_read_stats
    sau9  0x3C481ECA  ethernet_read_stats

  - Under the unit's command lock: the network statistics command, then
    its reply.  The reply's counts (low byte first) are added to the
    unit's first six counts; without the downloaded program the first
    count's high word is not the adapter's and is dropped.
  - On success the unit's statistics (version 1) are copied to stats^
    and len is 42.
  - With `ethernet_vme': the controller is asked for its eight counts,
    which the interrupt routine adds to the unit's as the reply comes;
    len is 50.

  Status stored:
    ethernet_start_cmd's status: the command did not go out
    ethernet_wait_cmd's status: its reply
}

%if ethernet_vme %then
procedure ethernet_read_stats(var unit: pinteger;
                              var stats: ethernet_$stats_ptr_t;
                              out len: integer; out status: status_$t);
  internal;
var
  u: ethernet_$unit_ptr_t;
begin
  u := addr(ether_ucb[unit]);
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_read_stats;
    param_3 := 3;
    value_3 := 0;
    stats_count := 8;
    unused_12 := 0;
    stats_bus := u^.ctl_stats_bus;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all = status_$ok then begin
    stats^ := u^.stats;
    len := eth_stats_len;
  end;
end;
%else
{ TODO(pascal) the stand-in locals of ethernet_read_stats

  The routine's frame has 8 bytes below st that no instruction
  addresses.  unused_7c stands for whatever the original declared
  there (`with' records, perhaps). }

procedure ethernet_read_stats(var unit: pinteger;
                              var stats: ethernet_$stats_ptr_t;
                              out len: integer; out status: status_$t);
  internal;
var
  copy: ethernet_$stats_t;
  pcb: ethernet_$pcb_t;
  u: ethernet_$unit_ptr_t;
  st: status_$t;
  unused_7c: array[1..2] of integer32;    { stand-ins, see the TODO }
begin
  u := addr(ether_ucb[unit]);
  pcb.cmd := eth_cmd_network_statistics;
  pcb.len := 0;
  ml_$exclusion_start(u^.cmd_lock);
  ethernet_start_cmd(u, addr(pcb),
                     eth_cmd_network_statistics + eth_cmd_reply, st);
  if st.all = status_$ok then begin
    ethernet_wait_cmd(u, st);
    if st.all = status_$ok then begin
      with u^.stats do begin
        version := 1;
        if not (eth_unit_program in u^.flags) then
          pcb.words[2] := 0;
        counts[1] := counts[1] + ethernet_swap32(pcb.longs[1]);
        counts[2] := counts[2] + ethernet_swap32(pcb.longs[2]);
        counts[3] := counts[3] +
          ((lshft(pinteger(pcb.words[5]), 8) ! rshft(pinteger(pcb.words[5]), 8))
           & 16#FFFF);
        counts[4] := counts[4] +
          ((lshft(pinteger(pcb.words[6]), 8) ! rshft(pinteger(pcb.words[6]), 8))
           & 16#FFFF);
        counts[5] := counts[5] +
          ((lshft(pinteger(pcb.words[7]), 8) ! rshft(pinteger(pcb.words[7]), 8))
           & 16#FFFF);
        counts[6] := counts[6] +
          ((lshft(pinteger(pcb.words[8]), 8) ! rshft(pinteger(pcb.words[8]), 8))
           & 16#FFFF);
      end;
      copy := u^.stats;
    end;
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if st.all = status_$ok then begin
    stats^ := copy;
    len := 42;
  end;
  status := st;
end;
%endif
