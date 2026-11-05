{ RING_$SENDP - send one packet on a ring unit.

  Image addresses:
    sau2  0x00E75916  RING_$SENDP
    sau3  0x00E77116  RING_$SENDP
    sau4  0x0F8831B2  RING_$SENDP
    sau5  0x00E7CBFA  RING_$SENDP
    sau6  0x78083FE2  RING_$SENDP
    sau7  0x3C48E720  RING_$SENDP
    sau8  0x03C81F20  RING_$SENDP
    sau9  0x3C47DB12  RING_$SENDP

  - A first attempt polls for the transmit eventcount until RING_$CTL's
    poll timeout, then waits for it; a retry forces the start and waits
    a fixed time.
  - A send that never completes is retried, switching the ring to its
    congestion mode once.
  - The soft failures are retried after a delay until the retries run
    out, unless the header or flags forbid them; xmit_status gets the
    send's outcome members.
  - At the end biphase_flag is stored twice.
  - With `ring_xmit_light' a completed send toggles the transmit light
    of the memory control register before the status is read.
  - With the board's own DMA (`ring_board_dma') the packet goes to the
    transmit's DMA controller, the start, forced start, abort and
    congestion mode are command bytes, and the outcome is the
    controller's transmit status with its own bits; a transmit bus
    error crashes the system with status_$network_transmit_bus_error
    (no parity check), and the light is bit 8.
  - Without `memory_parity' a transmit bus error is only counted and
    retried; with `ring_lights_8_4' the light is bit 8.
  - With the controller with buffers of its own (`ring8_controller')
    the packet is copied into the controller (ring_$setup_tx) under the
    unit's buffer lock, held to the end of the send on the 16 KB
    controller; the poll also ends when the ring has the packet, and
    the wait is a run of short waits until three ticks of the high
    clock have passed.  The outcome is the command word's high byte;
    an error status is counted in RING_$FROM_ERR and every third in a
    row in RING_$SCRUB, which clears the controller's errors for a
    moment; the congestion mode goes through the command block
    (ring_$set_ccb).

  Status stored:
    status_$ok: the ring took the packet
    status_$io_controller_not_in_system: the unit is not initialized
    status_$network_data_length_too_large: data_len is over the
      driver's maximum
    status_$network_transmit_failed: the transmitter is not ready, or
      the send failed (with `ring8_controller', also when the copy into
      the controller took a parity error)
    status_$ring_controller_hardware_error: the transmitter stays busy,
      or a forced retry did not complete
    status_$network_memory_parity_error_during_transmit: a bus error
      that was a parity error (with `memory_parity', not with
      `ring8_controller')
}

procedure ring_$sendp(var socket: pinteger; hdr_pa: integer32;
                      hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                      in data_pages: univ pkt_$data_pages_t;
                      data_va: integer32; data_len: pinteger;
                      in flags: univ integer;
                      out xmit_status: ring_$csr_t;
                      out status_ret: status_$t);
  options(val_param);
%if ring8_controller %then
label
  transmit_retry, process_status, hw_error, ok_count, ok_status, gate,
  retry_gate, transmit_done;
var
  data_buf: pkt_$data_pages_t;
  poll_now: time_$clock_t;
  deadline: time_$clock_t;
  attempt_start: time_$clock_t;
  wait_status: status_$t;
  ec_target_cell: integer32;
  errs: pinteger;
  dma_data_len: integer;
  retry_budget: integer;
  unit_data: ring_$unit_ptr_t;
  stats: ring_$stats_ptr_t;
  hw: ring8_$csr_ptr_t;
  tx_ec_target: integer32;
  hw_status: ring8_$csr_set_t;
  ctlr_word: pinteger;
  force_start: boolean;
  activity: boolean;
  no_retry: boolean;
begin
  unit_data := addr(ring_$ctl[socket]);
  stats := addr(ring_$data[socket]);
  xmit_status := [];

  { the refusals }
  if not unit_data^.initialized then begin
    xmit_status := xmit_status + [ring_sendp_res_not_ready];
    status_ret.all := status_$io_controller_not_in_system;
    return;
  end;
  if data_len > ring_$driver.max_data_len then begin
    status_ret.all := status_$network_data_length_too_large;
    return;
  end;
  status_ret.all := status_$network_transmit_failed;
  hw := unit_data^.hw_regs;
  if 7 in hw^.command then begin
    xmit_status := xmit_status + [ring_sendp_res_not_ready];
    return;
  end;

  retry_budget := 20;
  if stats^.last_success then
    retry_budget := 10;
  errs := 0;
  force_start := false;
  activity := false;
  no_retry := (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
              or odd(flags);
  stats^.xmit_call := stats^.xmit_call + 1;
  stats^.retry_pending := false;

  if data_len = 0 then begin
    dma_data_len := 0;
    data_buf[1] := hdr_pa;
  end
  else begin
    dma_data_len := data_len;
    data_buf := data_pages;
  end;

  if network_$do_chksum then
    hdr^.zero_0d := hdr_chksum(hdr^, hdr_len)
  else
    hdr^.zero_0d := 1;

transmit_retry:
  { the packet into the controller }
  tx_ec_target := unit_data^.tx_ec.value + 1;
  ml_$exclusion_start(unit_data^.buf_lock);
  wait_status.all := ring_$setup_tx(hdr, hdr_len, hdr_pa, data_buf, data_va,
                                    dma_data_len, hw^, socket);
  if wait_status.all = status_$network_memory_parity_error_during_transmit
  then begin
    ml_$exclusion_stop(unit_data^.buf_lock);
    goto transmit_done;
  end;
  if wait_status.all <> 0 then
    crash_system(wait_status);
  if unit_data^.ctlr_type = ring8_ctlr_128k then
    ml_$exclusion_stop(unit_data^.buf_lock);

  if not stats^.retry_pending then begin
    { start, and poll until the poll time-out or the ring has it }
    hw^.command := [9];
    time_$abs_clock(attempt_start);
    deadline := attempt_start;
    add48(deadline, ring_$poll_timeout);
    repeat
      if tx_ec_target <= unit_data^.tx_ec.value then
        goto process_status;
      time_$abs_clock(poll_now);
    until sub48(poll_now, deadline) or else (14 in hw^.status);
    { wait, a while at a time, for three more ticks of the high clock }
    deadline.high := attempt_start.high + 3;
    ring_$xmit_waited := ring_$xmit_waited + 1;
    repeat
      if 14 in hw^.status then
        exit;
      ec_target_cell := tx_ec_target;
      if time_$wait2(time_$relative, ring_$wait_interval, unit_data^.tx_ec,
                     ec_target_cell, wait_status) then
        goto process_status;
    until time_$clockh > deadline.high;
    { and until a little later }
    deadline := attempt_start;
    deadline.high := deadline.high + (attempt_start.low32 & 7);
    ec_target_cell := tx_ec_target;
    if time_$wait2(time_$absolute, deadline, unit_data^.tx_ec,
                   ec_target_cell, wait_status) then
      goto process_status;
  end
  else begin
    { a forced start }
    time_$abs_clock(ring_$force_start);
    discard(sub48(ring_$force_start, attempt_start));
    hw^.command := [9, 10];
    force_start := true;
    ec_target_cell := tx_ec_target;
    if time_$wait2(time_$relative, ring_$xmit_timeout1, unit_data^.tx_ec,
                   ec_target_cell, wait_status) then
      goto process_status;
  end;

  { stop the transmitter (rx_ptr read first) }
  ctlr_word := hw^.rx_ptr;
  hw^.command := [];
  if not (4 in hw^.command) then begin
    ec_target_cell := tx_ec_target;
    discard(time_$wait2(time_$relative, ring_$xmit_timeout2,
                        unit_data^.tx_ec, ec_target_cell, wait_status));
    if not (4 in hw^.command) then begin
      if unit_data^.ctlr_type = ring8_ctlr_16k then
        ml_$exclusion_stop(unit_data^.buf_lock);
      goto hw_error;
    end;
  end;
  if tx_ec_target <= unit_data^.tx_ec.value then
    goto process_status;
  if unit_data^.ctlr_type = ring8_ctlr_16k then
    ml_$exclusion_stop(unit_data^.buf_lock);
  if stats^.retry_pending then begin
  hw_error:
    status_ret.all := status_$ring_controller_hardware_error;
    goto transmit_done;
  end;

  { a time-out, retried }
  if force_start then
    goto transmit_done;
  stats^.xmit_tim := stats^.xmit_tim + 1;
  if (not stats^.congestion_flag) and stats^.biphase_flag then begin
    stats^.congestion_flag := true;
    xmit_status := xmit_status + [ring_sendp_res_congested];
    ring_$ccb[socket].mode := 8;
    wait_status.all := ring_$set_ccb(socket, true);
    if wait_status.all <> 0 then
      crash_system(wait_status);
  end;
  stats^.retry_pending := true;
  goto transmit_retry;

process_status:
  if unit_data^.ctlr_type = ring8_ctlr_16k then
    ml_$exclusion_stop(unit_data^.buf_lock);
%if ring_xmit_light %then
  mmu_$mcr_change(8);
%endif
  hw_status := hw^.command * [8..15];
  if hw_status = [12, 14] then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    stats^.xmitcnt := stats^.xmitcnt + 1;
    activity := true;
    network_$activity_flag := activity;
    goto ok_status;
  end;

  poll_now.high := 0;
  poll_now.low := 500;
  if hw_status * [8, 9] = [8, 9] then begin
    xmit_status := xmit_status + [ring_sendp_res_overrun];
    stats^.xmit_orun := stats^.xmit_orun + 1;
    goto retry_gate;
  end;

  if 15 in hw_status then begin
    if hw_status * [11..14] <> [] then begin
      if hw_status * [11..14] = [11] then begin
        { an error status: every third in a row scrubs the ring }
        ring_$from_err[socket] := ring_$from_err[socket] + 1;
        errs := errs + 1;
        if errs >= 3 then begin
          errs := 0;
          ring_$scrub[socket] := ring_$scrub[socket] + 1;
          hw^.status := [8, 11];
          time_$wait(time_$relative, ring_$scrub_delay, wait_status);
          hw^.status := [11];
        end;
      end;
      xmit_status := xmit_status + [ring_sendp_res_delayed];
      stats^.xmit_nortn := stats^.xmit_nortn + 1;
      goto gate;
    end;
    if 10 in hw_status then begin
      xmit_status := xmit_status + [ring_sendp_res_no_return];
      stats^.xmit_apar := stats^.xmit_apar + 1;
    end;
    goto gate;
  end;

  activity := true;
  network_$activity_flag := activity;
  if hw_status * [11, 12] = [11, 12] then begin
    xmit_status := xmit_status + [ring_sendp_res_no_return];
    stats^.xmit_error := stats^.xmit_error + 1;
    goto gate;
  end;
  if 14 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    goto ok_count;
  end;
  if 13 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_wack];
    stats^.xmit_wack := stats^.xmit_wack + 1;
    poll_now.low32 := 500;
    goto retry_gate;
  end;
  if not (12 in hw_status) then begin
    xmit_status := xmit_status + [ring_sendp_res_nack];
    if (hdr^.dest_node <> 0) and then (hdr^.dest_node <= 4) then begin
    ok_count:
      stats^.xmitcnt := stats^.xmitcnt + 1;
    ok_status:
      status_ret.all := status_$ok;
      goto transmit_done;
    end;
    stats^.xmit_nack := stats^.xmit_nack + 1;
    poll_now.low32 := 250;
    goto retry_gate;
  end;

  if not (11 in hw_status) then
    ring_$unexpected_xmit_stat := pinteger(hw_status);
  xmit_status := xmit_status + [ring_sendp_res_no_return];

gate:
  if no_retry then
    goto transmit_done;

retry_gate:
  retry_budget := retry_budget - 1;
  if retry_budget = 0 then
    goto transmit_done;
  if 1 in hdr^.flag_bits.info_bits then
    goto transmit_done;
  stats^.retry_pending := false;
  time_$wait(time_$relative, poll_now, wait_status);
  goto transmit_retry;

transmit_done:
  stats^.last_success := not activity;
  if stats^.last_success then begin
    xmit_status := xmit_status + [ring_sendp_res_retried];
    stats^.biphase_flag := false;
  end;
  stats^.biphase_flag := force_start;
end;
%else
label
  transmit_retry, process_status, hw_error, ok_count, ok_status, gate,
  retry_gate, transmit_done;
var
  data_buf: pkt_$data_pages_t;
  poll_now: time_$clock_t;
  deadline: time_$clock_t;
  attempt_start: time_$clock_t;
  wait_status: status_$t;
  ec_target_cell: integer32;
  dma_data_len: integer;
  unit_data: ring_$unit_ptr_t;
  stats: ring_$stats_ptr_t;
  hw: ring_$regs_ptr_t;
  tx_ec_target: integer32;
  hw_status: ring_$csr_t;
  retry_budget: integer;
  force_start: boolean;
  activity: boolean;
  no_retry: boolean;
%if ring_board_dma %then
  cmd: integer;
%elseif memory_parity %then
  parity_err: boolean;
%endif
begin
  unit_data := addr(ring_$ctl[socket]);
  stats := addr(ring_$data[socket]);
  xmit_status := [];

  { the refusals }
  if not unit_data^.initialized then begin
    xmit_status := xmit_status + [ring_sendp_res_not_ready];
    status_ret.all := status_$io_controller_not_in_system;
    return;
  end;
  if data_len > ring_$driver.max_data_len then begin
    status_ret.all := status_$network_data_length_too_large;
    return;
  end;
  status_ret.all := status_$network_transmit_failed;
  hw := unit_data^.hw_regs;
%if ring_board_dma %then
  if not (14 in hw^.rx_status) then begin
%else
  if not (13 in hw^.mode) then begin
%endif
    xmit_status := xmit_status + [ring_sendp_res_not_ready];
    return;
  end;

  retry_budget := 20;
  if stats^.last_success then
    retry_budget := 10;
  force_start := false;
  activity := false;
  no_retry := (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
              or odd(flags);
  stats^.xmit_call := stats^.xmit_call + 1;
  stats^.retry_pending := false;

  if data_len = 0 then begin
    dma_data_len := 0;
    data_buf[1] := hdr_pa;
  end
  else begin
    dma_data_len := data_len;
    data_buf := data_pages;
  end;

  if network_$do_chksum then
    hdr^.zero_0d := hdr_chksum(hdr^, hdr_len)
  else
    hdr^.zero_0d := 1;

transmit_retry:
  tx_ec_target := unit_data^.tx_ec.value + 1;
%if ring_controller_dma %then
  ring_$setup_tx_dma(hw^, hdr_pa, hdr_len, data_buf[1], dma_data_len);
%elseif ring_board_dma %then
  ring_$setup_tx_dma(hw^.tx_dma, ring_$ctl[socket].dma_page, hdr_pa,
                     hdr_len, data_buf[1], dma_data_len);
%else
  ring_$setup_tx_dma(hdr_pa, hdr_len, data_buf[1], dma_data_len);
%endif
  if not stats^.retry_pending then begin
    { start, and poll until the poll time-out }
%if ring_board_dma %then
    cmd := 16#81;
    if dma_data_len = 0 then
      cmd := 16#91;
    hw^.tx_cmd := cmd;
%else
    hw^.xmit_csr := [13, 14];
%endif
    time_$abs_clock(attempt_start);
    deadline := attempt_start;
    add48(deadline, ring_$poll_timeout);
    repeat
      if tx_ec_target <= unit_data^.tx_ec.value then
        goto process_status;
      time_$abs_clock(poll_now);
    until sub48(poll_now, deadline);
    { wait until the wait time-out }
    deadline := attempt_start;
    add48(deadline, ring_$wait_timeout);
    ring_$xmit_waited := ring_$xmit_waited + 1;
    ec_target_cell := tx_ec_target;
    if time_$wait2(time_$absolute, deadline, unit_data^.tx_ec,
                   ec_target_cell, wait_status) then
      goto process_status;
    { and until a little later }
    deadline := attempt_start;
    deadline.high := deadline.high + (attempt_start.low32 & 7);
    ec_target_cell := tx_ec_target;
    if time_$wait2(time_$absolute, deadline, unit_data^.tx_ec,
                   ec_target_cell, wait_status) then
      goto process_status;
  end
  else begin
    { a forced start }
    time_$abs_clock(ring_$force_start);
    discard(sub48(ring_$force_start, attempt_start));
%if ring_board_dma %then
    cmd := 16#A1;
    if dma_data_len = 0 then
      cmd := 16#B1;
    hw^.tx_cmd := cmd;
%else
    hw^.xmit_csr := [12, 13, 14];
%endif
    force_start := true;
    ec_target_cell := tx_ec_target;
    if time_$wait2(time_$relative, ring_$xmit_timeout1, unit_data^.tx_ec,
                   ec_target_cell, wait_status) then
      goto process_status;
  end;

  { abort the transmitter }
%if ring_board_dma %then
  hw^.tx_cmd := 16#41;
  if 15 in hw^.tx_status then begin
    ec_target_cell := tx_ec_target;
    discard(time_$wait2(time_$relative, ring_$xmit_timeout2,
                        unit_data^.tx_ec, ec_target_cell, wait_status));
    if 15 in hw^.tx_status then
      goto hw_error;
  end;
%else
  hw^.xmit_csr := [14];
  if 13 in hw^.xmit_csr then begin
    ec_target_cell := tx_ec_target;
    discard(time_$wait2(time_$relative, ring_$xmit_timeout2,
                        unit_data^.tx_ec, ec_target_cell, wait_status));
    if 13 in hw^.xmit_csr then
      goto hw_error;
  end;
%endif
  if tx_ec_target <= unit_data^.tx_ec.value then
    goto process_status;
%if not ring_controller_dma and not ring_board_dma %then
  ring_$clear_dma_channel(2, socket);
%endif
  if stats^.retry_pending then begin
  hw_error:
    status_ret.all := status_$ring_controller_hardware_error;
    goto transmit_done;
  end;

  { a time-out, retried }
  if force_start then
    goto transmit_done;
  stats^.xmit_tim := stats^.xmit_tim + 1;
  if (not stats^.congestion_flag) and stats^.biphase_flag then begin
    stats^.congestion_flag := true;
    xmit_status := xmit_status + [ring_sendp_res_congested];
%if ring_board_dma %then
    hw^.tx_cmd := 4;
%else
    if 14 in hw^.mode then
      hw^.mode := [11, 13, 14]
    else
      hw^.mode := [11, 13];
%endif
  end;
  stats^.retry_pending := true;
  goto transmit_retry;

process_status:
%if ring_board_dma %then
%if ring_xmit_light %then
  mmu_$mcr_change(8);
%endif
  hw_status := hw^.tx_status;
  if hw_status = [3, 6, 7] then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    stats^.xmitcnt := stats^.xmitcnt + 1;
    activity := true;
    network_$activity_flag := activity;
    goto ok_status;
  end;

  poll_now.high := 0;
  poll_now.low := 500;
  if hw_status * [0, 1] <> [] then begin
    if 0 in hw_status then begin
      xmit_status := xmit_status + [ring_sendp_res_biphase];
      ring_$xmit_biphase := ring_$xmit_biphase + 1;
    end;
    if 1 in hw_status then begin
      xmit_status := xmit_status + [ring_sendp_res_esb];
      ring_$xmit_esb := ring_$xmit_esb + 1;
    end;
    stats^.xmit_modem := stats^.xmit_modem + 1;
  end;

  if 9 in hw_status then begin
    crash_system(status_$network_transmit_bus_error);
    xmit_status := xmit_status + [ring_sendp_res_bus_err];
    stats^.xmit_bus := stats^.xmit_bus + 1;
    goto retry_gate;
  end;

  if 8 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_overrun];
    stats^.xmit_orun := stats^.xmit_orun + 1;
    goto retry_gate;
  end;
  if hw_status * [7, 12] <> [7] then begin
    xmit_status := xmit_status + [ring_sendp_res_delayed];
    stats^.xmit_nortn := stats^.xmit_nortn + 1;
    goto gate;
  end;
  if not (6 in hw_status) then begin
    xmit_status := xmit_status + [ring_sendp_res_no_return];
    stats^.xmit_apar := stats^.xmit_apar + 1;
    goto gate;
  end;

  activity := true;
  network_$activity_flag := activity;
  if hw_status * [4, 5] = [5] then begin
    xmit_status := xmit_status + [ring_sendp_res_no_return];
    stats^.xmit_error := stats^.xmit_error + 1;
    goto gate;
  end;
  if 3 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    goto ok_count;
  end;
  if 2 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_wack];
    stats^.xmit_wack := stats^.xmit_wack + 1;
    poll_now.low32 := 500;
    goto retry_gate;
  end;
  if 4 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_nack];
    if (hdr^.dest_node <> 0) and then (hdr^.dest_node <= 4) then begin
    ok_count:
      stats^.xmitcnt := stats^.xmitcnt + 1;
    ok_status:
      status_ret.all := status_$ok;
      goto transmit_done;
    end;
    stats^.xmit_nack := stats^.xmit_nack + 1;
    poll_now.low32 := 250;
    goto retry_gate;
  end;

  if not (5 in hw_status) then
    ring_$unexpected_xmit_stat := pinteger(hw_status);
  xmit_status := xmit_status + [ring_sendp_res_no_return];
%else
%if ring_xmit_light %then
%if ring_lights_8_4 %then
  mmu_$mcr_change(8);
%else
  mmu_$mcr_change(4);
%endif
%endif
  hw_status := hw^.xmit_csr;
%if not ring_controller_dma %then
  ring_$clear_dma_channel(2, socket);
%endif
  if hw_status = [2, 4] then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    stats^.xmitcnt := stats^.xmitcnt + 1;
    activity := true;
    network_$activity_flag := activity;
    goto ok_status;
  end;

  poll_now.high := 0;
  poll_now.low := 500;
  if hw_status * [10, 11] <> [] then begin
    if 11 in hw_status then begin
      xmit_status := xmit_status + [ring_sendp_res_biphase];
      ring_$xmit_biphase := ring_$xmit_biphase + 1;
    end;
    if 10 in hw_status then begin
      xmit_status := xmit_status + [ring_sendp_res_esb];
      ring_$xmit_esb := ring_$xmit_esb + 1;
    end;
    stats^.xmit_modem := stats^.xmit_modem + 1;
  end;

  if 6 in hw_status then begin
%if memory_parity %then
    parity_err := parity_$chk_io(rshft(hdr_pa, 10), rshft(data_buf[1], 10))
                  = 2;
    if parity_err then begin
      status_ret.all := status_$network_memory_parity_error_during_transmit;
      goto transmit_done;
    end;
%endif
    xmit_status := xmit_status + [ring_sendp_res_bus_err];
    stats^.xmit_bus := stats^.xmit_bus + 1;
    goto retry_gate;
  end;

  if 0 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_overrun];
    stats^.xmit_orun := stats^.xmit_orun + 1;
    goto retry_gate;
  end;
  if hw_status * [5, 9] <> [] then begin
    xmit_status := xmit_status + [ring_sendp_res_delayed];
    stats^.xmit_nortn := stats^.xmit_nortn + 1;
    goto gate;
  end;
  if 7 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_no_return];
    stats^.xmit_apar := stats^.xmit_apar + 1;
    goto gate;
  end;

  activity := true;
  network_$activity_flag := activity;
  if hw_status * [3, 4] = [3, 4] then begin
    xmit_status := xmit_status + [ring_sendp_res_no_return];
    stats^.xmit_error := stats^.xmit_error + 1;
    goto gate;
  end;
  if 2 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_ok];
    goto ok_count;
  end;
  if 1 in hw_status then begin
    xmit_status := xmit_status + [ring_sendp_res_wack];
    stats^.xmit_wack := stats^.xmit_wack + 1;
    poll_now.low32 := 500;
    goto retry_gate;
  end;
  if not (4 in hw_status) then begin
    xmit_status := xmit_status + [ring_sendp_res_nack];
    if (hdr^.dest_node <> 0) and then (hdr^.dest_node <= 4) then begin
    ok_count:
      stats^.xmitcnt := stats^.xmitcnt + 1;
    ok_status:
      status_ret.all := status_$ok;
      goto transmit_done;
    end;
    stats^.xmit_nack := stats^.xmit_nack + 1;
    poll_now.low32 := 250;
    goto retry_gate;
  end;

  if not (3 in hw_status) then
    ring_$unexpected_xmit_stat := pinteger(hw_status);
  xmit_status := xmit_status + [ring_sendp_res_no_return];

%endif

gate:
  if no_retry then
    goto transmit_done;

retry_gate:
  retry_budget := retry_budget - 1;
  if retry_budget = 0 then
    goto transmit_done;
  if 1 in hdr^.flag_bits.info_bits then
    goto transmit_done;
  stats^.retry_pending := false;
  time_$wait(time_$relative, poll_now, wait_status);
  goto transmit_retry;

transmit_done:
  stats^.last_success := not activity;
  if stats^.last_success then begin
    xmit_status := xmit_status + [ring_sendp_res_retried];
    stats^.biphase_flag := false;
  end;
  stats^.biphase_flag := force_start;
end;
%endif
