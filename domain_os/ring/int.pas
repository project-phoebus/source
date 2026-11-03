{ RING_$INT - a ring unit's interrupt.

  Image addresses:
    sau2  0x00E75748  RING_$INT
    sau3  0x00E76F48  RING_$INT
    sau5  0x00E7CAC8  RING_$INT

  - A transmit completion advances the unit's transmit eventcount; a
    receive completion hands the packet to ring_$process_rx_packet and
    advances the eventcount it returns.  The result is true.

  Status stored: none.
}

function ring_$int(var dcte: dcte_t): boolean;
var
  regs: ring_$regs_ptr_t;
  unit: ring_$unit_ptr_t;
  ec: ec_$eventcount_ptr_t;
begin
  unit := addr(ring_$ctl[dcte.cnum]);
  regs := dcte.disk_dinit;

  if 15 in regs^.xmit_csr then begin
    regs^.xmit_csr := [];
    ec_$advance_without_dispatch(unit^.tx_ec);
  end
  else if 15 in regs^.rcv_csr then begin
    regs^.rcv_csr := [];
    ring_$rcv_int_cnt := ring_$rcv_int_cnt + 1;
    mmu_$mcr_change(5);
    ec := ring_$process_rx_packet(ring_$ctl[dcte.cnum]);
    if ec = nil then
      ring_$data[dcte.cnum].rcvcnt := ring_$data[dcte.cnum].rcvcnt + 1
    else
      ec_$advance_without_dispatch(ec^);
  end;

  ring_$int := true;
end;
