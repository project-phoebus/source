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
