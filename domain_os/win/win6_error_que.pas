{ WIN6_$ERROR_QUE - the error queue entry of the second board's
  driver: retry or finish a process's failed request.

  Image addresses:
    sau6  0x7801B35A  send_cmd (nested)
    sau6  0x7801B464  ecc_fix (nested)
    sau6  0x7801B50C  return_iopbs (nested)
    sau6  0x7801B572  WIN6_$ERROR_QUE

  - For the calling process's failed request on the drive: one that
    found no command blocks goes to WIN6_$DO_IO again.  Else each
    request of the chain takes its block's status (win6_$epb_status);
    while the retries last and the first error asks for one, the chain
    is retried (WIN6_$DO_IO), after a recalibration at three tenths of
    the retries and a seek to the drive's geometry at six tenths, for a
    data check; else it is finished, a data check corrected (with
    WIN6_$FIX_ECCC), the blocks given back and the process's I/O
    eventcount advanced.
  - The time-out call (is_timeout, or no failed request) clears the
    drive's interrupt watch, after CRASH_SYSTEM with the time-out status
    when no completion came in the last 80 ticks.
  - send_cmd starts a drive command block (40 ticks for a free one);
    ecc_fix flips the ECC pattern's three bytes in the block header or
    the data page; return_iopbs gives the chain's blocks back.

  Status stored: none.
}

procedure win6_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
var
  failed: disk_$io_req_ptr_t;
  last_req: disk_$io_req_ptr_t;
  base: integer32;
  action: integer;
  count: integer;
  first_idx: integer;
  last_idx: integer;
  do_result: boolean;
  unit: pinteger;
  owner: integer;
  r: disk_$io_req_ptr_t;
  bad: disk_$io_req_ptr_t;
  retry: boolean;
  act: integer;
  st: integer32;
  old_sr: pinteger;
  now: integer32;

  procedure send_cmd(op: integer);
  label
    10;
  var
    first: integer;
    last: integer;
    free: boolean;
    idx: integer;
    deadline: integer32;
  begin
    free := win6_$get_iopbs(1, first, last) = 0;
    idx := first;
    if not free then begin
      deadline := time_$clockh + 40;
      repeat
        free := win6_$get_iopbs(1, first, last) = 0;
        idx := first;
        if free then
          goto 10;
      until time_$clockh > deadline;
      crash_system(status_$disk_controller_timeout);
    end;
10:
    with win6_page^.iopbs[idx] do begin
      req := nil;
      status := -1;
      link := win6_end_of_chain;
      opu.unit := vol.dev_unit;
      state := win6_state_used;
      f_0a.b_0a := 0;
      f_0a.b_0b := 0;
      w_10 := 0;
      opu.op := op;
      if op = win6_op_seek_geometry then
        geom := win6_drives[vol.dev_unit].geom
      else
        l_10 := 0;
      phys := 0;
      buf := 0;
      l_1c := 0;
    end;
    win6_$send_iopb(idx);
  end;

  procedure ecc_fix(var req: disk_$io_req_t);
  type
    win6_$hdr_bytes_t = array[0..31] of win_$byte_t;
  var
    pattern: win6_$ecc_pattern_t;
    pos: integer;
    hdr: ^win6_$hdr_bytes_t;
    i: integer;
    b: win_$byte_t;
    nb: win_$byte_t;
  begin
    hdr := addr(req.header);
    pos := win6_$iopb_ptr_t(req.reserved_18)^.ecc_pos;
    pattern := win6_$iopb_ptr_t(req.reserved_18)^.ecc_pattern;
    mmu_$install(req.ppn, addr(win_ecc_buf), 0, 16#16);
    for i := 1 to 3 do begin
      b := pattern[i];
      nb := ~b;
      if pos < 32 then
        hdr^[pos] := (b & ~hdr^[pos]) ! (hdr^[pos] & nb)
      else if pos < 1056 then
        win_ecc_buf[pos - 32] := (win_ecc_buf[pos - 32] & nb)
                                 ! (~win_ecc_buf[pos - 32] & b);
      pos := pos + 1;
    end;
    mmu_$remove(addr(win_ecc_buf), 0);
  end;

  procedure return_iopbs;
  begin
    base := integer32(addr(win6_page^.iopbs));
    first_idx := (integer32(failed^.reserved_18) - base) div win6_iopb_size;
    last_idx := (integer32(last_req^.reserved_18) - base) div win6_iopb_size;
    win6_$rtn_iopbs(count, first_idx, last_idx);
  end;

begin
  unit := vol.dev_unit;
  owner := proc1_$current;
  result := false;
  failed := win6_drives[unit].failed[owner];
  if (is_timeout = 0) and then (failed <> nil) then begin
    result := true;
    win6_drives[unit].failed[owner] := nil;
    if failed^.reserved_18 = nil then begin
      { it found no command blocks: again }
      win6_$do_io(vol, failed^, failed^, do_result);
      return;
    end;

    { each request's status; the first error decides }
    failed^.flags := failed^.flags + 1;
    retry := (failed^.flags <= win6_$retries) and not failed^.owner_op.chksum;
    r := failed;
    count := 0;
    act := win6_act_unset;
    repeat
      r^.status.all := 0;
      count := count + 1;
      st := win6_$epb_status(win6_$iopb_ptr_t(r^.reserved_18)^, action);
      if (st <> status_$ok) and then (act = win6_act_unset) then begin
        act := action;
        if act = win6_act_none then
          retry := false;
        bad := r;
      end;
      if not retry then
        r^.status.all := st;
      last_req := r;
      r := r^.next;
    until r = nil;

    if not retry or (act = win6_act_unset) then
      { finished }
      with disk_bptbl[owner] do begin
        case act of
          win6_act_unset: begin
            io_pending := true;
          end;
          win6_act_ecc: begin
            if win6_$fix_eccc then begin
              ecc_fix(bad^);
              bad^.status.all := status_$ok;
              io_pending := bad = last_req;
            end;
            win6_$fixes := win6_$fixes + 1;
          end;
          otherwise begin
            io_pending := false;
          end;
        end;
        return_iopbs;
        ec_$advance_without_dispatch(io_ec);
      end
    else begin
      { a retry }
      if act = win6_act_ecc then
        if failed^.flags = win6_$retries * 3 div 10 then
          act := win6_act_recal
        else if failed^.flags = win6_$retries * 6 div 10 then
          act := win6_act_seek;
      if act = win6_act_recal then
        send_cmd(win6_op_recalibrate);
      if act = win6_act_seek then
        send_cmd(win6_op_seek_geometry);
      return_iopbs;
      win6_$do_io(vol, failed^, last_req^, do_result);
    end;
  end
  else
    { the time-out call }
    with win6_drives[unit] do begin
      old_sr := set_sr(16#2700);
      now := time_$clockh;
      if not int_seen then
        if now - int_time > 80 then
          crash_system(status_$disk_controller_timeout);
      int_seen := false;
      discard(set_sr(old_sr));
    end;
end;
