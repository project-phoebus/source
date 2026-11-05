%if scsi_mailbox_ctlr %then
{ SCSI_$DO_COMMAND_PHYS - start a command on physical pages.

  Image addresses:
    sau7  0x3C4B8860  SCSI_$DO_COMMAND_PHYS

  - With the mailbox host adapter: the command is posted with the first
    page's address as the data's (scsi_post_cmd) under
    scsi_$exclusion_lock, with the device's next command id, which the
    device keeps when the command was posted.

  Status stored:
    scsi_get_tinfo's status: the handle is not the caller's
    status_$scsi_bad_length: len or the pages past scsi_$max_transfer
    scsi_post_cmd's status: otherwise
}

procedure scsi_$do_command_phys(in handle: scsi_$handle_t;
                                in cdb: scsi_$cdb_t;
                                in pages: scsi_$phys_list_t;
                                in npages: pinteger;
                                in len: linteger;
                                in dir: integer;
                                out id: integer32;
                                out status: status_$t);
var
  t: scsi_tinfo_ptr_t;
  st: status_$t;
  pa: integer32;
  next: integer32;
begin
  t := scsi_get_tinfo(handle.all, status);
  if status.all <> status_$ok then
    return;
  if (len > scsi_$max_transfer)
     or else (integer32(npages) * 1024 > scsi_$max_transfer) then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  st := status;
  ml_$exclusion_start(scsi_$exclusion_lock);
  next := t^.next_id + 1;
  pa := pages[1];
  scsi_post_cmd(t^, cdb, pa, len, dir, next, st);
  if st.all = status_$ok then
    t^.next_id := next;
  ml_$exclusion_stop(scsi_$exclusion_lock);
  status := st;
  id := next;
end;
%else
{ SCSI_$DO_COMMAND_PHYS - start a command on physical pages.

  Image addresses:
    sau9  0x3C4A505C  SCSI_$DO_COMMAND_PHYS

  - The pages are physical addresses, mapped through SCSI_PAGE when the
    transfer starts; the buffer starts at the first page's start.
  - Group 0 and 1 commands (6 and 10 bytes) only, not linked.
  - Queues the request and returns its id; starts the bus when neither
    the target nor the bus is busy.

  Status stored:
    status_$ok: the command was queued
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_bad_length: more than 32 pages
    status_$scsi_unsupported_function: another group, or a linked command
    scsi_get_req's status: no request was free
}

procedure scsi_$do_command_phys(in handle: scsi_$handle_t;
                                in cdb: scsi_$cdb_t;
                                in pages: scsi_$phys_list_t;
                                in npages: pinteger;
                                in len: linteger;
                                in dir: integer;
                                out id: integer32;
                                out status: status_$t);
var
  tgt: scsi_target_ptr_t;
  cb: scsi_cb_ptr_t;
  cdb_len: integer32;
  st: status_$t;
  req: scsi_req_ptr_t;
  i: integer;
  next_id: integer32;
  req_id: integer32;
  token: integer;
begin
  status.all := status_$ok;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  tgt := addr(scsi_$cb[handle.bus].target[handle.target]);
  if not tgt^.allocated then begin
    status.all := status_$scsi_device_not_acquired;
    return;
  end;
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  if npages * 1024 > scsi_$max_transfer then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  cb := addr(scsi_$cb[handle.bus]);
  if ord(cdb.b[0]) <= 31 then
    cdb_len := 6
  else if ord(cdb.b[0]) <= 63 then
    cdb_len := 10
  else begin
    status.all := status_$scsi_unsupported_function;
    return;
  end;
  if odd(ord(cdb.b[cdb_len - 1])) then begin
    status.all := status_$scsi_unsupported_function;
    return;
  end;

  st := status;
  ml_$exclusion_start(scsi_$exclusion_lock);
  req := scsi_get_req(cb, st);
  if st.all <> status_$ok then
    ml_$exclusion_stop(scsi_$exclusion_lock)
  else begin
    req^.cdb := cdb;
    req^.cdb_len := cdb_len;
    req^.buf_va := 0;
    for i := 1 to 32 do
      req^.pages[i] := pages[i];
    req^.length := len;
    req^.offset := 0;
    if (len & 1023) = 0 then
      req^.npages := rshft(len, 10)
    else
      req^.npages := rshft(len, 10) + 1;
    req^.dir := dir;
    req^.mapped := true;
    req^.ppn_list := false;
    req^.result.status.all := status_$ok;
    req^.result.scsi_status := scsi_$st_other;
    next_id := tgt^.next_id + 1;
    req^.result.id := next_id;
    tgt^.next_id := next_id;
    scsi_queue_req(tgt, req);
    req_id := req^.result.id;
    token := ml_$spin_lock(scsi_lock);
    if (tgt^.active = false) and then (cb^.connected = false) then
      scsi_start_next(cb);
    ml_$spin_unlock(scsi_lock, token);
    ml_$exclusion_stop(scsi_$exclusion_lock);
    id := req_id;
  end;
  status := st;
end;
%endif
