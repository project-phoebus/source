{ SM_C_$DO_IO - perform a chain of disk requests on an SM_C drive.

  Image addresses:
    sau5  0x00E75386  SM_C_$DO_IO

  - Runs under the controller's ML lock (its DCTE's disk_error_que_hi);
    a format request goes to sm_c_$format, a chain of writes is sorted.
  - At most seven tries; a correctable data error is corrected (unless
    the request asked for a checksum) and the chain goes on.
  - A drive not ready, or the third try, brings the drive up again.
  - On an error the requesting process's pending flag is cleared, the
    status goes into the current request, and later requests get -1.

  Status stored: none.
}

procedure sm_c_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
label
  again, done, failed, unlock;
var
  op: integer;
  head: disk_$io_req_ptr_t;
  unit_rec: ^sm_c_$unit_t;
  cmd: integer;
  status: integer32;
  try: integer;
  count: integer;
begin
  result := false;
  head := addr(req);
  op := req.owner_op.op;
  if op = 3 then begin
    ml_$lock(sm_c_dcte^.disk_error_que_hi);
    sm_c_$format(vol, req);
    goto unlock;
  end;
  if (op = 2) and (req.next <> nil) then
    disk_$sort(vol, head);
  ml_$lock(sm_c_dcte^.disk_error_que_hi);

  sm_c_req := head;
  sm_c_vol := addr(vol);
  unit_rec := addr(sm_$cb.c_unit[vol.dev_unit]);
  if sm_c_req^.owner_op.op = 2 then begin
    cmd := sm_c_cmd_write;
    sm_c_hdr^ := sm_c_req^.header.l;
  end
  else
    cmd := sm_c_cmd_read;

  try := 1;
  for count := 1 to 7 do begin
again:
%if long_iomap %then
    sm_c_iomap_entry^ := sm_c_req^.ppn + sm_iomap_bias;
%else
    { the SAU3's and SAU4's entry (the TODO(sau) in sm/cinit.pas) }
%endif
    sm_$cb.c_daddr.cyl_lo := sm_c_req^.daddr.cyl & 16#FF;
    sm_$cb.c_daddr.cyl_hi := rshft(sm_c_req^.daddr.cyl, 8);
    sm_$cb.c_daddr.head := sm_c_req^.daddr.head;
    sm_$cb.c_daddr.sector := sm_c_req^.daddr.sector;
    sm_$cb.c_count := 1;
    sm_$cb.c_buf_lo := sm_c_hdr_lo.lo;
    sm_$cb.c_buf_mid := sm_c_hdr_mid.lo;
    sm_$cb.c_cmd := cmd;
    sm_$cb.c_op := 8;
    sm_$cb.c_buf_hi := sm_c_hdr_hi.lo;
    status := sm_c_$command(vol.dev_unit, cmd);
    if status = 0 then
      goto done;

    if sm_$cb.c_status.code = sm_c_code_ecc then begin
      if sm_c_req^.owner_op.chksum then
        exit;
      sm_c_$fix_ecc;
      sm_$cb.c_ecc.all := 0;
    end;
    if (sm_$cb.c_status.code = sm_c_code_ecc) or
       (sm_$cb.c_status.code = sm_c_code_corrected) then begin
      status := 0;
      if sm_c_req^.next = nil then
        exit;
      sm_c_req := sm_c_req^.next;
      goto again;
    end;

    if status = status_$disk_not_ready then begin
      discard(ec_$wait(addr(time_$clockh_ec), addr(ec_$nil_ec),
                       addr(ec_$nil_ec), time_$clockh + 8, 0, 0));
      sm_c_$reinit(vol);
    end
    else if try = 3 then
      sm_c_$reinit(vol);
    try := try + 1;
  end;
  if status <> 0 then
    goto failed;

done:
  if unit_rec^.flags.parity_err then
    status := status_$memory_parity_error_during_disk_write;
  if status = 0 then
    goto unlock;

failed:
  disk_bptbl[sm_c_req^.owner_op.owner].io_pending := false;
  sm_c_req^.status.all := status;
  sm_c_req := sm_c_req^.next;
  while sm_c_req <> nil do begin
    sm_c_req^.status.all := -1;
    sm_c_req := sm_c_req^.next;
  end;

unlock:
  ml_$unlock(sm_c_dcte^.disk_error_que_hi);
end;
