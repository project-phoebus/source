{ SCSI_$RESET_DEVICE - reset a device.

  Image addresses:
    sau9  0x3C4A64C6  SCSI_$RESET_DEVICE

  - An idle target gets a request (an empty 6-byte command) and a BUS
    DEVICE RESET to send at its selection; the request takes its list's
    first place, followed by the first request's successor.  A
    connected target has attention raised for it.  Then waits (with no
    quit, up to 1000000 ticks) for that request.
  - The request is taken off the free list with the SCSI spin lock
    held.

  Status stored:
    status_$ok: the device was reset
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_target_disconnected: the target is disconnected
    scsi_get_req's status: no request was free
    SCSI_$WAIT's status: the wait failed
}

procedure scsi_$reset_device(in handle: scsi_$handle_t;
                             out status: status_$t);
var
  cb: scsi_cb_ptr_t;
  tgt: scsi_target_ptr_t;
  st: status_$t;
  token: integer;
  req: scsi_req_ptr_t;
  next_id: integer32;
  result: scsi_$result_t;
  count: integer;
begin
  status.all := status_$ok;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  cb := addr(scsi_$cb[handle.bus]);
  tgt := addr(cb^.target[handle.target]);
  if not tgt^.allocated then begin
    status.all := status_$scsi_device_not_acquired;
    return;
  end;
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;

  st := status;
  token := ml_$spin_lock(scsi_lock);
  if tgt^.active = false then begin
    req := scsi_get_req(cb, st);
    if st.all <> status_$ok then begin
      ml_$spin_unlock(scsi_lock, token);
      status := st;
      return;
    end;
    req^.cdb := scsi_null_cdb;
    req^.cdb_len := 6;
    next_id := tgt^.next_id + 1;
    req^.result.id := next_id;
    req^.ppn_list := false;
    tgt^.next_id := next_id;
    if tgt^.pend_head <> nil then begin
      req^.next := tgt^.pend_head^.next;
      tgt^.pend_head := req;
    end
    else begin
      req^.next := nil;
      tgt^.pend_head := req;
      tgt^.pend_tail := req;
    end;
    tgt^.active := true;
    tgt^.msg_out_state := scsi_mo_queued;
    tgt^.msg_out_code := scsi_msg_bus_device_reset;
    if cb^.connected = false then
      scsi_start_next(cb);
  end
  else if tgt^.state <> scsi_ts_disconnected then begin
    req := tgt^.pend_head;
    tgt^.msg_out_state := scsi_mo_atn;
    tgt^.msg_out_code := scsi_msg_bus_device_reset;
    cb^.regs^.cmd := c90_cmd_set_atn;
  end
  else
    st.all := status_$scsi_target_disconnected;
  ml_$spin_unlock(scsi_lock, token);

  status := st;
  if st.all = status_$ok then begin
    discard(scsi_$wait(handle, 1000000, false, req^.result.id, 1, result,
                       count, st));
    status := st;
  end;
end;
