{ win6_$send_iopb - start a chain of command blocks, or queue it.

  Image addresses:
    sau6  0x7801AA66  win6_$send_iopb (module-local)

  - At IPL 7.  While the controller has a start (CTL_BSY) the chain goes
    to the start queue RQ: a seek or a recalibration at its head, others
    at its tail, for WIN6_$INT to start.
  - Else the start word, once the controller has taken the last start
    (4 ticks, then CRASH_SYSTEM with the time-out status), gets the
    chain's offset, the first block marked started.

  Status stored: none.
}

procedure win6_$send_iopb(idx: integer);
  internal;
var
  old_sr: pinteger;
  page: win6_$page_ptr_t;
  deadline: integer32;
begin
  old_sr := set_sr(16#2700);
  page := win6_page;
  if ctl_bsy then begin
    rqcnt := rqcnt + 1;
    case page^.iopbs[idx].opu.op of
      win6_op_seek_geometry, win6_op_recalibrate: begin
        if rqst = 0 then
          rqst := 1;
        rq[rqst] := idx;
        if rqst = 1 then
          rqst := win6_rq_size
        else
          rqst := rqst - 1;
      end;
      otherwise begin
        if rqnd = win6_rq_size then
          rqnd := 1
        else
          rqnd := rqnd + 1;
        rq[rqnd] := idx;
      end;
    end;
  end
  else begin
    ctl_bsy := true;
    if page^.start.flag <> 0 then begin
      deadline := time_$clockh + 4;
      while page^.start.flag <> 0 do
        if time_$clockh > deadline then begin
          crash_system(status_$disk_controller_timeout);
          exit;
        end;
    end;
    page^.iopbs[idx].state := (page^.iopbs[idx].state & 16#FFFE) !
                              win6_state_started;
    page^.start_iopb := idx * win6_iopb_size;
    page^.start.flag := 1;
  end;
  discard(set_sr(old_sr));
end;
