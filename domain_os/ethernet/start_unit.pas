{ ethernet_start_unit - bring a configured unit on line.

  Image addresses:
    sau6  0x780876A8  ethernet_start_unit
    sau7  0x3C491814  ethernet_start_unit
    sau8  0x03C85010  ethernet_start_unit
    sau9  0x3C480C10  ethernet_start_unit

  - The adapter is reset, the unit's locks, eventcounts and tables
    cleared, the unit acquired from IO_ with ETHERNET_$INTERRUPT as its
    handler (which sets its I/O unit number) and the adapter set up.
  - The unit's two pages of ETHERNET_$BUFFER are installed, the receive
    process created, the first receive started, the adapter's command
    interrupt enabled and the device enabled.  The first step that fails
    ends it, with what it did left in place.
  - With `ethernet_vme': the transmit and receive buffers' indices and
    busy flags are set up too, the interrupt is defined with
    SYSBUS_$DEFINE_INT (the DCTE's vector, ETHERNET_$INTERRUPT, the
    DCTE), and the controller is set up and given both receive buffers.

  Status stored:
    status_$io_controller_not_in_system: the unit is not configured
    status_$eth_device_already_online: it is on line already
    ethernet_reset's, io_$acquire's, ethernet_setup's, proc1_$create_p's,
      ethernet_start_rcv's or io_$enable_device's status: that step
      failed (with `ethernet_vme', no io_$acquire or io_$enable_device)
    status_$ok: the unit is on line
}

procedure ethernet_start_unit(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
%if ethernet_vme %then
var
  id: io_$int_id_t;
  i: integer;
  j: integer;
begin
  if not (eth_unit_configured in u^.flags) then begin
    status.all := status_$io_controller_not_in_system;
    return;
  end;
  if eth_unit_online in u^.flags then begin
    status.all := status_$eth_device_already_online;
    return;
  end;
  if not ethernet_reset(u^.regs, status) then
    return;
  ml_$exclusion_init(u^.cmd_lock);
  u^.spare_dat := 0;
  ec_$init(u^.rcv_wake_ec);
  ec_$init(u^.reply_ec);
  ml_$exclusion_init(u^.xmit_lock);
  u^.xmit_idx := 1;
  u^.xmit_done := 1;
  u^.xmit_busy[1] := false;
  u^.xmit_busy[2] := false;
  u^.rcv_idx := 1;
  u^.rcv_done := 1;
  u^.rcv_busy[1] := false;
  u^.rcv_busy[2] := false;
  ec_$init(u^.xmit_wait_ec);
  ml_$exclusion_init(u^.arp_lock);
  for i := 0 to 63 do
    for j := 0 to 3 do begin
      u^.arp[i, j].node := 0;
      u^.arp[i, j].expire := 0;
    end;
  u^.range_count := 0;
  for i := 1 to 15 do begin
    u^.mcast[i].count := 0;
    u^.mcast[i].loaded := 0;
  end;
  u^.mcast_count := 0;
  id.vector := u^.dcte^.disk_error_que_lo;
  sysbus_$define_int(id, addr(ethernet_$interrupt), u^.dcte);
  ethernet_setup(u, status);
  if status.all <> status_$ok then
    return;
  discard(proc1_$create_p(ethernet_rcv_proc[u^.cnum], 16#8000007, status));
  if status.all <> status_$ok then
    return;
  u^.flags := u^.flags + [eth_unit_rcv_proc];
  ethernet_get_rcv_bufs(u);
  u^.rcv_state := eth_rcv_idle;
  ethernet_start_rcv(u, status);
  if status.all <> status_$ok then
    return;
  ethernet_start_rcv(u, status);
  if status.all <> status_$ok then
    return;
  u^.flags := u^.flags + [eth_unit_online];
  status.all := status_$ok;
end;
%else
var
  i: integer;
  j: integer;
  buf_off: integer;
begin
  if not (eth_unit_configured in u^.flags) then begin
    status.all := status_$io_controller_not_in_system;
    return;
  end;
  if eth_unit_online in u^.flags then begin
    status.all := status_$eth_device_already_online;
    return;
  end;
  if not ethernet_reset(u^.regs, status) then
    return;
  ml_$exclusion_init(u^.cmd_lock);
  u^.spare_dat := 0;
  ec_$init(u^.rcv_wake_ec);
  ec_$init(u^.reply_ec);
  ec_$init(u^.ec_1280);
  ml_$exclusion_init(u^.arp_lock);
  for i := 0 to 63 do
    for j := 0 to 3 do begin
      u^.arp[i, j].node := 0;
      u^.arp[i, j].expire := 0;
    end;
  u^.range_count := 0;
  for i := 1 to 15 do
    u^.mcast[i].count := 0;
  u^.mcast_count := 0;
  io_$acquire(ethernet_$io_desc_ptr_t(u^.dcte^.disk_dinit)^,
              addr(ethernet_$interrupt), u^.dcte, u^.io_unit, status);
  if status.all <> status_$ok then
    return;
  ethernet_setup(u, status);
  if status.all <> status_$ok then
    return;
  buf_off := u^.cnum * 2048;
  u^.buf_va := integer32(addr(ethernet_$buffer[buf_off]));
  mmu_$install(0, addr(ethernet_$buffer[buf_off]), 0, 16#16);
  u^.buf_pmape := mmu_$get_pmape_addr(univ_ptr(u^.buf_va));
  u^.buf2_va := integer32(addr(ethernet_$buffer[buf_off + 1024]));
  mmu_$install(0, addr(ethernet_$buffer[buf_off + 1024]), 0, 16#16);
  u^.buf2_pmape := mmu_$get_pmape_addr(univ_ptr(u^.buf2_va));
  discard(proc1_$create_p(ethernet_rcv_proc[u^.cnum], 16#8000007, status));
  if status.all <> status_$ok then
    return;
  u^.flags := u^.flags + [eth_unit_rcv_proc];
  ethernet_get_rcv_bufs(u);
  u^.rcv_state := eth_rcv_idle;
  ethernet_start_rcv(u, status);
  if status.all <> status_$ok then
    return;
  u^.regs^.control := u^.regs^.control & ~eth_hcr_dir;
  u^.regs^.control := u^.regs^.control ! eth_hcr_cmde;
  io_$enable_device(u^.io_unit, status);
  if status.all <> status_$ok then
    return;
  u^.flags := u^.flags + [eth_unit_online];
  status.all := status_$ok;
end;
%endif
