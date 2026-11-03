{ ring_8025_rcv_process - a unit's receive process.

  Image addresses:
    sau8  0x03C8D460  ring_8025_rcv_process
    sau9  0x3C489170  ring_8025_rcv_process

  - Under the server lock, woken through the unit's rcv_wake_ec, it does
    the work the interrupt routine flagged: after an adapter check the
    adapter is set up, opened and started again (under the transmit
    lock); the removals from the ring are counted; an adapter off the
    ring is halted and closed if it was on it, then opened every 20
    ticks while the unit is on line until it opens, and started; the
    error counters are read when they overflowed.  Then each complete
    receive list's frame is taken (ring_8025_receive_frame), the list
    handed back, and the adapter told to continue receiving.
  - When the unit is off line it halts and closes the adapter, stops
    its DMA channel (`ring_8025_dma_channel'), interrupts it, disables and releases the device, unmaps the unit's
    second window page, leaves the unit configured only, advances
    rcv_exit_ec and unbinds itself.

  Status stored: none.
}

procedure ring_8025_rcv_process(unit: pinteger); internal;
var
  copy: ring_8025_$stats_t;
  buf: ring_8025_$stats_ptr_t;
%if ring_8025_dma_channel %then
  count: integer32;
%endif
  st: status_$t;
  vals: ec_$waitn_vals_t;
  len: integer;
  ecs: ec_$waitn_ecs_t;
  u: ring_8025_$unit_ptr_t;
  wait_val: integer32;
begin
  proc1_$set_lock(ml_$server_lock);
  wait_val := 0;
  u := addr(ring8025_ucb[unit]);
  repeat
    wait_val := wait_val + 1;
    vals[1] := wait_val;
    ecs[1] := addr(u^.rcv_wake_ec);
    discard(ec_$waitn(ecs, vals, 1));

    { an adapter check: the adapter set up, opened and started again }
    if r8025_unit_adapter_check in u^.flags then begin
      ml_$exclusion_start(u^.xmit_lock);
      u^.stats.adapter_checks := u^.stats.adapter_checks + 1;
      ring_8025_initialize(u, st);
      ring_8025_open(u, st);
      ring_8025_start_rcv(u);
      ring_8025_start_xmit(u);
      u^.flags := u^.flags - [r8025_unit_adapter_check];
      ml_$exclusion_stop(u^.xmit_lock);
    end;

    { the removals from the ring }
    if r8025_unit_removed in u^.flags then begin
      with u^ do
        stats.removes := stats.removes + 1;
      u^.flags := u^.flags - [r8025_unit_removed];
    end;
    if r8025_unit_auto_removal in u^.flags then begin
      with u^ do
        stats.auto_removals := stats.auto_removals + 1;
      u^.flags := u^.flags - [r8025_unit_auto_removal];
    end;

    { off the ring: closed, then opened again until it opens }
    if r8025_unit_open_failed in u^.flags then begin
      if r8025_unit_on_ring in u^.flags then begin
        ml_$exclusion_start(u^.xmit_lock);
        ring_8025_xmit_halt(u);
        ring_8025_close(u);
        ml_$exclusion_stop(u^.xmit_lock);
      end;
      while r8025_unit_online in u^.flags do begin
        u^.stats.reopen_tries := u^.stats.reopen_tries + 1;
        ml_$exclusion_start(u^.xmit_lock);
        ring_8025_open(u, st);
        ml_$exclusion_stop(u^.xmit_lock);
        if st.all = status_$ok then
          exit;
        ring_8025_wait(20);
      end;
      ml_$exclusion_start(u^.xmit_lock);
      ring_8025_start_rcv(u);
      ring_8025_start_xmit(u);
      ml_$exclusion_stop(u^.xmit_lock);
      u^.flags := u^.flags + [r8025_unit_on_ring];
      u^.flags := u^.flags - [r8025_unit_open_failed];
    end;

    { the error counters overflowed: read them }
    if r8025_unit_counter_ovf in u^.flags then begin
      buf := addr(copy);
      ring_8025_read_stats(u^.cnum, buf, len, st);
      u^.flags := u^.flags - [r8025_unit_counter_ovf];
    end;

    { the frames received }
    while r8025_cstat_complete in u^.rcv_list^.cstat do begin
      ring_8025_receive_frame(u);
      u^.rcv_list^.cstat := [r8025_cstat_valid, r8025_cstat_rcv_ifw];
      u^.rcv_list := u^.rcv_list^.next;
    end;
    u^.regs^.sifcmd := r8025_sifcmd_rcv_continue;
  until not (r8025_unit_online in u^.flags);

  { the unit is off line }
  proc1_$clr_lock(ml_$server_lock);
  ring_8025_xmit_halt(u);
  ring_8025_close(u);
%if ring_8025_dma_channel %then
  dma_$stop(u^.dma_channel, count, st);
%endif
  u^.regs^.sifcmd := r8025_sifcmd_interrupt;
  io_$disable_device(u^.io_unit, st);
  io_$release(u^.io_unit, st);
  mmu_$remove(u^.win2_va, 0);
  u^.flags := [r8025_unit_configured];
  ec_$advance(u^.rcv_exit_ec);
  proc1_$unbind(proc1_$current, st);
end;
