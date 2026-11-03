{ RING8_$INT - the ring controller's interrupt, for both units.

  Image addresses:
    sau8  0x03C81B30  RING8_$INT
    sau9  0x3C47D730  RING8_$INT
    sau8  0x03C81A4A  ring8_$unit_int (nested)
    sau9  0x3C47D64A  ring8_$unit_int (nested)
    sau8  0x03C81AFA  ring8_$start_rx (nested)
    sau9  0x3C47D6FA  ring8_$start_rx (nested)

  - The AT bus handler IO_$ACQUIRE installs; its argument (the DCTE) is
    not read.  No unit initialized, or a fault: crash with
    status_$network_hardware_error.
  - The units are serviced (ring8_$unit_int, nested) until a pass finds
    nothing; then a receive given a new buffer is started
    (ring8_$start_rx, nested).
  - A received packet goes to ring_$process_rx_packet, whose eventcount
    is advanced (none: the unit's rcvcnt counts it).

  Returns:
    true

  Status stored: none.
}

function ring8_$int(dcte: univ_ptr): boolean;
  options(val_param);
var
  ec: ec_$eventcount_ptr_t;
  busy: boolean;

  { ring8_$unit_int: service one unit's transmit and receive. }
  function ring8_$unit_int(var unit: ring_$unit_t; unit_num: pinteger):
    boolean;
    options(val_param);
  var
    hw: ring8_$csr_ptr_t;
    found: boolean;
  begin
    hw := unit.hw_regs;
    found := false;
    if not (2 in hw^.status) then begin
      hw^.tx_ack := 1;
      ec_$advance_without_dispatch(unit.tx_ec);
      found := true;
    end;
    if not (1 in hw^.status) then begin
      ring_$rcv_int_cnt := ring_$rcv_int_cnt + 1;
      mmu_$mcr_change(4);
      ec := ring_$process_rx_packet(unit);
      if ec = nil then
        ring_$data[unit_num].rcvcnt := ring_$data[unit_num].rcvcnt + 1
      else
        ec_$advance_without_dispatch(ec^);
      found := true;
      hw^.rx_ack := 1;
    end;
    if not (0 in hw^.status) then
      crash_system(status_$network_hardware_error);
    ring8_$unit_int := found;
  end;

  { ring8_$start_rx: start the receive into the unit's current buffer. }
  procedure ring8_$start_rx(var unit: ring_$unit_t;
                            var buf: ring8_$rx_buf_t);
  var
    hw: ring8_$csr_ptr_t;
  begin
    unit.rx_restart := false;
    hw := unit.hw_regs;
    hw^.status := [11];
    hw^.rx_status := [11];
    buf.hdr_len := 0;
    buf.copied := false;
    buf.full := false;
    buf.armed := true;
  end;

begin
  if not (ring_$ctl[0].initialized or ring_$ctl[1].initialized) then
    crash_system(status_$network_hardware_error);

  repeat
    busy := false;
    if ring_$ctl[0].initialized and then ring8_$unit_int(ring_$ctl[0], 0) then
      busy := true;
    if ring_$ctl[1].initialized and then ring8_$unit_int(ring_$ctl[1], 1) then
      busy := true;
  until not busy;

  if ring_$ctl[0].rx_restart then
    ring8_$start_rx(ring_$ctl[0],
                    ring_$ctl[0].rx_bufs[ring_$ctl[0].rx_index]);
  if ring_$ctl[1].rx_restart then
    ring8_$start_rx(ring_$ctl[1],
                    ring_$ctl[1].rx_bufs[ring_$ctl[1].rx_index]);
  ring8_$int := true;
end;
