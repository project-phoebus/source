{ ethernet_setup - set an adapter up: its memory, its station address,
  its multicast list and its receive mode.

  Image addresses:
    sau6  0x78086D7C  ethernet_setup
    sau7  0x3C4916AA  ethernet_setup
    sau8  0x03C84EA6  ethernet_setup
    sau9  0x3C480AA6  ethernet_setup

  - A unit without a station address gets Apollo's: the vendor block
    08-00-1E and the node's number.  An address with either half zero
    crashes the system.
  - The commands are polled; the first that fails ends the setup.  The
    multicast list holds 09-00-1E-00-00-00 and 09-00-1E-00-00-01, and
    the 82586 is left in receive mode 2.
  - With `ethernet_vme': the unit's block of the shared section is
    taken (its rings, statistics and buffers' addresses kept in the
    unit), the start block filled with the rings' bus addresses, the
    rings' slots linked, and the controller given the start block's bus
    address a byte at a time; it marks the block's byte 6 when it has
    taken it.  Then the station address, Apollo's two multicast
    addresses and the controller's modes, each request awaited; the
    first that fails ends the setup.  Last the bus addresses of the
    statistics and the buffers.

  Status stored:
    ethernet_do_cmd_polled's status: the last command's
    with `ethernet_vme':
      ethernet_kick's, ethernet_start_cmd's or ethernet_wait_cmd's
        status: that step failed
      status_$eth_adapter_hardware_error: the controller did not take
        the start block, or refused it
      mmu_$vtop's status: otherwise
}

{ TODO(pascal) the adapter memory command's data

  The SAU9 image copies the configure-memory command's 12 data bytes
  whole, from a constant in the code.  No Pascal form of a 12-byte
  constant assigned whole is known that gives that copy; the six words
  are assigned one by one here, the same bytes. }

%if ethernet_vme %then
procedure ethernet_setup(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
type
  { The controller's start: two longwords given a byte at a time
    through its command register, the second the bus address of the
    start block, low byte first. }
  start_t = record
    case integer of
      1: (bus: array[1..2] of ethernet_$vme_bus_t);
      2: (bytes: array[1..8] of ethernet_$byte_t);
  end;
var
  blk: start_t;
  c: ethernet_$vme_ring_ptr_t;
  r: ethernet_$vme_ring_ptr_t;
  sh: ethernet_$vme_sh_ptr_t;
  cring: ethernet_$vme_ring_ptr_t;
  rring: ethernet_$vme_ring_ptr_t;
  va: integer32;
  pa: integer32;
  n: integer32;
  i: integer;
begin
  if (u^.station.high = 0) and then (u^.station.low = 0) then begin
    u^.station.high := eth_apollo_high;
    u^.station.low := node_$me;
  end;

  { the unit's block of the shared section }
  sh := addr(ethernet_vme_$sh[u^.cnum]);
  u^.sh := sh;
  cring := addr(ethernet_vme_$sh[u^.cnum].cmd_ring);
  u^.cmd_ring := cring;
  rring := addr(ethernet_vme_$sh[u^.cnum].reply_ring);
  u^.reply_ring := rring;
  u^.ctl_stats := addr(ethernet_vme_$sh[u^.cnum].stats);
  u^.rcv_va[1] := addr(ethernet_vme_$sh[u^.cnum].rcv_buf[1]);
  u^.rcv_va[2] := addr(ethernet_vme_$sh[u^.cnum].rcv_buf[2]);
  u^.xmit_va[1] := addr(ethernet_vme_$sh[u^.cnum].xmit_buf[1]);
  u^.xmit_va[2] := addr(ethernet_vme_$sh[u^.cnum].xmit_buf[2]);
  u^.stats.version := 1;

  { the start block }
  with sh^.cfg do begin
    words[0] := 1;
    for i := 1 to 2 do
      words[i] := 16#3030;
    bytes[6] := 16#FF;
    bytes[7] := 0;
    words[4] := 16#0101;
    bytes[10] := 0;
    bytes[11] := 0;
    bytes[12] := 0;
    bytes[13] := 3;
    bytes[14] := 0;
    bytes[15] := 0;
    bytes[16] := 1;
    bytes[17] := 3;
    bytes[18] := 7;
    bytes[19] := 15;
    words[10] := 16#0103;
    words[11] := 16#070F;
    longs[6] := 16#0103070F;
    for i := 7 to 11 do
      longs[i] := 0;
    longs[12] := -1;
    bytes[52] := 16#FF;
    bytes[53] := 16#FF;
    bytes[54] := 16#11;
    bytes[55] := 1;
    pa := lshft(mmu_$vtop(integer32(cring), status), 10);
    ethernet_check_status(status);
    blk.bus[1].all := pa - eth_vme_dma_base;
    blk.bus[1].space := eth_vme_bus_space;
    longs[14] := blk.bus[1].all;
    bytes[62] := 4;
    bytes[63] := 0;
    words[30] := integer32(cring) mod 1024;
    case u^.cnum of
      0: begin
        words[32] := 245;
      end;
      1: begin
        words[32] := 246;
      end;
    end;
    words[33] := 0;
    pa := lshft(mmu_$vtop(integer32(rring), status), 10);
    ethernet_check_status(status);
    blk.bus[1].all := pa - eth_vme_dma_base;
    blk.bus[1].space := eth_vme_bus_space;
    longs[17] := blk.bus[1].all;
    words[36] := integer32(rring) mod 1024;
    bytes[74] := 4;
    bytes[75] := 0;
    words[38] := words[32];
    words[39] := 0;
  end;

  { the rings: each slot linked to the next, the command slots the
    host's, the reply slots the controller's }
  c := u^.cmd_ring;
  r := u^.reply_ring;
  c^.head := sh^.cfg.words[30] + 2;
  r^.head := sh^.cfg.words[36] + 2;
  for i := 1 to eth_vme_ring_slots do begin
    with c^.slots[i] do begin
      link := c^.head + (i mod eth_vme_ring_slots) * 64;
      byte_02 := 0;
      owner := [eth_vme_slot_busy];
      len := 0;
    end;
    with r^.slots[i] do begin
      link := r^.head + (i mod eth_vme_ring_slots) * 64;
      byte_02 := 0;
      owner := [eth_vme_slot_ctlr, eth_vme_slot_busy];
      len := 58;
    end;
  end;
  u^.cmd_idx := 1;
  u^.cmd_done := eth_vme_ring_slots;
  u^.ring_12c0 := eth_vme_ring_slots;
  u^.reply_idx := eth_vme_ring_slots;

  { the controller started on the block }
  blk.bus[1].all := 16#FFFF0000;
  pa := lshft(mmu_$vtop(integer32(sh), status), 10);
  ethernet_check_status(status);
  blk.bus[2].all := pa - eth_vme_dma_base + (integer32(sh) mod 1024);
  blk.bus[2].space := eth_vme_bus_space;
  blk.bus[2].all := ethernet_swap32(blk.bus[2].all);
  for i := 1 to 8 do
    if not ethernet_kick(u^.regs, blk.bytes[i], status) then
      return;
  n := 400000;
  repeat
    if n = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      return;
    end;
    n := n - 1;
  until sh^.cfg.bytes[6] <> 16#FF;
  if sh^.cfg.bytes[6] <> 0 then begin
    status.all := status_$eth_adapter_hardware_error;
    return;
  end;

  { the station address and Apollo's two multicast addresses, then the
    controller's modes }
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_set_address;
    param_2 := 1;
    value_2 := 16#FD;
    hw_addr.high := u^.station.high;
    hw_addr.low := u^.station.low;
    if (hw_addr.high = 0) or else (hw_addr.low = 0) then
      crash_system(status_$eth_illegal_dest_address);
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_set_address;
    param_2 := 1;
    value_2 := 1;
    hw_addr.high := eth_apollo_mcast_high;
    hw_addr.low := 0;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_set_address;
    param_2 := 1;
    value_2 := 2;
    hw_addr.high := eth_apollo_mcast_high;
    hw_addr.low := 1;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x08;
    param := 1;
    value := 0;
    bytes[16] := 1;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x0a;
    param := 1;
    value := 16#FF;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x0a;
    param := 5;
    value := 16#FD;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x0a;
    param := 5;
    value := 1;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x0a;
    param := 5;
    value := 2;
  end;
  ethernet_start_cmd(u, status);
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    ethernet_wait_cmd(u, status);
  end
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  if status.all <> status_$ok then
    return;

  { the bus addresses of the controller's statistics and the buffers }
  va := integer32(addr(ethernet_vme_$sh[u^.cnum].stats));
  pa := lshft(mmu_$vtop(va, status), 10);
  ethernet_check_status(status);
  blk.bus[1].all := pa - eth_vme_dma_base + (va mod 1024);
  blk.bus[1].space := eth_vme_bus_space;
  u^.ctl_stats_bus := blk.bus[1].all;
  va := integer32(addr(ethernet_vme_$sh[u^.cnum].rcv_buf[1]));
  pa := lshft(mmu_$vtop(va, status), 10);
  ethernet_check_status(status);
  blk.bus[1].all := pa - eth_vme_dma_base + (va mod 1024);
  blk.bus[1].space := eth_vme_bus_space;
  u^.rcv_bus[1] := blk.bus[1].all;
  va := integer32(addr(ethernet_vme_$sh[u^.cnum].rcv_buf[2]));
  pa := lshft(mmu_$vtop(va, status), 10);
  ethernet_check_status(status);
  blk.bus[1].all := pa - eth_vme_dma_base + (va mod 1024);
  blk.bus[1].space := eth_vme_bus_space;
  u^.rcv_bus[2] := blk.bus[1].all;
  va := integer32(addr(ethernet_vme_$sh[u^.cnum].xmit_buf[1]));
  pa := lshft(mmu_$vtop(va, status), 10);
  ethernet_check_status(status);
  blk.bus[1].all := pa - eth_vme_dma_base + (va mod 1024);
  blk.bus[1].space := eth_vme_bus_space;
  u^.xmit_bus[1] := blk.bus[1].all;
  va := integer32(addr(ethernet_vme_$sh[u^.cnum].xmit_buf[2]));
  pa := lshft(mmu_$vtop(va, status), 10);
  ethernet_check_status(status);
  blk.bus[1].all := pa - eth_vme_dma_base + (va mod 1024);
  blk.bus[1].space := eth_vme_bus_space;
  u^.xmit_bus[2] := blk.bus[1].all;
end;
%else
procedure ethernet_setup(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
begin
  if (u^.station.high = 0) and then (u^.station.low = 0) then begin
    u^.station.high := 16#08001E;
    u^.station.low := node_$me;
  end;
  pcb.cmd := eth_cmd_configure_memory;
  pcb.len := 12;
  pcb.words[1] := 16#0400;
  pcb.words[2] := 16#0200;
  pcb.words[3] := 16#1100;
  pcb.words[4] := 16#2000;
  pcb.words[5] := 16#2000;
  pcb.words[6] := 16#0500;
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_configure_memory + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_set_station_address;
  pcb.len := 6;
  pcb.addrs[1].high := u^.station.high;
  pcb.addrs[1].low := u^.station.low;
  if (pcb.addrs[1].high = 0) or else (pcb.addrs[1].low = 0) then
    crash_system(status_$eth_illegal_dest_address);
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_set_station_address + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_load_multicast;
  pcb.len := 12;
  pcb.addrs[1].high := 16#09001E;
  pcb.addrs[1].low := 0;
  pcb.addrs[2].high := 16#09001E;
  pcb.addrs[2].low := 1;
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_load_multicast + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_configure_82586;
  pcb.len := 2;
  pcb.words[1] := 16#0200;
  u^.flags := u^.flags - [eth_unit_cfg_3];
  discard(ethernet_do_cmd_polled(u, addr(pcb),
                                 eth_cmd_configure_82586 + eth_cmd_reply,
                                 status));
end;
%endif
