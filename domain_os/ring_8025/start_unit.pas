{ ring_8025_start_unit - bring a configured unit up and open it onto
  the ring.

  Image addresses:
    sau7  0x3C49632E  ring_8025_start_unit
    sau8  0x03C89A06  ring_8025_start_unit
    sau9  0x3C4855EA  ring_8025_start_unit

  - Acquires the unit with RING_8025_$INT as its interrupt routine
    (with `ring_8025_iomap' and the unit's I/O map region, freed again
    when the controller does not initialize), maps the map page (not with `ring_8025_dma_channel') and the unit's
    two window pages (at first onto the unit record's page), initializes
    the controller, enables the device and starts the unit's receive
    process.
  - Links the two receive lists and the three transmit lists into
    rings in the control area; every data descriptor of a receive list
    points at the one frame buffer at 0x400 of the control area.
  - Under the transmit lock, opens the adapter.  A failed open is not the
    start's failure: the unit is marked, its receive process woken, and
    the status cleared.  A good one starts the receiver and the transmitter.

  Status stored:
    status_$ok: the unit is started
    status_$io_controller_not_in_system: the unit is not configured
    status_$r8025_device_already_online: it is already started
    io_$acquire's status: the unit could not be acquired
    io_$alloc_map's status: no I/O map region
    status_$r8025_adapter_hardware_error: the controller did not
      initialize (the unit is released)
    io_$enable_device's status: the device could not be enabled
    proc1_$create_p's status: no receive process
}

{ TODO(pascal) 8 frame bytes of ring_8025_start_unit with `ring_8025_iomap'

  The SAU7 image's frame is 8 bytes larger than the SAU8's and the
  SAU9's (72 against 64), and its three addressed locals (the vtop
  status, the page number, the acquired unit) lie 8 bytes lower; nothing
  addresses the 8 bytes above them.  Two longword locals declared first
  would account for them (the I/O map region's address, say, which the
  code keeps in a register); the stand-ins unused_4 and unused_8 hold
  the place. }

procedure ring_8025_start_unit(u: ring_8025_$unit_ptr_t;
                               out status: status_$t); internal;
var
%if ring_8025_iomap %then
  unused_4: integer32;                    { stand-ins: the TODO above }
  unused_8: integer32;
%endif
  st: status_$t;
  ppn: integer32;
  unit: io_$unit_num_t;
  channel: integer;
  i: integer;
begin
  if not (r8025_unit_configured in u^.flags) then begin
    status.all := status_$io_controller_not_in_system;
    return;
  end;
  if r8025_unit_online in u^.flags then begin
    status.all := status_$r8025_device_already_online;
    return;
  end;
  with u^.regs^ do begin
%if ring_8025_iomap %then
    control_3 := control_3 & 16#FD;
%else
    control_3 := control_3 ! 2;
%endif
%if ring_8025_dma_channel %then
    reset := reset ! 16#14;
%else
    reset := reset ! 16#30;
%endif
    control_7 := control_7 ! 16#70;
    control_7 := control_7 & 16#FD;
    control_3 := control_3 & 16#FB;
  end;
  if u^.cnum = 0 then
    channel := 6
  else
    channel := 5;
  io_$acquire(ring_8025_$io_desc_ptr_t(u^.dcte^.disk_dinit)^,
              addr(ring_8025_$int), u^.dcte, unit, status);
  if status.all <> status_$ok then
    return;
%if ring_8025_iomap %then
  u^.iomap_page := rshft(io_$alloc_map(unit, r8025_iomap_len, false, 0,
                                       status), 10);
  if status.all <> status_$ok then
    return;
%endif
  ml_$exclusion_init(u^.xmit_lock);
  ml_$exclusion_init(u^.route_lock);
  ml_$exclusion_init(u^.nullsap_lock);
  ec_$init(u^.rcv_wake_ec);
  ec_$init(u^.scb_ec);
  ec_$init(u^.route_ec);
  u^.route_wait_val := ec_$read(u^.route_ec) + 1;
  u^.nullsap_count := 0;
  u^.nullsap_out := 0;
  u^.nullsap_in := 0;
  u^.range_count := 0;
  u^.io_unit := unit;
  u^.dma_channel := channel;
  u^.llc_class := 1;
  u^.ssb := addr(ring8025_$aux_da.ctl[u^.cnum].ssb);
  u^.scb := addr(ring8025_$aux_da.ctl[u^.cnum].scb);
%if not ring_8025_dma_channel %then
  mmu_$install(0, addr(ring8025_$aux_da.map_page), 0, 16#16);
  ring_8025_map_pmape := mmu_$get_pmape_addr(addr(ring8025_$aux_da.map_page));
%endif
  ring_8025_initialize(u, status);
  if status.all <> status_$ok then begin
%if ring_8025_iomap %then
    io_$free_map(unit, status);
%endif
    io_$release(unit, status);
    status.all := status_$r8025_adapter_hardware_error;
    return;
  end;

  { the unit's window pages, at first onto the unit record's page }
  ppn := mmu_$vtop(integer32(u), st);
  if st.all <> status_$ok then
    crash_system(st);
  u^.win1_va := addr(ring8025_$aux_da.windows[u^.cnum, 1]);
  mmu_$install(ppn, u^.win1_va, 0, 16#16);
  u^.win1_pmape := mmu_$get_pmape_addr(u^.win1_va);
  u^.win2_va := addr(ring8025_$aux_da.windows[u^.cnum, 2]);
  mmu_$install(ppn, u^.win2_va, 0, 16#16);
  u^.win2_pmape := mmu_$get_pmape_addr(u^.win2_va);
  u^.regs^.sifcmd := r8025_sifcmd_ssb_clear;
  io_$enable_device(unit, status);
  if status.all <> status_$ok then
    return;
  case u^.cnum of
    0: discard(proc1_$create_p(addr(ring_8025_$rcv0), 16#8000007, status));
    1: discard(proc1_$create_p(addr(ring_8025_$rcv1), 16#8000007, status));
  end;
  if status.all <> status_$ok then
    return;
  u^.flags := u^.flags + [r8025_unit_online, r8025_unit_rcv_proc];

  { the receive lists, a ring of two }
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    for i := 1 to r8025_list_data do begin
      rcv[1].data[i].cnt.count := r8025_frame_size;
      rcv[1].data[i].cnt.mark := true;
%if ring_8025_iomap %then
      rcv[1].data[i].pa := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].frame)),
                                          r8025_frame_size,
                                          u^.iomap_page + r8025_map_frame);
      rcv[1].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].rcv[2])),
                                       sizeof(ring_8025_$list_t),
                                       u^.iomap_page + r8025_map_ctl);
%else
      rcv[1].data[i].pa := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].frame)));
      rcv[1].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].rcv[2])));
%endif
    end;
    rcv[1].data[r8025_list_data].cnt.mark := false;
    rcv[1].next := addr(ring8025_$aux_da.ctl[u^.cnum].rcv[2]);
    rcv[1].buf := addr(ring8025_$aux_da.ctl[u^.cnum].frame);
  end;
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    for i := 1 to r8025_list_data do begin
      rcv[2].data[i].cnt.count := r8025_frame_size;
      rcv[2].data[i].cnt.mark := true;
%if ring_8025_iomap %then
      rcv[2].data[i].pa := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].frame)),
                                          r8025_frame_size,
                                          u^.iomap_page + r8025_map_frame);
      rcv[2].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].rcv[1])),
                                       sizeof(ring_8025_$list_t),
                                       u^.iomap_page + r8025_map_ctl);
%else
      rcv[2].data[i].pa := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].frame)));
      rcv[2].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].rcv[1])));
%endif
    end;
    rcv[2].data[r8025_list_data].cnt.mark := false;
    rcv[2].next := addr(ring8025_$aux_da.ctl[u^.cnum].rcv[1]);
    rcv[2].buf := addr(ring8025_$aux_da.ctl[u^.cnum].frame);
  end;
  u^.rcv_list := addr(ring8025_$aux_da.ctl[u^.cnum].rcv[1]);

  { the transmit lists, a ring of three }
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    xmit[1].cstat := [];
%if ring_8025_iomap %then
    xmit[1].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[2])),
                                      sizeof(ring_8025_$list_t),
                                      u^.iomap_page + r8025_map_ctl);
%else
    xmit[1].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[2])));
%endif
    xmit[1].next := addr(ring8025_$aux_da.ctl[u^.cnum].xmit[2]);
  end;
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    xmit[2].cstat := [];
%if ring_8025_iomap %then
    xmit[2].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[3])),
                                      sizeof(ring_8025_$list_t),
                                      u^.iomap_page + r8025_map_ctl);
%else
    xmit[2].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[3])));
%endif
    xmit[2].next := addr(ring8025_$aux_da.ctl[u^.cnum].xmit[3]);
  end;
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    xmit[3].cstat := [];
%if ring_8025_iomap %then
    xmit[3].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[1])),
                                      sizeof(ring_8025_$list_t),
                                      u^.iomap_page + r8025_map_ctl);
%else
    xmit[3].forward := ring_8025_vtop(integer32(addr(ring8025_$aux_da.ctl[u^.cnum].xmit[1])));
%endif
    xmit[3].next := addr(ring8025_$aux_da.ctl[u^.cnum].xmit[1]);
  end;
  u^.xmit_list := addr(ring8025_$aux_da.ctl[u^.cnum].xmit[1]);

  ml_$exclusion_start(u^.xmit_lock);
  ring_8025_open(u, status);
  if status.all <> status_$ok then begin
    u^.flags := u^.flags + [r8025_unit_open_failed];
    ec_$advance(u^.rcv_wake_ec);
    status.all := status_$ok;
  end
  else begin
    ring_8025_start_rcv(u);
    ring_8025_start_xmit(u);
    u^.flags := u^.flags + [r8025_unit_on_ring];
  end;
  ml_$exclusion_stop(u^.xmit_lock);
end;
