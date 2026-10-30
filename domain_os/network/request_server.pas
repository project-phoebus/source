{ NETWORK_$REQUEST_SERVER - the body of a network request server process.

  Image addresses:
    sau2  0x00E118DC  NETWORK_$REQUEST_SERVER
    sau9  0x3C413CC4  NETWORK_$REQUEST_SERVER

  - Start-up: the remote page pool grows by one page, sockets 2 (files),
    4 (ASKNODE) and 8 (RIP) are opened, the five wait values set, the
    process's faults inhibited and REM_FILE_$SOCK_LOCK initialized.
  - Then forever it waits for socket 2 (REM_FILE_$SERVER), socket 4
    (ASKNODE_$SERVER, with propagations held until their time), socket
    8 (RIP_$SERVER), the clock or the quit eventcount.
  - The clock: RIP_$AGE, and every fourth tick of 60 a ring check, which
    may send a null packet to node 4 and report a failure.
  - Quit: the timer is cancelled, NETWORK_$RQST_DONE_EC advanced and the
    process unbound.
  - A failed header build and the quit arm go on after CRASH_SYSTEM.
  - A propagation whose TIME_$ADVANCE fails is sent at once; arm 3's
    early path skips the scan.

  Status stored: none.
}

{ TODO(pascal) the 0x1E-byte copy of NETWORK_$SERVER_PKT_INFO

  As in NETWORK_$REPORT_FAILURE (network/report_failure.pas's TODO): the
  packet info is copied as seven longwords and a word, 30 bytes, into a
  pkt_$info_t of 32.  The fifth instance.  Not settled. }

{ TODO(pascal) REQUEST_SERVER's frame stand-ins

  The regions of the frame no instruction addresses and that the
  register-held locals do not fill here: -0x7C (4 bytes), -0x94 (4),
  -0xC4 (4), -0xCE (6), -0xD8 (4) and -0xE0 (6). }

procedure network_$request_server;
label
  10, 20, 30, 31, 40;
var
  slot: integer;
  k: integer;
  attempt: integer;
  elem: time_$queue_elem_t;
  pkt_info: pkt_$info_t;
  last_errors: pinteger;
  errors: pinteger;
  wait_ec: ec_$eventcount_t;
  delta: integer;
  report: boolean;
  saved: boolean;
  ctx: asknode_$server_ctx_t;
  unused_7c: integer32;                   { stand-in }
  waits: array[0..4] of integer32;
  unused_94: integer32;                   { stand-in }
  ecs: array[0..4] of ec_$eventcount_ptr_t;

  port: route_$port_ptr_t;
  routing: integer32;
  status: status_$t;
  hdr_pa: integer32;
  hdr: pkt_$hdr_ptr_t;
  hdr_va: pkt_$hdr_ptr_t;
  unused_c4: integer32;                   { stand-in }
  timeout: pinteger;
  retry: integer;
  unused_ce: array[1..3] of integer;      { stand-in }
  result: ring_$csr_t;
  out_port: integer;
  hdr_len: integer;
  unused_d8: integer32;                   { stand-in }
  token: pinteger;
  unused_e0: array[1..3] of integer;      { stand-in }
begin
  pkt_info := network_$server_pkt_info;

  token := ml_$spin_lock(network_$lock);
  mmap_$min_rmt_pool := mmap_$min_rmt_pool + 1;
  mmap_$pageable_pages_lower_limit := mmap_$min_rmt_pool;
  ml_$spin_unlock(network_$lock, token);

  if (mmap_$rmt_limit < 0) and then
     (network_$allowed_service.remote_pool < mmap_$min_rmt_pool) then
    network_$allowed_service.remote_pool :=
      mmap_$remote_pool(mmap_$min_rmt_pool);

  discard(sock_$open(2, 16#10, 0, 1, 16#400));
  discard(sock_$open(4, 8, 0, 0, 16#400));
  discard(sock_$open(8, 4, 0, 0, 16#400));

  if network_$std_open_flag then begin
    rip_$std_open;
    app_$std_open;
    network_$std_open_flag := false;
  end;

  elem.callback_arg := nil;
  elem.flags := [];

  token := ml_$spin_lock(network_$lock);
  waits[0] := network_$rqst_wait[1];
  network_$rqst_wait[1] := network_$rqst_wait[1] + 1;
  waits[1] := network_$rqst_wait[2];
  network_$rqst_wait[2] := network_$rqst_wait[2] + 1;
  waits[2] := network_$rqst_wait[3];
  network_$rqst_wait[3] := network_$rqst_wait[3] + 1;
  waits[3] := network_$rqst_wait[4];
  if network_$rqst_wait[4] < time_$clockh_ec.value then
    network_$rqst_wait[4] := time_$clockh_ec.value + 60
  else
    network_$rqst_wait[4] := network_$rqst_wait[4] + 60;
  waits[4] := 1;
  ml_$spin_unlock(network_$lock, token);

  ecs[0] := addr(sock_$socket_ptr[2]^.ec);
  ecs[1] := addr(sock_$socket_ptr[4]^.ec);
  ecs[2] := addr(sock_$socket_ptr[8]^.ec);
  ecs[3] := addr(time_$clockh_ec);
  ecs[4] := addr(network_$rqst_quit_ec);
  ec_$init(wait_ec);
  last_errors := 0;
  if route_$port[0].port_type = route_$port_type_ring then
    port := route_$portp[0]
  else
    port := nil;
  proc1_$inhibit_begin;
  ml_$exclusion_init(rem_file_$sock_lock);

10:
  slot := ec_$waitn(ecs, waits, 5) - 1;

20:
  case slot of
    0: begin
      rem_file_$server;
      token := ml_$spin_lock(network_$lock);
      waits[0] := network_$rqst_wait[1];
      network_$rqst_wait[1] := network_$rqst_wait[1] + 1;
      ml_$spin_unlock(network_$lock, token);
    end;
    1: begin
      if ecs[1] <> addr(sock_$socket_ptr[4]^.ec) then
        goto 30;
      ctx.version := -16#2151;
      ctx.clock.high := 0;
      ctx.clock.low := 0;
      asknode_$server(ctx, routing);
      if ctx.version <> -16#2151 then begin
        ecs[1] := addr(wait_ec);
        waits[1] := wait_ec.value + 1;
        if elem.callback_arg <> nil then
          time_$cancel(wait_ec.value, elem, status);
        time_$advance(time_$relative, ctx.clock, wait_ec, elem, status);
        if status.all <> status_$ok then
          goto 30;
        goto 40;
      end;
    31:
      token := ml_$spin_lock(network_$lock);
      waits[1] := network_$rqst_wait[2];
      network_$rqst_wait[2] := network_$rqst_wait[2] + 1;
      ml_$spin_unlock(network_$lock, token);
      goto 40;
    30:
      asknode_$propagate_who(ctx, routing);
      ecs[1] := addr(sock_$socket_ptr[4]^.ec);
      goto 31;
    end;
    2: begin
      rip_$server;
      token := ml_$spin_lock(network_$lock);
      waits[2] := network_$rqst_wait[3];
      network_$rqst_wait[3] := network_$rqst_wait[3] + 1;
      ml_$spin_unlock(network_$lock, token);
    end;
    3: begin
      rip_$age;
      token := ml_$spin_lock(network_$lock);
      network_$age_ticks := network_$age_ticks + 1;
      if (network_$age_ticks mod 240) div 60 <> 0 then begin
        waits[3] := network_$rqst_wait[4];
        if network_$rqst_wait[4] < time_$clockh_ec.value then
          network_$rqst_wait[4] := time_$clockh_ec.value + 60
        else
          network_$rqst_wait[4] := network_$rqst_wait[4] + 60;
        ml_$spin_unlock(network_$lock, token);
        goto 10;
      end;
      ml_$spin_unlock(network_$lock, token);

      if (network_$ring_dcte <> nil) and then (port <> nil) and then
         (port^.active <> 1) then begin
        errors := ring_$data[0].xmit_modem + ring_$data[0].xmit_nortn;
        delta := errors - last_errors;
        last_errors := errors;
        if time_$clockh - network_$failure_rec.timestamp < 16#157 then
          report := network_$failure_rec.node_id = node_$me
        else
          report := (not network_$activity_flag) or (delta > 0);
        saved := (not report) and network_$failure_rec.flag;
        if report then
          for attempt := 1 to 3 do begin
            network_$gethdr(0, hdr_va, hdr_pa);
            pkt_info.flags := 0;
            hdr := hdr_va;
            pkt_$bld_internet_hdr(0, 4, 0, 0, node_$me, 0, pkt_info, 0,
                                  0, 0, 0, out_port, hdr^, hdr_len,
                                  retry, timeout, status);
            hdr_va := hdr;
            if status.all <> status_$ok then
              crash_system(status);
            ring_$sendp(port^.socket, hdr_pa, hdr_va, hdr_len, 0, 0, 0,
                        0, result, status);
            network_$rtnhdr(hdr_va);
            if not ((ring_sendp_res_biphase in result) or
                    (ring_sendp_res_delayed in result)) then begin
              report := false;
              exit;
            end;
          end;
        if report then
          network_$report_failure(result)
        else
          network_$failure_rec.flag := saved;
        network_$activity_flag := false;
      end;

      token := ml_$spin_lock(network_$lock);
      waits[3] := network_$rqst_wait[4];
      if network_$rqst_wait[4] < time_$clockh_ec.value then
        network_$rqst_wait[4] := time_$clockh_ec.value + 60
      else
        network_$rqst_wait[4] := network_$rqst_wait[4] + 60;
      ml_$spin_unlock(network_$lock, token);
    end;
    4: begin
      if elem.callback_arg <> nil then
        time_$cancel(wait_ec.value, elem, status);
      proc1_$inhibit_end;
      ec_$advance(network_$rqst_done_ec);
      proc1_$unbind(proc1_$current, status);
      crash_system(status);
    end;
  end;

40:
  for k := slot + 1 to 4 do
    if ec_$read(ecs[k]^) - waits[k] >= 0 then begin
      slot := k;
      goto 20;
    end;
  goto 10;
end;
