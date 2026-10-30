{ ETHERNET_$INT_DEFERRED - a unit's receive work at the end of its
  interrupt.

  Image addresses:
    sau9  0x3C48450C  ETHERNET_$INT_DEFERRED

  - The routine ETHERNET_$INTERRUPT queues (DI_$ENQ) with the unit.  A
    packet the adapter announced is read (its receive command, then its
    bytes); a packet in the pages is learnt from and handed on; new
    pages are taken; and the next receive command goes out.  None of it
    waits: what needs a lock that is held, or the process level, is left
    in the receive state for the receive process.
  - The result is the eventcount to advance, the receive process's when
    it has work, else nil.
  - A failed step counts in the seventh statistic; a call with nothing
    to do counts in idle_defers.

  Status stored: none.
}

function ethernet_$int_deferred(u: ethernet_$unit_ptr_t):
  ec_$eventcount_ptr_t;
  options(val_param);
var
  pcb: ethernet_$pcb_t;
  st: status_$t;
begin
  { a packet the adapter announced: read it }
  if eth_unit_rcv_ready in u^.flags then begin
    if u^.rcv_state <> eth_rcv_idle then begin
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    u^.flags := u^.flags - [eth_unit_rcv_ready];
    pcb.cmd := eth_cmd_x17;
    pcb.len := 0;
    if ml_$cond_exclusion_start(u^.cmd_lock) then begin
      u^.rcv_state := eth_rcv_read;
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    if ethernet_send_pcb(u, addr(pcb), st) then
      ethernet_rcv_packet(u, (u^.rcv_len + 1) & ~1, u^.rcv_tag, st);
    ml_$cond_exclusion_stop(u^.cmd_lock);
    if st.all = status_$ok then
      u^.rcv_state := eth_rcv_got
    else
      u^.stats.counts[7] := u^.stats.counts[7] + 1;
  end
  else if u^.rcv_state <> eth_rcv_got then
    u^.idle_defers := u^.idle_defers + 1;

  { a packet in the pages: learn from it, hand it on, new pages }
  if u^.rcv_state = eth_rcv_got then begin
    if ml_$exclusion_check(u^.cmd_lock) then begin
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    if not ethernet_arp_input_cond(u, u^.hdr_va) then begin
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    if not ethernet_demux_int(u) then begin
      u^.rcv_state := eth_rcv_demux;
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    if not ethernet_get_rcv_bufs_cond(u) then begin
      u^.rcv_state := eth_rcv_bufs;
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end;
    u^.rcv_state := eth_rcv_idle;
  end;

  { the next receive command }
  if not (eth_unit_rcv_pending in u^.flags) then
    if not ethernet_start_rcv_cond(u, st) then begin
      if st.all <> status_$ok then
        u^.stats.counts[7] := u^.stats.counts[7] + 1;
      ethernet_$int_deferred := addr(u^.rcv_wake_ec);
      return;
    end
    else if st.all <> status_$ok then
      u^.stats.counts[7] := u^.stats.counts[7] + 1;
  ethernet_$int_deferred := nil;
end;
