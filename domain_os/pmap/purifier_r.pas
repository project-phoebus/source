{ PMAP_$PURIFIER_R - the remote page purifier process.

  Image addresses:
    sau2  0x00E1416C  PMAP_$PURIFIER_R
    sau3  0x00E141C4  PMAP_$PURIFIER_R
    sau8  0x03C15368  PMAP_$PURIFIER_R
    sau9  0x3C41647C  PMAP_$PURIFIER_R

  - A process's body: it never returns.
  - The dirty remote pool (list 4) is written one page at a time while
    credit is left or the clean pools are below PMAP_$MID_THRESH.
  - A page whose write failed is parked in the wired list (5), unless it
    has left list 4 or the write was refused ("end of file", a
    concurrency violation, "object not found").

  Status stored: none.
}

procedure pmap_$purifier_r;
var
  batch: pmap_$batch_t;
  carry_delta: linteger;
  status: status_$t;
  scan_cnt: linteger;
  recalc_time: linteger;
  scan_time: linteger;
  wait_val: integer32;
  ret_cnt: pinteger;
  carryover: linteger;
  total: linteger;
  count: pinteger;
  scanned: linteger;
  vpn: linteger;
  i: integer;
begin
%if boot_time_lock %then
  { synchronize with the creator }
  ml_$lock(ml_$mt_lock);
  ml_$unlock(ml_$mt_lock);
%endif
  proc1_$set_lock(ml_$server_lock);
  scan_time := time_$clockh + 228;
  recalc_time := scan_time;
  wait_val := pmap_$r_purifier_ec.value + 1;
  carryover := 0;
  carry_delta := 0;

  repeat
    discard(ec_$wait(addr(pmap_$r_purifier_ec),
                     ec_$eventcount_ptr_t(addr(time_$clockh)),
                     addr(ec_$nil_ec), wait_val, scan_time, 0));
    if scan_time <= integer32(time_$clockh) then begin
      if recalc_time <= scan_time then begin
        recalc_time := scan_time + 228;
        carry_delta := (mmap_$wsl[4].page_count + 5) div 6;
      end;
      scan_time := scan_time + 38;
      carryover := carryover + carry_delta;
    end;
    ml_$lock(ml_$pmap_lock);

    { write the dirty remote pages }
    repeat
      total := mmap_$wsl[0].page_count + mmap_$wsl[2].page_count +
               mmap_$wsl[1].page_count;
      if (mmap_$wsl[4].page_count = 0) or else
         ((carryover = 0) and then (total >= pmap_$mid_thresh)) then
        exit;
      mmap_$get_impure(4, batch, total < pmap_$mid_thresh, 1, scan_cnt,
                       ret_cnt);
      count := ret_cnt;
      scanned := scan_cnt;
      for i := 1 to count do begin
        vpn := batch[i];
        with mmap[vpn] do begin
          ast_pmaps[segment][seg_offset].flags :=
            ast_pmaps[segment][seg_offset].flags + [ast_$pmap_in_trans];
%if pmmu_page_maps %then
          ast_pmaps[segment][seg_offset].flags :=
            ast_pmaps[segment][seg_offset].flags - [ast_$pmap_modified];
%else
          pft[vpn].w_02 := pft[vpn].w_02 & ~16#4000;
%endif
          if priority > 5 then
            wsl_index := priority;
          pmap_$write_page(vpn, status, true);
          if status.all = status_$ok then begin
            ec_$advance(pmap_$pages_ec);
            mmap_$avail(vpn);
          end
          else if (wsl_index = 4) and then
                  (status.all <> status_$ast_eof) and then
                  (status.all <> status_$ast_write_concurrency_violation)
                  and then (status.all <> file_$object_not_found) then begin
            mmap_$unavail_remov(vpn, true);
            wsl_index := 5;
            mmap_$avail(vpn);
          end;
        end;
      end;
      pmap_$pur_r_cnt := pmap_$pur_r_cnt + count;
      if scanned > carryover then
        carryover := 0
      else
        carryover := carryover - scanned;
    until false;

    wait_val := pmap_$r_purifier_ec.value + 1;
    ml_$unlock(ml_$pmap_lock);
  until false;
end;
