{ RING_$RCV_FROM_UNIT_PRIV - a ring unit's receive process.

  Image addresses:
    sau2  0x00E76048  RING_$RCV_FROM_UNIT_PRIV (module-local)
    sau2  0x00E75DE4  ring_$validate_receive (nested)
    sau4  0x0F883928  RING_$RCV_FROM_UNIT_PRIV (module-local)
    sau4  0x0F88366C  ring_$validate_receive (nested)
    sau5  0x00E7D30C  RING_$RCV_FROM_UNIT_PRIV (module-local)
    sau5  0x00E7D0A8  ring_$validate_receive (nested)
    sau8  0x03C8281E  RING_$RCV_FROM_UNIT_PRIV (module-local)
    sau9  0x3C47E410  RING_$RCV_FROM_UNIT_PRIV (module-local)
    sau8  0x03C82496  ring_$rearm_rx (nested)
    sau9  0x3C47E088  ring_$rearm_rx (nested)
    sau8  0x03C82540  ring_$validate_receive (nested)
    sau9  0x3C47E132  ring_$validate_receive (nested)

  - A process's body: it never returns.  Holding the server lock, it
    arms the receiver, tells its starter it is up (the first time), and
    hands each good packet to ring_$receive_packet.
  - A busy unit whose receiver stays active is reset; if it stays busy,
    the system crashes.  A bad checksum or a receive bus error crashes
    it too (ring_$validate_receive).
  - ring_$validate_receive (nested) checks a packet and counts its
    errors, reaching its parent's frame for every object.
  - With the controller with buffers of its own (`ring8_controller')
    the process takes the unit's buffers in turn: it copies each full
    one out (ring_$copy_rx), checks it and hands it on, frees it, and
    restarts a receive the interrupt stopped for want of a buffer
    (ring_$rearm_rx, nested); a changed transmit mask goes to the
    controller's command block first.  The first time round it starts
    the receive on its first buffer.  A receive error resets the
    controller's error word; a header checksum error crashes the
    system; ring_$rearm_rx crashes it with status_$network_buffer_error
    for a buffer still full.
  - With the board's own DMA (`ring_board_dma') the receiver is armed
    and reset with command bytes and its status word, the lengths are
    the receive channels' counts, and the status bits are the
    controller's own; the congestion flag is left alone.

  Status stored: none.
}

procedure ring_$rcv_from_unit_priv(unit: integer); internal;
%if ring8_controller %then
label
  no_mask;
var
  data_pages: pkt_$data_pages_t;
  regs: ring8_$csr_ptr_t;
  hdr: integer32;
  no_data: integer32;
  ccb_status: status_$t;
  restart_idx: pinteger;
  rcv_data_len: integer;
  rcv_hdr_len: integer;
  hdr_cksum: integer;
  hdr_hdr_len: integer;
  hdr_data_len: integer;
  hdr_pkt_class: integer;
  rcv_status: ring8_$csr_set_t;
  overrun_seen: boolean;
  wait_val: integer32;
  armed: boolean;
  first_time: boolean;
  taken: boolean;
  unit_data: ring_$unit_ptr_t;
  buf: ring8_$rx_buf_ptr_t;
  next_idx: pinteger;
  prev_idx: pinteger;
  i: integer;

  { ring_$rearm_rx: give the controller a unit's buffer and start the
    receive. }
  procedure ring_$rearm_rx(var u: ring_$unit_t; var idx: pinteger);
  var
    b: ring8_$rx_buf_ptr_t;
  begin
    b := addr(u.rx_bufs[idx]);
    if 6 in rcv_status then
      crash_system(status_$network_buffer_error);
    if b^.full then
      crash_system(status_$network_buffer_error);
    if b^.hdr_pa = 0 then
      netbuf_$get_hdr(b^.hdr_pa, b^.hdr_va);
    b^.copied := false;
    b^.hdr_len := 0;
    b^.data_len := 0;
    ring_$set_rx_buffer(b^.ctlr_addr, regs^, u.max_data_words + 512);
    u.rx_index := idx;
    b^.armed := true;
    u.rx_stopped := false;
    regs^.status := [11];
    regs^.rx_status := [11];
  end;

  { ring_$validate_receive: check a received packet, count its errors. }
  function ring_$validate_receive: boolean;
  var
    valid: boolean;
    is_swdiag: boolean;
    b: ring8_$rx_buf_ptr_t;
  begin
    valid := false;
    with ring_$data[unit] do begin
      b := addr(ring_$ctl[unit].rx_bufs[ring_$ctl[unit].rx_next]);
      rcv_status := b^.rx_status;
      rcv_hdr_len := b^.hdr_len;
      rcv_data_len := b^.data_len;
      rcv_status := rcv_status * [2..4, 8..11, 15];
      if not (10 in b^.status) and then (rcv_status = [])
         and then (5 in b^.rx_status) then begin
        { the lengths }
        hdr_pkt_class := ring_$hdr_ptr_t(hdr)^.pkt_class;
        hdr_cksum := ring_$hdr_ptr_t(hdr)^.chksum;
        hdr_hdr_len := ring_$hdr_ptr_t(hdr)^.hdr_len;
        hdr_data_len := ring_$hdr_ptr_t(hdr)^.data_len;
        rcv_data_len := rcv_data_len - (hdr_data_len & 1);
        rcv_hdr_len := rcv_hdr_len - (hdr_hdr_len & 1);
        if hdr_data_len = 0 then
          rcv_data_len := 0;
        if (rcv_data_len <> hdr_data_len)
           or else (rcv_hdr_len <> hdr_hdr_len) then
          ring_$bad_data_cnt := ring_$bad_data_cnt + 1
        else if ((hdr_cksum <> 1) and network_$do_chksum)
                and then not (0 in ring_$hdr_ptr_t(hdr)^.flags.info_bits)
                and then (hdr_chksum(ring_$hdr_ptr_t(hdr)^, hdr_hdr_len)
                          <> hdr_cksum) then begin
          crash_system(status_$network_bad_checksum);
          rcvhcsum := rcvhcsum + 1;
        end
        else begin
          valid := true;
          rcvcnt := rcvcnt + 1;
        end;
      end

      else if (ring_$hdr_ptr_t(hdr)^.msg_type.node = 1)
              or else (ring_$hdr_ptr_t(hdr)^.msg_type.node = 3) then begin
        { a failure report }
        network_$failure_rec.timestamp := time_$current_clockh;
        network_$failure_rec.node_id := ring_$hdr_ptr_t(hdr)^.src_id.node;
        network_$failure_rec.flag := true;
        network_$failure_rec.failure_type :=
          ring_$hdr_ptr_t(hdr)^.msg_type.node;
      end

      else begin
        { the receive errors }
        is_swdiag := (1 in ring_$hdr_ptr_t(hdr)^.flags.info_bits)
                     and then (4 in ring_$hdr_ptr_t(hdr)^.flags.info_bits);
        if (10 in b^.status) or else (3 in rcv_status)
           or else (4 in rcv_status) then begin
          regs^.reg_0406 := 1;
          if 3 in rcv_status then
            ring_$rcv_esb := ring_$rcv_esb + 1;
          if 4 in rcv_status then
            ring_$rcv_biphase := ring_$rcv_biphase + 1;
          rcvpkt := rcvpkt + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvpkt := ring_$swdiag_data.rcvpkt + 1;
        end
        else if 15 in rcv_status then begin
          rcvtim := rcvtim + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvtim := ring_$swdiag_data.rcvtim + 1;
        end
        else if not (5 in b^.rx_status) then begin
          ring_$busy_on_rcv_int := ring_$busy_on_rcv_int + 1;
          rcvbus := rcvbus + 1;
        end
        else if 2 in rcv_status then begin
          rcveor := rcveor + 1;
          if is_swdiag then
            ring_$swdiag_data.rcveor := ring_$swdiag_data.rcveor + 1;
        end
        else if 8 in rcv_status then begin
          if (regs^.ctlr_id & 16#F7FF) = 16#1000 then
            overrun_seen := true;
          if overrun_seen
             and then (ring_$ctl[unit].ctlr_type = ring8_ctlr_128k) then begin
            regs^.reg_0806 := 1;
            overrun_seen := false;
            rcvovr := rcvovr + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvovr := ring_$swdiag_data.rcvovr + 1;
          end
          else begin
            rcvapar := rcvapar + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvapar := ring_$swdiag_data.rcvapar + 1;
          end;
        end
        else begin
          if 11 in rcv_status then begin
            rcvcrc := rcvcrc + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvcrc := ring_$swdiag_data.rcvcrc + 1;
          end;
          if 9 in rcv_status then begin
            rcvxerr := rcvxerr + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvxerr := ring_$swdiag_data.rcvxerr + 1;
          end
          else if 10 in rcv_status then begin
            rcvmodem := rcvmodem + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvmodem := ring_$swdiag_data.rcvmodem + 1;
          end;
        end;
      end;
    end;

    ring_$validate_receive := valid;
  end;

begin
  first_time := true;
  proc1_$set_lock(ml_$server_lock);
  for i := 1 to 4 do
    netbuf_$get_dat(data_pages[i]);

  { the first buffer }
  unit_data := addr(ring_$ctl[unit]);
  buf := addr(unit_data^.rx_bufs[unit_data^.rx_next]);
  regs := unit_data^.hw_regs;
  if buf^.hdr_pa = 0 then
    netbuf_$get_hdr(buf^.hdr_pa, buf^.hdr_va);
  buf^.copied := false;
  buf^.hdr_len := 0;
  buf^.data_len := 0;
  ring_$set_rx_buffer(buf^.ctlr_addr, regs^,
                      unit_data^.max_data_words + 512);
  armed := false;
  wait_val := ring_$ctl[unit].rx_wake_ec.value + 1;

  repeat
    unit_data := addr(ring_$ctl[unit]);
    buf := addr(unit_data^.rx_bufs[unit_data^.rx_next]);

    { a changed transmit mask }
    if ring_unit_busy in unit_data^.state_flags then begin
      ml_$lock(ml_$net_io_lock);
      ring_$ccb[unit].tmask := unit_data^.tmask;
      ccb_status.all := ring_$set_ccb(unit, true);
      unit_data^.state_flags := unit_data^.state_flags - [ring_unit_busy];
      ml_$unlock(ml_$net_io_lock);
      if ccb_status.all <> 0 then
        crash_system(ccb_status);
    end;

    if buf^.full then begin
      { the packet }
      hdr := buf^.hdr_va;
      ring_$copy_rx(buf^, unit_data^, data_pages);
      if ring_$validate_receive then begin
        network_$activity_flag := true;
        if hdr_data_len > 0 then begin
          ring_$receive_packet(unit, hdr, data_pages[1], rcv_hdr_len,
                               rcv_data_len);
          for i := 1 to rshft(hdr_data_len + 1023, 10) do
            netbuf_$get_dat(data_pages[i]);
        end
        else begin
          no_data := 0;
          ring_$receive_packet(unit, hdr, no_data, rcv_hdr_len,
                               rcv_data_len);
        end;
      end
      else begin
        ring_$abort_cnt := ring_$abort_cnt + 1;
        netbuf_$rtn_hdr(buf^.hdr_va);
      end;

      { the buffer freed, the next one the process's }
      buf^.hdr_pa := 0;
      buf^.copied := false;
      if unit_data^.rx_next >= unit_data^.rx_buf_cnt then
        unit_data^.rx_next := 1
      else
        unit_data^.rx_next := unit_data^.rx_next + 1;
      if taken then
        wait_val := wait_val + 1;
      taken := true;

      { a stopped receive restarted }
      disable;
      buf^.full := false;
      if unit_data^.rx_stopped and then (unit_data^.tmask <> 0) then begin
        enable;
        if unit_data^.rx_index >= unit_data^.rx_buf_cnt then
          next_idx := 1
        else
          next_idx := unit_data^.rx_index + 1;
        if unit_data^.rx_next = 1 then
          prev_idx := unit_data^.rx_buf_cnt
        else
          prev_idx := unit_data^.rx_next - 1;
        if next_idx = prev_idx then
          ring_$post_cnt1 := ring_$post_cnt1 + 1
        else
          ring_$post_cnt2 := ring_$post_cnt2 + 1;
        restart_idx := next_idx;
        ring_$rearm_rx(unit_data^, restart_idx);
        next;
      end;
      enable;
      next;
    end;

    { the receive: started the first time, restarted when stopped }
    if not buf^.armed and then armed then begin
      if buf^.full then
        next;
      if unit_data^.rx_stopped then begin
        if unit_data^.tmask = 0 then
          goto no_mask;
        ring_$post_cnt3 := ring_$post_cnt3 + 1;
        ring_$rearm_rx(unit_data^, unit_data^.rx_next);
        next;
      end;
      crash_system(status_$network_buffer_error);
    end;
    if unit_data^.tmask <> 0 then begin
      regs^.status := [11];
      if not armed then begin
        unit_data^.rx_index := unit_data^.rx_next;
        buf^.armed := true;
        unit_data^.rx_stopped := false;
        armed := true;
        regs^.rx_status := [11];
      end;
    end
    else begin
    no_mask:
      regs^.status := [];
    end;

    { the wait }
    taken := false;
    if first_time then begin
      ec_$advance(unit_data^.ready_ec);
      first_time := false;
    end;
    discard(ec_$wait(addr(unit_data^.rx_wake_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), wait_val, 0, 0));
    wait_val := wait_val + 1;
    ring_$wakeup_cnt := ring_$wakeup_cnt + 1;
  until false;
end;
%else
var
  status: status_$t;
  hw_regs: ring_$regs_ptr_t;
  delay: time_$clock_t;
  hdr: integer32;
  data_pa: integer32;
  rcv_data_len: integer;
  rcv_hdr_len: integer;
  hdr_cksum: integer;
  hdr_hdr_len: integer;
  hdr_data_len: integer;
  hdr_pkt_class: integer;
  rcv_status: ring_$csr_t;
  first_time: boolean;
  wait_val: integer32;
  unit_data: ring_$unit_ptr_t;

  { ring_$validate_receive: check a received packet, count its errors. }
  function ring_$validate_receive: boolean;
  var
    valid: boolean;
    is_swdiag: boolean;
  begin
    valid := false;
    with ring_$data[unit] do begin
%if ring_board_dma %then
      rcv_status := hw_regs^.rx_status - [14];
      if rcv_status = [6, 7] then begin
        { the lengths: the receive channels' counts, read low byte
          first }
        hw_regs^.rx_dma.clear_ff := 0;
        rcv_hdr_len := hw_regs^.rx_dma.chan[0].count;
        rcv_hdr_len := (512 - (hw_regs^.rx_dma.chan[0].count * 256
                               + rcv_hdr_len + 1)) * 2;
        rcv_data_len := hw_regs^.rx_dma.chan[1].count;
        rcv_data_len := (512 - (hw_regs^.rx_dma.chan[1].count * 256
                                + rcv_data_len + 1)) * 2;
%else
      rcv_status := hw_regs^.rcv_csr;
      if rcv_status - [1, 2, 4] = [] then begin
        { the lengths }
%if ring_controller_dma %then
        rcv_hdr_len := (hw_regs^.rx_hdr_resid & 16#3FF) * 2;
        rcv_data_len := (hw_regs^.rx_data_resid & 16#3FF) * 2;
%else
        rcv_hdr_len := 1024 - dma[0].mtc * 2;
        rcv_data_len := 1024 - dma[1].mtc * 2;
%endif
%endif
        hdr_pkt_class := ring_$hdr_ptr_t(hdr)^.pkt_class;
        hdr_cksum := ring_$hdr_ptr_t(hdr)^.chksum;
        hdr_hdr_len := ring_$hdr_ptr_t(hdr)^.hdr_len;
        hdr_data_len := ring_$hdr_ptr_t(hdr)^.data_len;
        rcv_data_len := rcv_data_len - (hdr_data_len & 1);
        rcv_hdr_len := rcv_hdr_len - (hdr_hdr_len & 1);
        if hdr_data_len = 0 then
          rcv_data_len := 0;
        if (rcv_data_len <> hdr_data_len)
           or else (rcv_hdr_len <> hdr_hdr_len) then
          ring_$bad_data_cnt := ring_$bad_data_cnt + 1
        else if ((hdr_cksum <> 1) and network_$do_chksum)
                and then not (0 in ring_$hdr_ptr_t(hdr)^.flags.info_bits)
                and then (hdr_chksum(ring_$hdr_ptr_t(hdr)^, hdr_hdr_len)
                          <> hdr_cksum) then begin
          crash_system(status_$network_bad_checksum);
          rcvhcsum := rcvhcsum + 1;
        end
        else begin
          valid := true;
          rcvcnt := rcvcnt + 1;
        end;
      end

      else if (ring_$hdr_ptr_t(hdr)^.msg_type.node = 1)
              or else (ring_$hdr_ptr_t(hdr)^.msg_type.node = 3) then begin
        { a failure report }
        network_$failure_rec.timestamp := time_$current_clockh;
        network_$failure_rec.node_id := ring_$hdr_ptr_t(hdr)^.src_id.node;
        network_$failure_rec.flag := true;
        network_$failure_rec.failure_type :=
          ring_$hdr_ptr_t(hdr)^.msg_type.node;
      end

      else begin
        { the receive errors }
        is_swdiag := (1 in ring_$hdr_ptr_t(hdr)^.flags.info_bits)
                     and then (4 in ring_$hdr_ptr_t(hdr)^.flags.info_bits);
%if ring_board_dma %then
        if (1 in rcv_status) or else (0 in rcv_status) then begin
          if 1 in rcv_status then
            ring_$rcv_esb := ring_$rcv_esb + 1;
          if 0 in rcv_status then
            ring_$rcv_biphase := ring_$rcv_biphase + 1;
          rcvpkt := rcvpkt + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvpkt := ring_$swdiag_data.rcvpkt + 1;
        end
        else if 12 in rcv_status then begin
          rcvtim := rcvtim + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvtim := ring_$swdiag_data.rcvtim + 1;
        end
        else if 9 in rcv_status then begin
          crash_system(status_$network_receive_bus_error);
          rcvbus := rcvbus + 1;
        end
        else if not (7 in rcv_status) then begin
          rcvovr := rcvovr + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvovr := ring_$swdiag_data.rcvovr + 1;
        end
        else if 10 in rcv_status then begin
          rcveor := rcveor + 1;
          if is_swdiag then
            ring_$swdiag_data.rcveor := ring_$swdiag_data.rcveor + 1;
        end
        else if 8 in rcv_status then begin
          rcvapar := rcvapar + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvapar := ring_$swdiag_data.rcvapar + 1;
        end
        else begin
          if 13 in rcv_status then begin
            rcvcrc := rcvcrc + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvcrc := ring_$swdiag_data.rcvcrc + 1;
          end;
          if not (6 in rcv_status) then begin
            rcvxerr := rcvxerr + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvxerr := ring_$swdiag_data.rcvxerr + 1;
          end
          else if 5 in rcv_status then begin
            rcvmodem := rcvmodem + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvmodem := ring_$swdiag_data.rcvmodem + 1;
          end;
        end;
%else
        if (10 in rcv_status) or else (11 in rcv_status) then begin
          if 10 in rcv_status then
            ring_$rcv_esb := ring_$rcv_esb + 1;
          if 11 in rcv_status then
            ring_$rcv_biphase := ring_$rcv_biphase + 1;
          rcvpkt := rcvpkt + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvpkt := ring_$swdiag_data.rcvpkt + 1;
        end
        else if 9 in rcv_status then begin
          rcvtim := rcvtim + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvtim := ring_$swdiag_data.rcvtim + 1;
        end
        else if 6 in rcv_status then begin
          crash_system(status_$network_receive_bus_error);
          rcvbus := rcvbus + 1;
        end
        else if 5 in rcv_status then begin
          rcveor := rcveor + 1;
          if is_swdiag then
            ring_$swdiag_data.rcveor := ring_$swdiag_data.rcveor + 1;
        end
        else if 0 in rcv_status then begin
          rcvapar := rcvapar + 1;
          if is_swdiag then
            ring_$swdiag_data.rcvapar := ring_$swdiag_data.rcvapar + 1;
        end
        else begin
          if 8 in rcv_status then begin
            rcvcrc := rcvcrc + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvcrc := ring_$swdiag_data.rcvcrc + 1;
          end;
          if 7 in rcv_status then begin
            rcvxerr := rcvxerr + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvxerr := ring_$swdiag_data.rcvxerr + 1;
          end
          else if 3 in rcv_status then begin
            rcvmodem := rcvmodem + 1;
            if is_swdiag then
              ring_$swdiag_data.rcvmodem := ring_$swdiag_data.rcvmodem + 1;
          end;
        end;
%endif
      end;
    end;

    ring_$validate_receive := valid;
  end;

begin
  first_time := true;
  unit_data := addr(ring_$ctl[unit]);
  discard(io_$get_dcte(2, unit, status));
  if status.all <> 0 then
    crash_system(status);
  proc1_$set_lock(ml_$server_lock);

  hw_regs := unit_data^.hw_regs;
  wait_val := unit_data^.rx_wake_ec.value + 1;

  repeat
    { the buffers, the DMA }
    if unit_data^.rx_data_pa = 0 then
      netbuf_$get_dat(unit_data^.rx_data_pa);
    if unit_data^.rx_hdr_pa = 0 then
      netbuf_$get_hdr(unit_data^.rx_hdr_pa, unit_data^.rx_hdr);
%if ring_controller_dma %then
    ring_$setup_rx_dma(hw_regs^, unit_data^.rx_hdr_pa,
                       unit_data^.rx_data_pa);
%elseif ring_board_dma %then
    ring_$setup_rx_dma(hw_regs^.rx_dma, unit_data^.dma_page,
                       unit_data^.rx_hdr_pa, unit_data^.rx_data_pa);
%else
    ring_$setup_rx_dma(unit_data^.rx_hdr_pa, unit_data^.rx_data_pa);
%endif

    { the receiver }
    hw_regs^.tmask := unit_data^.tmask;
    unit_data^.state_flags := unit_data^.state_flags - [ring_unit_busy];
%if ring_board_dma %then
    if unit_data^.tmask <> 0 then
      hw_regs^.rx_cmd := 16#A1
    else
      hw_regs^.rx_cmd := 16#10;
%else
    if unit_data^.tmask <> 0 then begin
      hw_regs^.rcv_csr := [13, 14];
      hw_regs^.mode := [10, 13];
      ring_$data[unit].congestion_flag := false;
    end
    else
      hw_regs^.mode := [12];
%endif

    if first_time then begin
      ec_$advance(unit_data^.ready_ec);
      first_time := false;
    end;
    discard(ec_$wait(addr(unit_data^.rx_wake_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), wait_val, 0, 0));
    wait_val := wait_val + 1;
    ring_$wakeup_cnt := ring_$wakeup_cnt + 1;
    hdr := unit_data^.rx_hdr;

%if ring_board_dma %then
    if ring_unit_busy in unit_data^.state_flags then begin
      if 15 in hw_regs^.rx_status then begin
        { reset a stuck receiver }
        hw_regs^.rx_cmd := 16#40;
        if 15 in hw_regs^.rx_status then begin
          delay.high := 0;
          delay.low := 2750;
          time_$wait(time_$relative, delay, status);
          if status.all <> 0 then
            crash_system(status)
          else if 15 in hw_regs^.rx_status then
            crash_system(status_$network_receive_process_failed_to_start);
        end;
        next;
      end;
    end
    else if 15 in hw_regs^.rx_status then
      ring_$busy_on_rcv_int := ring_$busy_on_rcv_int + 1;
%else
    if ring_unit_busy in unit_data^.state_flags then begin
      if 13 in hw_regs^.rcv_csr then begin
        { reset a stuck receiver }
        hw_regs^.rcv_csr := [];
        if 13 in hw_regs^.rcv_csr then begin
          delay.high := 0;
          delay.low := 2750;
          time_$wait(time_$relative, delay, status);
          if status.all <> 0 then
            crash_system(status)
          else if 13 in hw_regs^.rcv_csr then
            crash_system(status_$network_receive_process_failed_to_start);
        end;
%if not ring_controller_dma %then
        ring_$clear_dma_channel(0, unit);
        ring_$clear_dma_channel(1, unit);
%endif
        next;
      end;
    end
    else if 13 in hw_regs^.rcv_csr then
      ring_$busy_on_rcv_int := ring_$busy_on_rcv_int + 1;
%endif

    { the packet }
%if not ring_controller_dma and not ring_board_dma %then
    ring_$clear_dma_channel(0, unit);
    ring_$clear_dma_channel(1, unit);
%endif
    if ring_$validate_receive then begin
      network_$activity_flag := true;
      if hdr_data_len > 0 then
        data_pa := unit_data^.rx_data_pa
      else
        data_pa := 0;
      ring_$receive_packet(unit, hdr, data_pa, rcv_hdr_len, rcv_data_len);
      unit_data^.rx_hdr_pa := 0;
      if data_pa <> 0 then
        unit_data^.rx_data_pa := 0;
    end
    else
      ring_$abort_cnt := ring_$abort_cnt + 1;
  until false;
end;
%endif
