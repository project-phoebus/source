{ WIN6_$INT - the second controller's completion interrupt.

  Image addresses:
    sau6  0x7801AB76  WIN6_$INT

  - The completed chain's first block is marked done, its drive's
    interrupt watch set with the clock.  A parameters block advances
    the drive's eventcount; a seek's or a recalibration's block is
    given back.  A transfer's chain is walked: at an error block the
    request is the process's failed request and its error eventcount is
    advanced; at the last block the process's I/O eventcount is
    advanced and the chain given back.
  - Then the next queued chain is started, or CTL_BSY cleared.
  - Without a completion waiting, or for another operation, or a block
    whose request does not point back at it: CRASH_SYSTEM with the
    controller error.

  Status stored: none.
}

function win6_$int(in dcte: dcte_t): boolean;
label
  10;
var
  page: win6_$page_ptr_t;
  idx: integer;
  unit: integer;
  r: disk_$io_req_ptr_t;
  owner: integer;
  n: integer;
  i: integer;
  deadline: integer32;
begin
  page := win6_page;
  if page^.done.flag = 1 then
    idx := page^.done_iopb div win6_iopb_size
  else begin
    win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
    crash_system(status_$disk_controller_error);
    goto 10;
  end;

  with page^.iopbs[idx] do begin
    state := state ! win6_state_done;
    unit := opu.unit;
    r := req;
    owner := r^.owner_op.owner;
    win6_drives[unit].int_seen := true;
    win6_drives[unit].int_time := time_$clockh;
    case opu.op of
      win6_op_drive_params: begin
        ec_$advance_without_dispatch(win6_drives[unit].ec);
      end;
      win6_op_seek_geometry, win6_op_recalibrate: begin
        win6_$rtn_iopbs(1, idx, idx);
      end;
      win6_op_format, win6_op_format_track, win6_op_write,
      win6_op_read: begin
        n := 0;
        i := idx;
        repeat
          n := n + 1;
          with page^.iopbs[i] do begin
            if (req = nil) or else
               (req^.reserved_18 <> addr(page^.iopbs[i])) then
              crash_system(status_$disk_controller_error);
            if err.sev <> win6_sev_none then begin
              win6_drives[unit].failed[owner] := r;
              ec_$advance_without_dispatch(disk_bptbl[owner].err_ec);
              exit;
            end;
            if link = win6_end_of_chain then begin
              ec_$advance_without_dispatch(disk_bptbl[owner].io_ec);
              win6_$rtn_iopbs(n, idx, i);
              exit;
            end;
            i := link div win6_iopb_size;
          end;
        until false;
      end;
      otherwise begin
        crash_system(status_$disk_controller_error);
      end;
    end;
  end;

  { the next queued chain }
  page^.done.flag := 0;
  if rqcnt = 0 then
    ctl_bsy := false
  else begin
    if page^.start.flag <> 0 then begin
      deadline := time_$clockh + 3;
      while page^.start.flag <> 0 do
        if time_$clockh > deadline then begin
          crash_system(status_$disk_controller_timeout);
          exit;
        end;
    end;
    rqcnt := rqcnt - 1;
    if rqst = win6_rq_size then
      rqst := 1
    else
      rqst := rqst + 1;
    page^.iopbs[rq[rqst]].state := (page^.iopbs[rq[rqst]].state & 16#FFFE)
                                   ! win6_state_started;
    page^.start_iopb := rq[rqst] * win6_iopb_size;
    page^.start.flag := 1;
  end;
10:
  win6_$int := true;
end;
