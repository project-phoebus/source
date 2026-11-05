{ ring_$process_rx_packet - take a paging packet straight off the ring.

  Image addresses:
    sau2  0x00E75400  ring_$process_rx_packet (module-local)
    sau4  0x0F882C00  ring_$process_rx_packet (module-local)
    sau5  0x00E7C800  ring_$process_rx_packet (module-local)
    sau6  0x78083C00  ring_$process_rx_packet (module-local)
    sau7  0x3C48DEE6  ring_$process_rx_packet (module-local)
    sau8  0x03C816E6  ring_$process_rx_packet (module-local)
    sau9  0x3C47D2E6  ring_$process_rx_packet (module-local)

  - At interrupt level.  A packet the receive process must see (an
    error, logging on, lengths that do not match, the ring's own
    packets, no buffers) gets the unit's wake eventcount as the result.
  - Else it is delivered to its socket (SOCK_$PUT_INT_INT), fresh
    buffers taken, and the result is nil; no buffer crashes the system.
    A full paging socket is retried as socket 6.
  - RING_$SWDIAG_GOODRCV_CNT counts the software diagnostic's bad
    receives.
  - With the controller with buffers of its own (`ring8_controller')
    the packet is in the unit's current buffer: its lengths and status
    words are recorded, and a paging candidate's header copied out (not
    while RING_$SENDP holds the buffer lock); only a packet without data
    is delivered here, and the buffer, re-armed, stays the controller's.
    Any other packet is left in its buffer for the receive process and
    the controller given the next free one; with none, no transmit mask
    or no header pages, the unit's receive is marked stopped.  A packet
    arriving on a stopped unit crashes the system with
    status_$network_hardware_error.  RING_$SWDIAG_GOODRCV_CNT counts the
    diagnostic's good receives.
  - With the board's own DMA (`ring_board_dma') the lengths are the
    receive channels' counts and the channels are re-armed in place,
    their buffers mapped in the I/O map from the unit's dma_page.

  Status stored: none.
}

function ring_$process_rx_packet(var unit: ring_$unit_t):
  ec_$eventcount_ptr_t;
  internal;
%if ring8_controller %then
label
  retry, rearm, crash, to_process, stopped, wake;
var
  regs: ring8_$csr_ptr_t;
  buf: ring8_$rx_buf_ptr_t;
  hdr_len: pinteger;
  hdr: pkt_$hdr_ptr_t;
  forwarded: boolean;
  sock_num: pinteger;
  now: time_$clock_t;
  info: sock_$pkt_info_t;
  sock: sock_$sock_ptr_t;
  next: pinteger;
  next_buf: ring8_$rx_buf_ptr_t;
begin
  if unit.rx_stopped then begin
    crash_system(status_$network_hardware_error);
    goto stopped;
  end;

  { the buffer the packet is in }
  regs := unit.hw_regs;
  buf := addr(unit.rx_bufs[unit.rx_index]);
  buf^.copied := false;
  buf^.full := true;
  buf^.armed := false;
  buf^.rx_status := regs^.rx_status;
  buf^.status := regs^.status;
  hdr_len := ring_$read_timer(regs^, ring8_cnt_rx_hdr) + 4;
  buf^.hdr_len := hdr_len;
  buf^.data_len := ring_$read_timer(regs^, ring8_cnt_rx_data) + 1;

  if (5 in buf^.rx_status) and then (hdr_len <= 952)
     and then not ml_$exclusion_check(unit.buf_lock) then begin

    { the header }
    ring_$rb_from(regs^, buf^.ctlr_addr, univ_ptr(buf^.hdr_va),
                  hdr_len div 2);
    buf^.copied := true;
    hdr := pkt_$hdr_ptr_t(buf^.hdr_va);

    { the software diagnostic's counters }
    if (1 in hdr^.flag_bits.info_bits)
       and then (4 in hdr^.flag_bits.info_bits) then begin
      ring_$swdiag_rcvcnt := ring_$swdiag_rcvcnt + 1;
      ring_$swdiag_nodeid := hdr^.src_node;
      if buf^.rx_status * [2..4, 8..11, 15] = [] then
        ring_$swdiag_goodrcv_cnt := ring_$swdiag_goodrcv_cnt + 1;
    end;

    if buf^.rx_status * [2..4, 8..11, 15] <> [] then
      goto to_process;
    if ring_$logging_now then
      goto to_process;
    if hdr_len <> hdr^.total_len then
      goto to_process;
    if hdr^.pkt_data_len <> 0 then
      goto to_process;
    if 0 in hdr^.flag_bits.info_bits then
      goto to_process;
    if (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
       and then (hdr^.dest_node = 2)
       and then (3 in hdr^.flag_bits.flags_07) then
      goto rearm;

    { the arrival time }
    time_$abs_clock(now);
    if netlog_$ok_to_log_server then begin
      hdr^.dest_node := now.high;
      hdr^.flag_bits.arrival_lo := now.low;
    end
    else
      hdr^.dest_node := time_$clockh;

    { the socket }
    forwarded := false;
    if hdr^.routing_type = pkt_$routing_local then
      sock_num := hdr^.route[hdr^.route_count + 1]
    else begin
      if (hdr^.src.node & net_io_$all_f_addr) = net_io_$all_f_addr then
        goto to_process;
      sock_num := hdr^.dest.sock;
      if hdr^.src.net = 0 then
        hdr^.src.net := unit.route_port^.network;
      if not (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
         and then (hdr^.dest.node <> node_$me) then begin
        sock_num := route_$sock;
        forwarded := true;
      end;
    end;

    if (netbuf_$hdr_top = 0) or else (unit.tmask = 0) then
      goto stopped;
    network_$activity_flag := true;
    if (sock_num = 0) or else (sock_num > 224) then
      goto rearm;

  retry:
    { the packet record }
    sock := sock_$socket_ptr[sock_num];
    hdr^.zero_0f := sock^.queue_count;
    info.hdr := integer32(hdr);
    info.data_pages[1] := 0;
    info.hdr_len := hdr^.total_len;
    info.data_len := hdr^.pkt_data_len;
    info.n_hops := 0;
    info.src_addr := now.high;
    info.src_port := now.low;
    info.flags := [];

    case sock_$put_int_int(sock, info, not forwarded, 0,
                           unit.device_info^.cnum) of
      0: begin
           hdr^.route_count := hdr^.route_count + 1;
           advance(sock^.ec);
           if not netbuf_$get_hdr_cond(buf^.hdr_pa, buf^.hdr_va) then
             goto crash;
         end;
      1: begin
        if sock_num = 2 then begin
          sock_num := 6;
          goto retry;
        end
        else if sock_num = 1 then
          ring_$paging_overflow := ring_$paging_overflow + 1
        else if sock_num = route_$sock then
          route_$q_oflo := route_$q_oflo + 1;
      end;
      2: { empty };
      otherwise begin
        crash_system(status_$network_hardware_error);
      end;
    end;

  rearm:
    { the same buffer again }
    ring_$set_rx_buffer(buf^.ctlr_addr, regs^, unit.max_data_words + 512);
    unit.rx_restart := true;
    ring_$process_rx_packet := nil;
    return;

  crash:
    repeat
      crash_system(status_$network_buffer_error);
    until false;
  end;

to_process:
  { the receive process takes the packet; the controller the next buffer }
  if (unit.tmask = 0) or else (netbuf_$hdr_top = 0) then
    goto stopped;
  next := unit.rx_index + 1;
  if next > unit.rx_buf_cnt then
    next := 1;
  next_buf := addr(unit.rx_bufs[next]);
  if next_buf^.full then
    goto stopped;
  unit.rx_index := next;
  if not netbuf_$get_hdr_cond(next_buf^.hdr_pa, next_buf^.hdr_va) then
    goto crash;
  ring_$set_rx_buffer(next_buf^.ctlr_addr, regs^,
                      unit.max_data_words + 512);
  unit.rx_restart := true;
  goto wake;

stopped:
  unit.rx_stopped := true;
wake:
  ring_$process_rx_packet := addr(unit.rx_wake_ec);
end;
%else
label
  retry, rearm, crash, to_process;
var
  hdr: pkt_$hdr_ptr_t;
  regs: ring_$regs_ptr_t;
  csr: ring_$csr_t;
  hdr_bytes: integer;
  data_bytes: integer;
  forwarded: boolean;
  sock_num: pinteger;
  now: time_$clock_t;
  info: sock_$pkt_info_t;
  sock: sock_$sock_ptr_t;
begin
  netbuf_$hdr_page_ptr_t(unit.rx_hdr)^.phys := unit.rx_hdr_pa;
  regs := unit.hw_regs;
  hdr := pkt_$hdr_ptr_t(unit.rx_hdr);
%if ring_board_dma %then
  csr := regs^.rx_status;
%else
  csr := regs^.rcv_csr;
%endif

  { the software diagnostic's counters }
  if (1 in hdr^.flag_bits.info_bits)
     and then (4 in hdr^.flag_bits.info_bits) then begin
    ring_$swdiag_rcvcnt := ring_$swdiag_rcvcnt + 1;
    ring_$swdiag_nodeid := hdr^.src_node;
%if ring_board_dma %then
    if csr <> [6, 7, 14] then
%else
    if csr - [1, 2, 4] <> [] then
%endif
      ring_$swdiag_goodrcv_cnt := ring_$swdiag_goodrcv_cnt + 1;
  end;

%if ring_controller_dma %then
  if (csr - [1, 2, 4] = [])
     and then not ring_$logging_now then begin

    { the lengths received }
    hdr_bytes := (regs^.rx_hdr_resid & 16#3FF) * 2;
    data_bytes := (regs^.rx_data_resid & 16#3FF) * 2;
%elseif ring_board_dma %then
  if (csr = [6, 7, 14])
     and then not ring_$logging_now then begin

    { the lengths received: the receive channels' counts, read low byte
      first }
    regs^.rx_dma.clear_ff := 0;
    hdr_bytes := (512 - (regs^.rx_dma.chan[0].count
                         + regs^.rx_dma.chan[0].count * 256 + 1)) * 2;
    data_bytes := (512 - (regs^.rx_dma.chan[1].count
                          + regs^.rx_dma.chan[1].count * 256 + 1)) * 2;
%else
  if (csr - [1, 2, 4] = [])
     and then not ring_$logging_now
     and then ((ord(dma[0].csr) & m68450_csr_err) = 0)
     and then ((ord(dma[1].csr) & m68450_csr_err) = 0) then begin

    { stop the two receive channels }
    if (ord(dma[0].csr) & m68450_csr_act) <> 0 then
      dma[0].ccr := chr(m68450_ccr_sab);
    dma[0].csr := chr(16#FF);
    hdr_bytes := 1024 - dma[0].mtc * 2;
    if (ord(dma[1].csr) & m68450_csr_act) <> 0 then
      dma[1].ccr := chr(m68450_ccr_sab);
    dma[1].csr := chr(16#FF);
    data_bytes := 1024 - dma[1].mtc * 2;
%endif

    if hdr_bytes <> hdr^.total_len then
      goto to_process;
    if data_bytes <> hdr^.pkt_data_len then begin
      if hdr^.pkt_data_len <> 0 then
        goto to_process;
      data_bytes := 0;
    end;

    if 0 in hdr^.flag_bits.info_bits then
      goto to_process;
    if (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
       and then (hdr^.src.node = 2)
       and then (3 in hdr^.flag_bits.flags_07) then
      goto rearm;

    { the arrival time }
    time_$abs_clock(now);
    if netlog_$ok_to_log_server then begin
      time_$abs_clock(now);
      hdr^.dest_node := now.high;
      hdr^.flag_bits.arrival_lo := now.low;
    end
    else
      hdr^.dest_node := time_$clockh;

    { the socket }
    forwarded := false;
    if hdr^.routing_type = pkt_$routing_local then
      sock_num := hdr^.route[hdr^.route_count + 1]
    else begin
      if (hdr^.src.node & net_io_$all_f_addr) = net_io_$all_f_addr then
        goto to_process;
      sock_num := hdr^.dest.sock;
      if hdr^.src.net = 0 then
        hdr^.src.net := unit.route_port^.network;
      if not (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits)
         and then (hdr^.dest.node <> node_$me) then begin
        sock_num := route_$sock;
        forwarded := true;
      end;
    end;

    if (netbuf_$hdr_top = 0) or else (netbuf_$dat_cnt = 0) then
      goto to_process;
    network_$activity_flag := true;
    if (sock_num = 0) or else (sock_num > 224) then
      goto rearm;

  retry:
    { the packet record }
    sock := sock_$socket_ptr[sock_num];
    hdr^.zero_0f := sock^.queue_count;
    info.hdr := integer32(hdr);
    info.hdr_len := hdr^.total_len;
    info.data_len := hdr^.pkt_data_len;
    info.n_hops := 0;
    info.src_addr := now.high;
    info.src_port := now.low;
    info.flags := [];
    if data_bytes = 0 then
      info.data_pages[1] := 0
    else
      info.data_pages[1] := unit.rx_data_pa;

    case sock_$put_int_int(sock, info, not forwarded, 0,
                           unit.device_info^.cnum) of
      0: begin
           hdr^.route_count := hdr^.route_count + 1;
           advance(sock^.ec);
           if not netbuf_$get_hdr_cond(unit.rx_hdr_pa, unit.rx_hdr) then
             goto crash;
           if (data_bytes <> 0)
              and then not netbuf_$get_dat_cond(unit.rx_data_pa) then
             goto crash;
         end;
      1: begin
        if sock_num = 2 then begin
          sock_num := 6;
          goto retry;
        end
        else if sock_num = 1 then
          ring_$paging_overflow := ring_$paging_overflow + 1
        else if sock_num = route_$sock then
          route_$q_oflo := route_$q_oflo + 1;
      end;
      2: { empty };
      otherwise begin
        crash_system(status_$network_hardware_error);
      end;
    end;

  rearm:
    { re-arm the receive DMA }
%if ring_controller_dma %then
    regs^.rx_hdr_cnt := 512;
    regs^.rx_hdr_addr := unit.rx_hdr_pa;
    regs^.rx_data_cnt := 512;
    regs^.rx_data_resid := 0;
    regs^.rx_data_addr := unit.rx_data_pa;
%elseif ring_board_dma %then
    regs^.rx_dma.clear_ff := 0;
    regs^.rx_dma.chan[0].addr := 0;
    regs^.rx_dma.chan[0].addr := unit.dma_page * 2 + 8;
    regs^.rx_dma.chan[1].addr := 0;
    regs^.rx_dma.chan[1].addr := unit.dma_page * 2 + 12;
    regs^.rx_dma.chan[0].count := 255;    { 511: 512 words less one }
    regs^.rx_dma.chan[0].count := 1;
    regs^.rx_dma.chan[1].count := 255;
    regs^.rx_dma.chan[1].count := 1;
    regs^.rx_dma.mode := 4;
    regs^.rx_dma.mode := 5;
    regs^.rx_dma.mask := 0;
    regs^.rx_dma.mask := 1;
    iomap[unit.dma_page + 4] := rshft(unit.rx_hdr_pa, 10);
    iomap[unit.dma_page + 5] := 0;
    iomap[unit.dma_page + 6] := rshft(unit.rx_data_pa, 10);
    iomap[unit.dma_page + 7] := 0;
%else
    dma[0].mtc := 512;
    dma[0].mar := unit.rx_hdr_pa;
    dma[0].mfc := chr(0);
    dma[0].ccr := chr(16#80);
    dma[1].mtc := 512;
    dma[1].mar := unit.rx_data_pa;
    dma[1].mfc := chr(0);
    dma[1].ccr := chr(16#80);
%endif
%if ring_board_dma %then
    regs^.rx_cmd := 16#81;
%else
    regs^.rcv_csr := [13, 14];
%endif
    ring_$process_rx_packet := nil;
    return;

  crash:
    repeat
      crash_system(status_$network_buffer_error);
    until false;
  end;

to_process:
  ring_$process_rx_packet := addr(unit.rx_wake_ec);
end;
%endif
