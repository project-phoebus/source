%if scsi_mailbox_ctlr %then
{ SCSI_$DO_COMMAND - start a command on a buffer.

  Image addresses:
    sau7  0x3C4B891E  SCSI_$DO_COMMAND

  - With the mailbox host adapter: the command's group gives its length
    (6 bytes for groups 0, 10 for 1); a set link bit is refused, as is
    another group.  Under scsi_$exclusion_lock a buffer is mapped into
    the device's I/O map region, which is allocated first when the
    device has none, and allocated again when the buffer does not fit;
    the command is posted with the device's next command id.

  Status stored:
    scsi_get_tinfo's status: the handle is not the caller's
    status_$scsi_bad_length: len past scsi_$max_transfer
    status_$scsi_unsupported_function: the command's group or link bit
    status_$scsi_command_in_progress: a transfer is outstanding
    the region's, the mapping's or scsi_post_cmd's status: otherwise
}

procedure scsi_$do_command(in handle: scsi_$handle_t; in cdb: scsi_$cdb_t;
                           in buf: univ char; in len: integer32;
                           in dir: integer; out id: integer32;
                           out status: status_$t);
label
  9;
var
  t: scsi_tinfo_ptr_t;
  n: integer;
  next: integer32;
  iova: integer32;
  st: status_$t;
begin
  t := scsi_get_tinfo(handle.all, status);
  if status.all <> status_$ok then
    return;
  if linteger(len) > scsi_$max_transfer then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  if ord(cdb.b[0]) <= 31 then
    n := 6
  else if ord(cdb.b[0]) <= 63 then
    n := 10
  else begin
    status.all := status_$scsi_unsupported_function;
    return;
  end;
  if odd(ord(cdb.b[n - 1])) then begin
    status.all := status_$scsi_unsupported_function;
    return;
  end;
  ml_$exclusion_start(scsi_$exclusion_lock);
  next := t^.next_id + 1;
  st.all := status_$ok;
  if len <> 0 then begin
    if not (scsi_tf_wired in t^.flags) then
      discard(scsi_alloc_iova(t^, len, st))
    else if scsi_tf_busy in t^.flags then
      st.all := status_$scsi_command_in_progress;
    if st.all <> status_$ok then
      goto 9;
    iova := scsi_map_buffer(t^, integer32(addr(buf)), len, t^.iova, st);
    if st.all = status_$scsi_buffer_too_large then begin
      scsi_free_iova(t^, st);
      if st.all <> status_$ok then
        goto 9;
      discard(scsi_alloc_iova(t^, len, st));
      if st.all <> status_$ok then
        goto 9;
      iova := scsi_map_buffer(t^, integer32(addr(buf)), len, t^.iova, st);
    end;
  end
  else
    iova := 0;
  if st.all = status_$ok then begin
    scsi_post_cmd(t^, cdb, iova, len, dir, next, st);
    if st.all = status_$ok then
      t^.next_id := next;
  end;
9:
  ml_$exclusion_stop(scsi_$exclusion_lock);
  status := st;
  id := next;
end;
%else
{ SCSI_$DO_COMMAND - start a command on a buffer.

  Image addresses:
    sau9  0x3C4A5252  SCSI_$DO_COMMAND

  - The buffer's pages must be wired for the device (SCSI_$WIRE); a
    user buffer's pages are wired once more for the transfer, which
    SCSI_$WAIT undoes.
  - Group 0 and 1 commands (6 and 10 bytes) only, not linked; at most
    32768 bytes.
  - Queues the request and returns its id; starts the bus when neither
    the target nor the bus is busy.

  Status stored:
    status_$ok: the command was queued
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_unsupported_function: another group, or a linked command
    status_$scsi_bad_length: more than 32768 bytes
    status_$scsi_page_not_wired: a page of the buffer is not wired
    scsi_get_req's status: no request was free
}

procedure scsi_$do_command(in handle: scsi_$handle_t; in cdb: scsi_$cdb_t;
                           in buf: univ char; in len: integer32;
                           in dir: integer; out id: integer32;
                           out status: status_$t);
var
  cdb_copy: scsi_$cdb_t;
  length: integer32;
  direction: integer;
  buf_va: integer32;
  tgt: scsi_target_ptr_t;
  dev: integer;
  cdb_len: integer32;
  va: integer32;
  last: integer32;
  npages: pinteger;
  offset: integer32;
  i: pinteger;
  ppns: scsi_page_list_t;
  t: scsi_target_ptr_t;
  cb: scsi_cb_ptr_t;
  st: status_$t;
  req: scsi_req_ptr_t;
  next_id: integer32;
  req_id: integer32;
  token: integer;
begin
  status.all := status_$ok;
  cdb_copy := cdb;
  length := len;
  direction := dir;
  buf_va := integer32(addr(buf));
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  tgt := addr(scsi_$cb[handle.bus].target[handle.target]);
  dev := handle.bus * 8 + handle.target;
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
  if not tgt^.allocated then
    status.all := status_$scsi_device_not_acquired;
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  if status.all <> status_$ok then
    return;
  if linteger(length) > scsi_$max_transfer then begin
    status.all := status_$scsi_bad_length;
    return;
  end;

  { The buffer's pages, wired for the device. }
  va := integer32(addr(buf));
  last := va + length - 1;
  if length <> 0 then
    npages := rshft(last, 10) - rshft(va, 10) + 1
  else
    npages := 0;
  offset := va & 1023;
  for i := 1 to npages do begin
    ppns[i] := scsi_va_to_ppn(dev, va);
    if ppns[i] = 0 then begin
      status.all := status_$scsi_page_not_wired;
      return;
    end;
    va := va + 1024;
  end;

  t := tgt;
  cb := addr(scsi_$cb[handle.bus]);
  st := status;
  ml_$exclusion_start(scsi_$exclusion_lock);
  req := scsi_get_req(cb, st);
  if st.all <> status_$ok then begin
    ml_$exclusion_stop(scsi_$exclusion_lock);
    status := st;
    return;
  end;
  req^.cdb := cdb_copy;
  req^.cdb_len := cdb_len;
  req^.buf_va := buf_va;
  req^.length := length;
  req^.offset := 0;
  req^.mapped := true;
  req^.ppn_list := true;
  req^.pages := ppns;
  req^.npages := npages;
  req^.offset := offset;
  if linteger(req^.buf_va) < 16#3C000000 then
    for i := 1 to req^.npages do
      wp_$wire(ppns[i]);
  req^.dir := direction;
  req^.result.status.all := status_$ok;
  req^.result.scsi_status := scsi_$st_other;
  next_id := tgt^.next_id + 1;
  req^.result.id := next_id;
  tgt^.next_id := next_id;
  scsi_queue_req(tgt, req);
  req_id := req^.result.id;
  token := ml_$spin_lock(scsi_lock);
  if (t^.active = false) and then (cb^.connected = false) then
    scsi_start_next(cb);
  ml_$spin_unlock(scsi_lock, token);
  ml_$exclusion_stop(scsi_$exclusion_lock);
  status := st;
  id := req_id;
end;
%endif
