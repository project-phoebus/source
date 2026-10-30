{ scsi_get_req - take a request off its bus's free list.

  Image addresses:
    sau9  0x3C4A4D14  scsi_get_req

  - With the list empty, waits on the bus's free eventcount (released
    lock, 200 ticks a time) until a request is freed.
  - Returns the request, or nil with the status set.
  - A time-out sets the status, and the wait goes on until a request is
    freed.

  Status stored:
    status_$ok: a request was taken
    status_$scsi_no_resources: a wait timed out
}

function scsi_get_req(cb: scsi_cb_ptr_t;
                      out status: status_$t): scsi_req_ptr_t; internal;
var
  token: integer;
  req: scsi_req_ptr_t;
  value: integer32;
  which: integer;
begin
  token := ml_$spin_lock(scsi_lock);
  req := nil;
  status.all := status_$ok;
  while cb^.free_head = nil do begin
    value := cb^.free_ec.value + 1;
    ml_$spin_unlock(scsi_lock, token);
    which := ec_$wait(addr(cb^.free_ec), addr(time_$clockh_ec),
                      addr(ec_$nil_ec), value, time_$clockh + 200, 0);
    token := ml_$spin_lock(scsi_lock);
    if which <> 0 then
      status.all := status_$scsi_no_resources;
  end;
  if status.all = status_$ok then begin
    cb^.free_count := cb^.free_count - 1;
    if cb^.free_count = 0 then
      scsi_cnts := 16#FACE;
    req := cb^.free_head;
    cb^.free_head := req^.next;
    if cb^.free_head = nil then
      cb^.free_tail := nil;
  end;
  ml_$spin_unlock(scsi_lock, token);
  scsi_get_req := req;
end;
