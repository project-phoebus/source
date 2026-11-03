{ RING_8025_$INIT - initialize a token-ring controller.

  Image addresses:
    sau8  0x03C8B4F6  RING_8025_$INIT
    sau9  0x3C4870FA  RING_8025_$INIT

  - The DCTE's unit must be 0 or 1 and its adapter answer at the CSR
    pages its I/O descriptor maps (ring_8025_probe; the DCTE's longword
    at 0x34 points to the descriptor).
  - The unit's record is set up (configured, source routing on, the
    first largest frame, no channel open, the statistics cleared), the
    driver record given the network's UID, a NET_IO port created for the
    unit and the unit's I/O map space allocated.
  - The result is the status as a longword; a unit out of range or an
    adapter that does not answer is status_$io_controller_not_in_system.

  Status stored: none.
}

function ring_8025_$init(var dcte: dcte_t): integer32;
var
  status: status_$t;
  u: ring_8025_$unit_ptr_t;
  i: integer;
begin
  if (dcte.cnum > r8025_max_unit) or else
     not ring_8025_probe(ring_8025_$io_desc_ptr_t(dcte.disk_dinit)) then begin
    ring_8025_$init := status_$io_controller_not_in_system;
    return;
  end;
  u := addr(ring8025_ucb[dcte.cnum]);
  u^.flags := [r8025_unit_configured];
  u^.wired := false;
  u^.routes_wired := false;
  u^.ctl_wired := false;
  u^.routing := true;
  u^.max_frame := r8025_max_frame;
  ml_$exclusion_init(u^.lock);
  u^.users := 0;
  u^.cnum := dcte.cnum;
  u^.regs := ring_8025_$regs_ptr_t(
               ring_8025_$io_desc_ptr_t(dcte.disk_dinit)^.csr.va);
  u^.dcte := addr(dcte);
  ml_$exclusion_init(u^.chan_lock);
  for i := 1 to r8025_max_chan do
    u^.channels[i].open := false;
  ec_$init(u^.rcv_exit_ec);
  with u^ do
    for i := 1 to 25 do
      stats.counts[i] := 0;
  ring_8025_driver.network_uid := ring_8025_$network_uid;
  u^.port := net_io_$create_port(5, dcte.cnum, addr(ring_8025_driver), 0,
                                 status);
  if status.all <> status_$ok then begin
    ring_8025_$init := status.all;
    return;
  end;
  case dcte.cnum of
    0: discard(io_$alloc(u^.io_unit, 8, true, 16#98000, status));
    1: discard(io_$alloc(u^.io_unit, 8, true, 16#94000, status));
  end;
  if status.all <> status_$ok then begin
    ring_8025_$init := status.all;
    return;
  end;
  ring_8025_$init := status_$ok;
end;
