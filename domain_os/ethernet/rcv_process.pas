{ ethernet_rcv_process - a unit's receive process.

  Image addresses:
    sau8  0x03C88C12  ethernet_rcv_process
    sau9  0x3C484838  ethernet_rcv_process

  - Under the server lock, woken through the unit's rcv_wake_ec, it does
    the receive work the deferred work left (the receive state): a
    packet read, learnt from (ARP), handed on, new pages; then the next
    receive command.  A failed step counts in the seventh statistic.
  - When the unit is off line it disables and releases the device,
    turns the command register's interrupt off, gives the pages back,
    unmaps the unit's buffer windows, leaves the unit configured only,
    advances rcv_exit_ec and unbinds itself.

  Status stored: none.
}

procedure ethernet_rcv_process(unit: pinteger); internal;
var
  pcb: ethernet_$pcb_t;
  st: status_$t;
  vals: ec_$waitn_vals_t;
  ecs: ec_$waitn_ecs_t;
  u: ethernet_$unit_ptr_t;
  wait_val: integer32;
begin
  proc1_$set_lock(ml_$server_lock);
  wait_val := 0;
  u := addr(ether_ucb[unit]);
  repeat
    wait_val := wait_val + 1;
    vals[1] := wait_val;
    ecs[1] := addr(u^.rcv_wake_ec);
    discard(ec_$waitn(ecs, vals, 1));

    { a packet the adapter announced, left for this level }
    if (eth_unit_rcv_ready in u^.flags)
       and then (u^.rcv_state = eth_rcv_idle) then begin
      u^.rcv_state := eth_rcv_read;
      u^.flags := u^.flags - [eth_unit_rcv_ready];
    end;
    if u^.rcv_state = eth_rcv_read then begin
      pcb.cmd := eth_cmd_x17;
      pcb.len := 0;
      ml_$exclusion_start(u^.cmd_lock);
      if ethernet_send_pcb(u, addr(pcb), st) then
        ethernet_rcv_packet(u, (u^.rcv_len + 1) & ~1, u^.rcv_tag, st);
      ml_$exclusion_stop(u^.cmd_lock);
      if st.all = status_$ok then
        u^.rcv_state := eth_rcv_got
      else begin
        with u^ do
          stats.counts[7] := stats.counts[7] + 1;
        u^.rcv_state := eth_rcv_idle;
      end;
    end;

    { the packet in the pages }
    if u^.rcv_state = eth_rcv_got then begin
      ethernet_arp_input(u, u^.hdr_va);
      u^.rcv_state := eth_rcv_demux;
    end;
    if u^.rcv_state = eth_rcv_demux then begin
      ethernet_demux(u);
      u^.rcv_state := eth_rcv_bufs;
    end;
    if u^.rcv_state = eth_rcv_bufs then begin
      ethernet_get_rcv_bufs(u);
      u^.rcv_state := eth_rcv_idle;
    end;

    { the next receive command }
    if not (eth_unit_rcv_pending in u^.flags) then begin
      ethernet_start_rcv(u, st);
      if st.all <> status_$ok then
        with u^ do
          stats.counts[7] := stats.counts[7] + 1;
    end;
  until not (eth_unit_online in u^.flags);

  { the unit is off line }
  proc1_$clr_lock(ml_$server_lock);
  io_$disable_device(u^.io_unit, st);
  u^.regs^.control := u^.regs^.control & ~eth_hcr_cmde;
  io_$release(u^.io_unit, st);
  netbuf_$rtn_hdr(u^.hdr_va);
  if u^.dat_va <> 0 then
    netbuf_$rtn_dat(u^.dat_va);
  if u^.spare_dat <> 0 then
    netbuf_$rtn_dat(u^.spare_dat);
  u^.rcv_state := eth_rcv_bufs;
  mmu_$remove(u^.buf_va, 0);
  mmu_$remove(u^.buf2_va, 0);
  u^.flags := [eth_unit_configured];
  ec_$advance(u^.rcv_exit_ec);
  proc1_$unbind(proc1_$current, st);
end;
