{ RING_$XMIT_INT - a ring unit's transmit interrupt.

  Image addresses:
    sau4  0x0F882F50  RING_$XMIT_INT

  - The controller's transmit interrupt is acknowledged and the unit's
    transmit eventcount advanced.  The result is true.
  - With the board's own DMA (`ring_board_dma') only: ring_$init_internal
    defines it with SYSBUS_$DEFINE_INT for the transmit vector, with the
    unit's DCTE.

  Status stored: none.
}

function ring_$xmit_int(var dcte: dcte_t): boolean;
var
  unit: ring_$unit_ptr_t;
begin
  unit := addr(ring_$ctl[dcte.cnum]);
  unit^.hw_regs^.tx_int_ack := 1;
  ec_$advance_without_dispatch(unit^.tx_ec);
  ring_$xmit_int := true;
end;
