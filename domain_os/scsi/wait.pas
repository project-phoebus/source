{ SCSI_$WAIT - wait for a device's command to end.

  Image addresses:
    sau9  0x3C4A6A6E  SCSI_$WAIT

  - Id 0 takes the device's first done request.  A request still pending
    is waited for on the target's eventcount (its value the request's
    id), the time-out (in milliseconds, rounded to clock ticks of 4 ms
    and at least one) and, with allow_quit, a quit of the process.
  - A done request returns its result (count 1); its pages are unwired
    if they were wired for the transfer, and it is freed, with every
    done request of a lower id.
  - The quit's wait value is truncated to a word, as CT_WAIT's.

  Returns:
    0: the request is done
    1: the time-out passed, or timeout 0 and the request is not done
    2: a quit (the quit eventcount's value taken)
    undefined: the status is not status_$ok

  Status stored:
    status_$ok: as returned
    status_$scsi_bad_handle: the handle names no device or an old one, or
      the device is not set up
    status_$scsi_bad_parameter: max_results is 0 or above 64
    status_$scsi_no_such_operation: the device has no such request
}

function scsi_$wait(in handle: scsi_$handle_t; in timeout: integer32;
                    in allow_quit: boolean; in id: integer32;
                    in max_results: integer; out result: scsi_$result_t;
                    out count: integer; out status: status_$t): integer;
var
  cb: scsi_cb_ptr_t;
  tgt: scsi_target_ptr_t;
  quit: boolean;
  req_id: integer32;
  ticks: integer32;
  token: integer;
  req: scsi_req_ptr_t;
  wait_value: integer32;
  quit_ec: ec_$eventcount_ptr_t;
  quit_value: integer;
  w: integer;
  i: integer;
  p: scsi_req_ptr_t;
  next: scsi_req_ptr_t;
begin
  status.all := status_$ok;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  cb := addr(scsi_$cb[handle.bus]);
  tgt := addr(cb^.target[handle.target]);
  if not tgt^.allocated or else (tgt^.gen <> handle.gen) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  if (pinteger(max_results) > 64) or else (max_results = 0) then begin
    status.all := status_$scsi_bad_parameter;
    return;
  end;
  quit := allow_quit;
  req_id := id;
  ticks := timeout;

  token := ml_$spin_lock(scsi_lock);
  if (req_id = 0) and then (tgt^.done_head <> nil) then begin
    w := 0;
    req := tgt^.done_head;
  end
  else if scsi_find_req(tgt^.done_head, req_id, req) then
    w := 0
  else if ticks = 0 then
    w := 1
  else if scsi_find_req(tgt^.pend_head, req_id, req) then begin
    wait_value := req^.result.id;
    ml_$spin_unlock(scsi_lock, token);
    ticks := (ticks + 125) div 250;
    if ticks = 0 then
      ticks := 1;
    if quit then begin
      quit_ec := addr(fim_$quit_ec[proc1_$as_id]);
      quit_value := fim_$quit_value[proc1_$as_id] + 1;
    end
    else begin
      quit_ec := nil;
      quit_value := 0;
    end;
    w := ec_$wait(addr(tgt^.ec), addr(time_$clockh_ec), quit_ec,
                  wait_value, ticks + time_$clockh, quit_value);
    if w = 2 then
      fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
    token := ml_$spin_lock(scsi_lock);
  end
  else begin
    ml_$spin_unlock(scsi_lock, token);
    status.all := status_$scsi_no_such_operation;
    return;
  end;

  case w of
    0: begin
      scsi_$wait := 0;
      ml_$spin_unlock(scsi_lock, token);
      result := req^.result;
      count := 1;
      if req^.ppn_list and then (linteger(req^.buf_va) < 16#3C000000)
         and then (req^.npages <> 0) then
        for i := 1 to req^.npages do
          wp_$unwire(req^.pages[i]);
      token := ml_$spin_lock(scsi_lock);
      scsi_remove_done_req(cb, tgt, req);
      p := tgt^.done_head;
      while p <> nil do begin
        next := p^.next;
        if req_id > p^.result.id then
          scsi_remove_done_req(cb, tgt, p);
        p := next;
      end;
    end;
    1: begin
      scsi_$wait := 1;
    end;
    2: begin
      scsi_$wait := 2;
    end;
  end;
  ml_$spin_unlock(scsi_lock, token);
end;
