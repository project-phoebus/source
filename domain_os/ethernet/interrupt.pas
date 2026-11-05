{ ETHERNET_$INTERRUPT - a unit's interrupt routine.

  Image addresses:
    sau6  0x7808AC7C  ETHERNET_$INTERRUPT
    sau7  0x3C495252  ETHERNET_$INTERRUPT
    sau8  0x03C88A4E  ETHERNET_$INTERRUPT
    sau9  0x3C48464E  ETHERNET_$INTERRUPT

  - The routine IO_$ACQUIRE registers with the unit's DCTE.  A byte in
    the adapter's command register names the block it sends, which is
    read after it: the downloaded program's notice of a received packet
    (its length, then the deferred work queued); the reply to the
    receive command (the packet read, then the deferred work queued); the
    reply a command waits for (copied to the waiter's block and the
    waiter woken); the program's replies to its two commands.
  - The command register's interrupt is off while it works (not with
    `ethernet_int_unmasked').
  - No byte in the command register counts in the eth_stat_unexpected count, as
    does an unknown block; a failed read in eth_stat_errors (the receive
    process woken), a transmit reply of the program in eth_stat_xmit_failed.
  - With `ethernet_vme': the routine SYSBUS_$DEFINE_INT defines for the
    unit.  The command slots the controller is done with become the
    host's again; then the next reply slot, if the controller has filled
    it: a received packet (its length kept, then the deferred work
    queued; a failed receive wakes the receive process), a transmit's
    end (its buffer and data page freed, a waiting sender woken), or the
    reply a command waits for (the waiter woken; a statistics reply's
    counts added to the unit's).  The slot is then handed back.  A reply
    that failed, one that is none of these, a failed transmit and a
    transmit or receive with no buffer out count in the statistics.
  - The result is true: the interrupt was the unit's.

  Status stored: none.
}

function ethernet_$interrupt(dcte: integer32): boolean;
  options(val_param);
%if ethernet_vme %then
var
  u: ethernet_$unit_ptr_t;
  cring: ethernet_$vme_ring_ptr_t;
  rring: ethernet_$vme_ring_ptr_t;
  i: integer;
  j: integer;
  k: pinteger;
  s: integer;
  cs: ethernet_$vme_stats_ptr_t;
begin
  u := addr(ether_ucb[dcte_ptr_t(dcte)^.cnum]);
  cring := u^.cmd_ring;
  rring := u^.reply_ring;
  repeat
    i := u^.cmd_done + 1;
    if i > eth_vme_ring_slots then
      i := 1;
    if eth_vme_slot_busy in cring^.slots[i].owner then
      exit;
    cring^.slots[i].owner := [eth_vme_slot_busy];
    u^.cmd_done := i;
  until i = u^.cmd_idx;
  j := u^.reply_idx + 1;
  if j > eth_vme_ring_slots then
    j := 1;
  with rring^.slots[j] do
    if not (eth_vme_slot_ctlr in owner) then
      if (eth_vme_slot_busy in owner) or else
          (eth_vme_slot_error in owner) then begin
        if eth_vme_slot_error in owner then
          u^.stats.counts[eth_stat_errors] :=
            u^.stats.counts[eth_stat_errors] + 1
        else
          u^.stats.counts[eth_stat_unexpected] :=
            u^.stats.counts[eth_stat_unexpected] + 1;
      end
      else begin
        k := u^.rcv_done;
        if u^.rcv_busy[k] and then (request = eth_vme_cmd_receive) then begin
          u^.flags := u^.flags - [eth_unit_rcv_pending];
          if result = 0 then begin
            u^.flags := u^.flags + [eth_unit_rcv_ready];
            u^.rcv_len[k] := data_len - 4;
            u^.rcv_done := (u^.rcv_done mod 2) + 1;
            di_$enq(addr(ethernet_$int_deferred), u, u^.di_elem);
          end
          else begin
            u^.stats.counts[eth_stat_errors] :=
              u^.stats.counts[eth_stat_errors] + 1;
            u^.rcv_done := (k mod 2) + 1;
            ec_$advance_without_dispatch(u^.rcv_wake_ec);
          end;
        end
        else if (eth_unit_xmit_busy in u^.flags) and then
                (request = eth_vme_cmd_transmit) then begin
          s := result & 16#F7;
          if (s <> 2) and then (s <> 0) and then (s <> 1) then
            u^.stats.counts[eth_stat_xmit_failed] :=
              u^.stats.counts[eth_stat_xmit_failed] + 1;
          if u^.xmit_busy[u^.xmit_done] then begin
            if u^.xmit_dat[u^.xmit_done] <> 0 then
              netbuf_$rtn_dat(u^.xmit_dat[u^.xmit_done]);
            u^.xmit_busy[u^.xmit_done] := false;
            u^.xmit_done := (u^.xmit_done mod 2) + 1;
          end
          else
            u^.stats.counts[eth_stat_errors] :=
              u^.stats.counts[eth_stat_errors] + 1;
          if not u^.xmit_busy[u^.xmit_done] then
            u^.flags := u^.flags - [eth_unit_xmit_busy];
          if eth_unit_xmit_wait in u^.flags then
            ec_$advance_without_dispatch(u^.xmit_wait_ec);
        end
        else if (eth_unit_cmd_pending in u^.flags) and then
                (request = u^.reply_cmd) and then (id = u^.reply_id) then begin
          u^.reply_status := result;
          u^.flags := u^.flags - [eth_unit_cmd_pending];
          ec_$advance_without_dispatch(u^.reply_ec);
          if u^.reply_cmd = eth_vme_cmd_read_stats then begin
            cs := u^.ctl_stats;
            with u^.stats do begin
              counts[1] := counts[1] + cs^[1];
              counts[2] := counts[2] + cs^[2];
              counts[3] := counts[3] + cs^[3];
              counts[5] := counts[5] + cs^[5];
              counts[6] := counts[6] + cs^[6];
              counts[7] := counts[7] + cs^[7];
              counts[8] := counts[8] + cs^[8];
            end;
          end;
        end
        else
          u^.stats.counts[eth_stat_unexpected] :=
            u^.stats.counts[eth_stat_unexpected] + 1;
        len := 58;
        owner := [eth_vme_slot_ctlr, eth_vme_slot_busy];
        u^.reply_idx := j;
      end;
  ethernet_$interrupt := true;
end;
%else
var
  pcb: ethernet_$pcb_t;
  st: status_$t;
  len: integer;
  u: ethernet_$unit_ptr_t;
  regs: ethernet_$regs_ptr_t;
  cmd: integer;
begin
  u := addr(ether_ucb[dcte_ptr_t(dcte)^.cnum]);
  regs := u^.regs;
  if not (eth_asr_acrf in regs^.status) then begin
    with u^ do
      stats.counts[eth_stat_unexpected] :=
        stats.counts[eth_stat_unexpected] + 1;
    ethernet_$interrupt := true;
    return;
  end;
%if not ethernet_int_unmasked %then
  with regs^ do begin
    control := control ! eth_hcr_tcen;
    control := control & ~eth_hcr_cmde;
  end;
%endif
  cmd := regs^.command;

  { the program's notice: a packet waits, its length in the block }
  if cmd = eth_cmd_x16 + eth_cmd_reply then begin
    if ethernet_get_pcb(u, addr(pcb), 2, st) then begin
      with u^ do begin
        rcv_len := lshft(pinteger(pcb.words[1]), 8)
                   ! rshft(pinteger(pcb.words[1]), 8);
        rcv_tag := rcv_len;
        flags := flags + [eth_unit_rcv_ready];
      end;
      di_$enq(addr(ethernet_$int_deferred), u, u^.di_elem);
    end
    else begin
      with u^ do
        stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
      ec_$advance_without_dispatch(u^.rcv_wake_ec);
    end;
  end

  { the receive command's reply: the packet }
  else if (eth_unit_rcv_pending in u^.flags)
          and then (cmd = eth_cmd_receive_packet + eth_cmd_reply) then begin
    u^.flags := u^.flags - [eth_unit_rcv_pending];
    if ethernet_get_pcb(u, addr(pcb), 2, st)
       and then (pcb.words[5] = 0) then begin
      len := ((lshft(pinteger(pcb.words[3]), 8)
               ! rshft(pinteger(pcb.words[3]), 8)) + 1) & ~1;
      ethernet_rcv_packet(u, len,
                          lshft(pinteger(pcb.words[4]), 8)
                          ! rshft(pinteger(pcb.words[4]), 8),
                          st);
      u^.rcv_state := eth_rcv_got;
      di_$enq(addr(ethernet_$int_deferred), u, u^.di_elem);
    end
    else begin
      with u^ do
        stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
      ec_$advance_without_dispatch(u^.rcv_wake_ec);
    end;
  end

  { the reply a command waits for }
  else if (eth_unit_cmd_pending in u^.flags)
          and then (cmd = u^.reply_cmd) then begin
    u^.flags := u^.flags - [eth_unit_cmd_pending];
    u^.reply_pcb^.cmd := cmd;
    if ethernet_get_pcb(u, u^.reply_pcb, 2, st) then
      ec_$advance_without_dispatch(u^.reply_ec)
    else
      with u^ do
        stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
  end

  { the program's replies, and the rest }
  else if cmd = eth_cmd_x17 + eth_cmd_reply then begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    ec_$advance_without_dispatch(u^.ec_1280);
  end
  else if cmd = eth_cmd_x18 + eth_cmd_reply then begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    with u^ do
      stats.counts[eth_stat_xmit_failed] :=
        stats.counts[eth_stat_xmit_failed] + 1;
  end
  else begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    with u^ do
      stats.counts[eth_stat_unexpected] :=
        stats.counts[eth_stat_unexpected] + 1;
  end;

%if not ethernet_int_unmasked %then
  with u^.regs^ do begin
    control := control ! eth_hcr_cmde;
    control := control & ~eth_hcr_tcen;
  end;
%endif
  ethernet_$interrupt := true;
end;
%endif
