{ RING_$RCV_INT - a ring unit's receive interrupt.

  Image addresses:
    sau4  0x0F882F8E  RING_$RCV_INT

  - The interrupt is acknowledged, the receive light toggled, and the
    packet handed to ring_$process_rx_packet: its eventcount advanced,
    or rcvcnt counted for nil.  The result is true.
  - With the board's own DMA (`ring_board_dma') only: ring_$init_internal
    defines it with SYSBUS_$DEFINE_INT for the two receive vectors, with
    the unit's DCTE.

  Status stored: none.
}

function ring_$rcv_int(var dcte: dcte_t): boolean;
var
  regs: ring_$regs_ptr_t;
  ec: ec_$eventcount_ptr_t;
begin
  regs := dcte.disk_dinit;
  regs^.rx_int_ack := 1;
  ring_$rcv_int_cnt := ring_$rcv_int_cnt + 1;
  mmu_$mcr_change(4);
  ec := ring_$process_rx_packet(ring_$ctl[dcte.cnum]);
  if ec = nil then
    ring_$data[dcte.cnum].rcvcnt := ring_$data[dcte.cnum].rcvcnt + 1
  else
    ec_$advance_without_dispatch(ec^);

  ring_$rcv_int := true;
end;
