{ scsi_complete_req - move a target's first pending request to its done
  list.

  Image addresses:
    sau9  0x3C4A6ECE  scsi_complete_req

  Assume we're called with the SCSI spin lock held.

  - The target's eventcount advances (its value is the last done
    request's id).
}

procedure scsi_complete_req(tgt: scsi_target_ptr_t);
var
  req: scsi_req_ptr_t;
begin
  req := tgt^.pend_head;
  tgt^.pend_head := req^.next;
  req^.next := nil;
  if tgt^.pend_head = nil then
    tgt^.pend_tail := nil;
  if tgt^.done_head = nil then
    tgt^.done_head := req
  else
    tgt^.done_tail^.next := req;
  tgt^.done_tail := req;
  ec_$advance_without_dispatch(tgt^.ec);
end;
