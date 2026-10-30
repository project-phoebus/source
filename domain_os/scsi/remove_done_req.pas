{ scsi_remove_done_req - take a request off a target's done list and free
  it.

  Image addresses:
    sau9  0x3C4A4CAA  scsi_remove_done_req

  Assume we're called with the SCSI spin lock held.

  - A request not on the list is left alone.
}

procedure scsi_remove_done_req(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                               req: scsi_req_ptr_t); internal;
var
  p: scsi_req_ptr_t;
  q: scsi_req_ptr_t;
  found: boolean;
begin
  p := tgt^.done_head;
  found := false;
  if p <> nil then begin
    if req = p then begin
      found := true;
      tgt^.done_head := p^.next;
    end
    else
      while p <> nil do begin
        if req = p^.next then begin
          q := p^.next;
          found := true;
          p^.next := q^.next;
          if req = tgt^.done_tail then
            tgt^.done_tail := p;
          exit;
        end;
        p := p^.next;
      end;
    if found then begin
      if tgt^.done_head = nil then
        tgt^.done_tail := nil;
      scsi_free_req(cb, req);
    end;
  end;
end;
