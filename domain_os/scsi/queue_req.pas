{ scsi_queue_req - append a request to a target's pending list.

  Image addresses:
    sau9  0x3C4A4DF0  scsi_queue_req
}

procedure scsi_queue_req(tgt: scsi_target_ptr_t; req: scsi_req_ptr_t);
  internal;
var
  token: integer;
begin
  token := ml_$spin_lock(scsi_lock);
  req^.next := nil;
  if tgt^.pend_head = nil then
    tgt^.pend_head := req
  else
    tgt^.pend_tail^.next := req;
  tgt^.pend_tail := req;
  ml_$spin_unlock(scsi_lock, token);
end;
