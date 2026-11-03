{ PMAP_$PURIFIER_L - the local page purifier process.

  Image addresses:
    sau2  0x00E13A9C  PMAP_$PURIFIER_L
    sau3  0x00E13B10  PMAP_$PURIFIER_L
    sau9  0x3C415DD4  PMAP_$PURIFIER_L

  - A process's body: it never returns.
  - The dirty local pool (list 3) is written while the clean pools are
    below PMAP_$MID_THRESH or carryover credit is left, 16 pages at a
    time with the PMAP lock released.
  - When fewer than 24 pages are clean, working sets are scanned or
    purged: an overdue or idle one, else one picked at random in
    proportion to its pages above the floor.
  - A failed batch write or CAL_$SHUTDOWN crashes the system; a diskless
    node runs no shutdown.

  Status stored: none.
}

{ TODO(pascal) The deadlines compared signed with the clock, unsigned with each other

  Both purifiers compare scan_time with the clock signed, and with the
  other deadlines unsigned.  Under ref 4.3.3 no one declaration gives
  both while base/base.ins.pas's time_$clockh_t is linteger (the
  customer file's): the deadlines are linteger, and the clock is
  transferred to integer32 in the two comparisons.  The kernel's own
  insert may have declared TIME_$CLOCKH signed; settling it needs a
  survey of every comparison of TIME_$CLOCKH. }

procedure pmap_$purifier_l;
type
  pmap_l_log_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (vol: pinteger);                 { 0x00 }
  end;
var
  log_rec: pmap_l_log_t;
  batch: pmap_$batch_t;
  qtail: disk_$io_req_ptr_t;
  qhead: disk_$io_req_ptr_t;
  prev_steal: integer32;
  steal_count: integer32;
  aote: ast_$aote_ptr_t;
  carry_delta: linteger;
  carryover: linteger;
  shutdown_time: linteger;
  log_time: linteger;
  scan_time: linteger;
  wait_val: integer32;
  status: status_$t;
  scan_cnt: linteger;
  wait_result: integer;
  ret_cnt: pinteger;
  below: boolean;
  did_advance: boolean;
  saved_chksum: boolean;
  total: linteger;
  scanned: linteger;
  count: pinteger;
  advanced: boolean;
  vpn: linteger;
  i: integer;
  first: disk_$io_req_ptr_t;
  q: disk_$io_req_ptr_t;
  cutoff: integer32;
  slot: pinteger;
  slot_pages: pinteger;
  target: pinteger;
  acc: linteger;
  total_steal: integer32;
  delta: linteger;
  log_vpn: integer32;
label
  10;
begin
%if boot_time_lock %then
  { synchronize with the creator }
  ml_$lock(ml_$mt_lock);
  ml_$unlock(ml_$mt_lock);
%endif
  proc1_$set_lock(ml_$server_lock);
  scan_time := time_$clockh + 228;
  log_time := scan_time;
  shutdown_time := scan_time;
  wait_val := pmap_$l_purifier_ec.value + 1;
  pmap_$low_thresh := mmap_$pageable_pages div 50;
  pmap_$mid_thresh := mmap_$pageable_pages div 20;
  carryover := 0;
  carry_delta := 0;
  steal_count := 0;
  prev_steal := 0;
  pmap_$init_timers;

  repeat
    wait_result := ec_$wait(addr(pmap_$l_purifier_ec),
                            ec_$eventcount_ptr_t(addr(time_$clockh)),
                            addr(ec_$nil_ec), wait_val, scan_time, 0);
    ml_$lock(ml_$pmap_lock);
    did_advance := false;

    repeat
      { drain the dirty local pool }
      repeat
        total := mmap_$wsl[0].page_count + mmap_$wsl[2].page_count +
                 mmap_$wsl[1].page_count;
        below := total < pmap_$mid_thresh;
        if ((carryover = 0) and not below) or else
           (mmap_$wsl[3].page_count = 0) then
          exit;
        mmap_$get_impure(3, batch, total < pmap_$mid_thresh, 16,
                         scan_cnt, ret_cnt);
        count := ret_cnt;
        scanned := scan_cnt;
        if count <> 0 then begin
          { mark the batch in transit }
          for i := 1 to count do begin
            vpn := batch[i];
            with mmap[vpn] do begin
              with ast_pmaps[segment][seg_offset] do begin
                if not flags2_7 then begin
                  aote := ast[segment].aote;
                  log_rec.vol := aote^.vol_index;
                end;
                flags := flags + [ast_$pmap_in_trans];
              end;
%if pmmu_page_maps %then
              if ast_$pmap_modified in
                 ast_pmaps[segment][seg_offset].flags then begin
                ast_pmaps[segment][seg_offset].flags :=
                  ast_pmaps[segment][seg_offset].flags - [ast_$pmap_modified];
%else
              if (pft[vpn].w_02 & 16#4000) <> 0 then begin
                pft[vpn].w_02 := pft[vpn].w_02 & ~16#4000;
%endif
                if not flags2_7 then begin
                  time_$abs_clock(aote^.dtv);
                  time_$clock(aote^.dtm);
                  aote^.dta := aote^.dtm;
                  aote^.flags := aote^.flags + [5];
                end;
              end;
              if priority <> 0 then
                wsl_index := priority;
            end;
          end;

          { write the batch }
          ml_$unlock(ml_$pmap_lock);
          disk_$get_qblks(count, qhead, qtail);
          first := qhead;
          pmap_$fill_write_qblks(batch, first, count);
          disk_$write_multi(true, first, status);
          if status.all <> status_$ok then
            crash_system(status);
          proc1_$stats[proc1_$current].stat[3] :=
            proc1_$stats[proc1_$current].stat[3] + count;

          { the results }
          advanced := false;
          ml_$lock(ml_$pmap_lock);
          q := first;
          for i := 1 to count do begin
            pmap_$write_complete(q^.ppn, q^.status);
            vpn := q^.ppn;
            if q^.status.all = status_$ok then begin
              advanced := true;
              mmap_$avail(vpn);
            end
            else if mmap[vpn].wsl_index = 3 then begin
              mmap_$unavail_remov(vpn, true);
              mmap[vpn].wsl_index := 5;
              mmap_$avail(vpn);
            end;
            q := q^.free_next;
          end;

          if netlog_$ok_to_log then begin
            log_rec.uid := uid_$nil;
            netlog_$log_it(13, log_rec.uid, count, wait_result,
                           rshft(first^.header.abs_daddr, 16),
                           first^.header.abs_daddr,
                           rshft(qtail^.header.abs_daddr, 16),
                           qtail^.header.abs_daddr);
          end;
          disk_$rtn_qblks(count, first, qtail);
          if advanced then begin
            ec_$advance(ast_$pmap_in_trans_ec);
            ec_$advance(pmap_$pages_ec);
          end;
          did_advance := advanced;
          pmap_$pur_l_cnt := pmap_$pur_l_cnt + count;
        end;

        if scanned > carryover then
          carryover := 0
        else
          carryover := carryover - scanned;
      until false;

      wait_val := pmap_$l_purifier_ec.value + 1;
      total := total + mmap_$wsl[3].page_count;

      { short of clean pages, scan working sets }
      while total < 24 do begin
        cutoff := time_$clockh - pmap_$idle_interval;
        prev_steal := prev_steal + 1;
        slot_pages := 0;
        for slot := mmap_$wsl_hi_mark downto 5 do
          with mmap_$wsl[slot] do
            if page_count <> 0 then begin
              if owner > pmap_$ws_interval then begin
                owner := 0;
                ws_timestamp := time_$clockh;
                discard(mmap_$ws_scan(slot, false, 16#3FFFFF, 16#3FFFFF));
                goto 10;
              end;
              if cutoff > pri_timestamp then begin
                mmap_$purge(slot);
                goto 10;
              end;
              if (page_count > ws_floor) or else (total = 0) then
                slot_pages := slot_pages + page_count;
            end;
        if slot_pages = 0 then
          exit;

        { pick a working set at random }
        pmap_$ws_random_seed := (pmap_$ws_random_seed * 12345) & 16#3FF;
        target := rshft(slot_pages * pmap_$ws_random_seed, 10);
        acc := 0;
        for slot := mmap_$wsl_hi_mark downto 5 do
          with mmap_$wsl[slot] do begin
            if (page_count > ws_floor) or else (total = 0) then
              acc := acc + page_count;
            if target < acc then begin
              discard(mmap_$ws_scan(slot, false, 1, 16#3FFFFF));
              exit;
            end;
          end;

    10: ml_$unlock(ml_$pmap_lock);
        time_$wait(time_$relative, pmap_$short_wait_delay, status);
        ml_$lock(ml_$pmap_lock);
        total := mmap_$wsl[0].page_count + mmap_$wsl[1].page_count +
                 mmap_$wsl[2].page_count + mmap_$wsl[3].page_count +
                 mmap_$wsl[4].page_count;
      end;

      if not did_advance then begin
        ec_$advance(pmap_$pages_ec);
        did_advance := true;
      end;
    until (not below) or else (mmap_$wsl[3].page_count = 0);

    { retune the scan interval }
    if integer32(time_$clockh) >= scan_time then begin
      scan_time := scan_time + 19;
      carryover := carryover + carry_delta;
      total_steal := prev_steal + mmap_$steal_cnt;
      delta := total_steal - steal_count;
      if delta = 0 then begin
        pmap_$ws_interval := pmap_$ws_interval + pmap_$ws_scan_delta;
        if pmap_$max_ws_interval < pmap_$ws_interval then
          pmap_$ws_interval := pmap_$max_ws_interval;
      end
      else if delta > 5 then begin
        pmap_$ws_interval := rshft(pmap_$ws_interval, 1);
        if pmap_$min_ws_interval > pmap_$ws_interval then
          pmap_$ws_interval := pmap_$min_ws_interval;
      end;
      steal_count := total_steal;
    end;
    ml_$unlock(ml_$pmap_lock);

    { the log deadline }
    if scan_time >= log_time then begin
      carry_delta := (mmap_$wsl[3].page_count + 11) div 12;
      pmap_$low_thresh :=
        rshft(pmap_$low_thresh + mmap_$pageable_pages div 50, 1);
      pmap_$mid_thresh :=
        rshft(pmap_$mid_thresh + mmap_$pageable_pages div 20, 1);
      log_vpn := log_$update;
      if log_vpn <> 0 then begin
        ml_$lock(ml_$pmap_lock);
        if not network_$diskless then begin
          saved_chksum := disk_$do_chksum;
          disk_$do_chksum := false;
        end;
        pmap_$write_page(log_vpn, status, false);
        if not network_$diskless then
          disk_$do_chksum := saved_chksum;
        if status.all <> status_$ok then
          log_$logfile_ptr := nil;
        ml_$unlock(ml_$pmap_lock);
      end;
      log_time := scan_time + 228;
    end;

    { the shutdown deadline }
    if not pmap_$shutting_down_flag and then
       (scan_time >= shutdown_time) then begin
      if not network_$diskless then begin
        cal_$shutdown(status);
        if status.all <> status_$ok then
          crash_system(status);
      end;
      shutdown_time := scan_time + 13680;
    end;
  until false;
end;
