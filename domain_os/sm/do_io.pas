{ SM_$DO_IO - perform a disk request on a storage module drive.

  Image addresses:
    sau3  0x00E6E2BA  SM_$DO_IO
    sau4  0x0F877A02  SM_$DO_IO
    sau5  0x00E6F612  SM_$DO_IO
    sau6  0x78076A5E  SM_$DO_IO

  - Under the controller's lock.  A format request (operation 3) goes
    to sm_$format.
  - At most two tries of the read or write; a failed command resets
    the controller and retries.  A data check on a request with its
    checksum flag set ends the tries.
  - On an error the requester's pending flag is cleared; after a read
    the block header is copied back.
  - result is always false.

  Status stored (in req):
    none: the transfer succeeded
    sm_$format's status: a format request (operation 3)
    status_$storage_module_stopped: a write to a drive not ready, or the
      drive stopped during the transfer
    sm_$reset's status: a failed command, and the reset failed too
    sm_$command's or sm_$check_status's status: both tries failed, or a
      data check on a request with its checksum flag set
    status_$memory_parity_error_during_disk_write: the interrupt saw a
      parity error
}

procedure sm_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; out result: boolean);
label
  failed, unlock;
var
  op: integer;
  unit: integer;
  cmd: integer;
  io_status: integer32;
  rst_status: status_$t;
  try: integer;
begin
  result := false;
  ml_$lock(sm_dcte^.disk_error_que_hi);

  op := req.owner_op.op;
  if op = 3 then begin
    sm_$format(vol, req);
    goto unlock;
  end;

  unit := vol.dev_unit;
  sm_buf_ppn := req.ppn;
  with sm_$cb.drive[unit] do begin
    if op = 2 then begin
      if not ready then begin
        io_status := status_$storage_module_stopped;
        goto failed;
      end;
      stats.xfers[2] := stats.xfers[2] + 1;
      cmd := sm_cmd_write;
      sm_$hdr_ptr_t(sm_dcte^.io_va)^ := req.header.l;
    end
    else begin
      stats.xfers[1] := stats.xfers[1] + 1;
      cmd := sm_cmd_read;
    end;
%if long_iomap %then
    iomap[sm_iomap_buf] := req.ppn + sm_iomap_bias;
%elseif word_iomap %then
    iomap[sm_iomap_buf] := req.ppn;
%else
    iomap[sm_iomap_buf].entry := req.ppn + sm_iomap_bias;
%endif

    for try := 1 to 2 do begin
      sm_$cb.cyl := req.daddr.cyl;
      sm_$cb.head := req.daddr.head;
      sm_$cb.sector := req.daddr.sector;
      sm_$cb.buf_offset := sm_$page_offset(univ_ptr(sm_dcte^.io_va));
      sm_$cb.xfer_word := 16#420;
      io_status := sm_$command(unit, cmd);
      if io_status <> 0 then begin
        sm_$reset(sm_dcte, rst_status);
        if rst_status.all <> 0 then begin
          io_status := rst_status.all;
          goto failed;
        end;
      end
      else begin
        io_status := sm_$check_status(unit);
        if io_status = 0 then
          exit;
        if (io_status = status_$disk_data_check) and
           req.owner_op.chksum then
          exit;
      end;
    end;
    if io_status <> 0 then
      goto failed;

    if not ready then
      io_status := status_$storage_module_stopped;
    if io_status <> 0 then
      goto failed;
%if memory_parity %then
    if parity_err then
      io_status := status_$memory_parity_error_during_disk_write;
%endif
    if io_status = 0 then begin
      if op = 1 then
        req.header.l := sm_$hdr_ptr_t(sm_dcte^.io_va)^;
      goto unlock;
    end;
  end;

failed:
  disk_bptbl[req.owner_op.owner].io_pending := false;
  req.status.all := io_status;

unlock:
  ml_$unlock(sm_dcte^.disk_error_que_hi);
end;
