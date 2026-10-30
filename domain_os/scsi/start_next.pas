{ scsi_start_next - start the next target's business on a free bus.

  Image addresses:
    sau9  0x3C4A709E  scsi_start_next

  Assume we're called with the SCSI spin lock held.

  - A target on the bus with a message of the driver's to send goes
    first; otherwise the last idle target with a request pending.
  - Called with a target connected, it crashes the system.
}

procedure scsi_start_next(cb: scsi_cb_ptr_t);
var
  found: scsi_target_ptr_t;
  tid: integer;
  i: integer;
begin
  if cb^.connected then
    crash_system(status_$scsi_internal_error);
  found := nil;
  for i := 0 to 7 do
    with cb^.target[i] do
      if (active = false) and then (pend_head <> nil) then begin
        tid := i;
        found := addr(cb^.target[tid]);
      end
      else if (active = true)
              and then (msg_out_state = scsi_mo_queued) then begin
        tid := i;
        found := addr(cb^.target[tid]);
        exit;
      end;
  if found <> nil then
    if found^.active then
      scsi_start_abort(cb, found, tid)
    else
      scsi_start_cmd(cb, found, tid);
end;
