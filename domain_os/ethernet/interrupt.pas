{ ETHERNET_$INTERRUPT - a unit's interrupt routine.

  Image addresses:
    sau9  0x3C48464E  ETHERNET_$INTERRUPT

  - The routine IO_$ACQUIRE registers with the unit's DCTE.  A byte in
    the adapter's command register names the block it sends, which is
    read after it: the downloaded program's notice of a received packet
    (its length, then the deferred work queued); the reply to the
    receive command (the packet read, then the deferred work queued); the
    reply a command waits for (copied to the waiter's block and the
    waiter woken); the program's replies to its two commands.
  - The command register's interrupt is off while it works.
  - No byte in the command register counts in the ninth statistic, as
    does an unknown block; a failed read in the seventh (the receive
    process woken), a transmit reply of the program in the tenth.
  - The result is true: the interrupt was the unit's.

  Status stored: none.
}

function ethernet_$interrupt(dcte: integer32): boolean;
  options(val_param);
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
      stats.counts[9] := stats.counts[9] + 1;
    ethernet_$interrupt := true;
    return;
  end;
  with regs^ do begin
    control := control ! eth_hcr_tcen;
    control := control & ~eth_hcr_cmde;
  end;
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
        stats.counts[7] := stats.counts[7] + 1;
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
        stats.counts[7] := stats.counts[7] + 1;
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
        stats.counts[7] := stats.counts[7] + 1;
  end

  { the program's replies, and the rest }
  else if cmd = eth_cmd_x17 + eth_cmd_reply then begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    ec_$advance_without_dispatch(u^.ec_1280);
  end
  else if cmd = eth_cmd_x18 + eth_cmd_reply then begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    with u^ do
      stats.counts[10] := stats.counts[10] + 1;
  end
  else begin
    discard(ethernet_get_pcb(u, addr(pcb), 2, st));
    with u^ do
      stats.counts[9] := stats.counts[9] + 1;
  end;

  with u^.regs^ do begin
    control := control ! eth_hcr_cmde;
    control := control & ~eth_hcr_tcen;
  end;
  ethernet_$interrupt := true;
end;
