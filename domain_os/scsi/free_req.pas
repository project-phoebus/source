{ scsi_free_req - put a request back on its bus's free list.

  Image addresses:
    sau9  0x3C4A4C44  scsi_free_req

  - The bus's free eventcount advances when the list was empty.
}

procedure scsi_free_req(cb: scsi_cb_ptr_t; req: scsi_req_ptr_t); internal;
var
  token: integer;
begin
  token := ml_$spin_lock(scsi_lock);
  req^.next := nil;
  cb^.free_count := cb^.free_count + 1;
  if cb^.free_head = nil then begin
    cb^.free_head := req;
    cb^.free_tail := req;
    ec_$advance_without_dispatch(cb^.free_ec);
  end
  else begin
    cb^.free_tail^.next := req;
    cb^.free_tail := req;
  end;
  ml_$spin_unlock(scsi_lock, token);
end;
