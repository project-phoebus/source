{ SCSI_$ABORT_OPERATION - abort a device's command in progress.

  Image addresses:
    sau9  0x3C4A4F34  SCSI_$ABORT_OPERATION

  - Raises attention on the connected target, with an ABORT message to
    send, then waits (with no quit, up to 1000000 ticks) for the
    request on the bus to end.

  Status stored:
    status_$ok: the command was aborted
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_target_disconnected: the target is disconnected
    status_$scsi_no_such_operation: the target is not on the bus
    SCSI_$WAIT's status: the wait failed
}

procedure scsi_$abort_operation(in handle: scsi_$handle_t;
                                out status: status_$t);
var
  st: status_$t;
  h: scsi_$handle_t;
  cb: scsi_cb_ptr_t;
  tgt: scsi_target_ptr_t;
  req: scsi_req_ptr_t;
  token: integer;
  result: scsi_$result_t;
  count: integer;
begin
  status.all := status_$ok;
  st := status;
  h := handle;
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

  token := ml_$spin_lock(scsi_lock);
  if tgt^.active then
    if tgt^.state <> scsi_ts_disconnected then begin
      req := tgt^.pend_head;
      tgt^.msg_out_state := scsi_mo_atn;
      tgt^.msg_out_code := scsi_msg_abort;
      cb^.regs^.cmd := c90_cmd_set_atn;
    end
    else
      st.all := status_$scsi_target_disconnected
  else
    st.all := status_$scsi_no_such_operation;
  ml_$spin_unlock(scsi_lock, token);

  if st.all = status_$ok then
    discard(scsi_$wait(h, 1000000, false, req^.result.id, 1, result, count,
                       st));
  status := st;
end;
