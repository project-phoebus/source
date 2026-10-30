{ DISK_$FORMAT_WHOLE - format a whole volume.

  Image addresses:
    sau2  0x00E3D296  DISK_$FORMAT_WHOLE

  - One queue block (operation 10) goes to the volume's driver through
    DISK_$DO_IO; a queued request is waited for and the block returned.
  - The index test is the set's bit modulo 32.

  Status stored:
    the request's status: the volume was formatted, or not
    status_$invalid_volume_index: an index outside 1..10
    status_$volume_not_properly_mounted: the volume is not the caller's
}

procedure disk_$format_whole(in vol_idx: integer; out status: status_$t);
var
  tail: disk_$io_req_ptr_t;
  err_wait: integer32;
  io_wait: integer32;
  head: disk_$io_req_ptr_t;
  queued: boolean;
  req: disk_$io_req_ptr_t;
begin
  if not (vol_idx in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  if (disk_$dvtbl[vol_idx].mount_state <> 2) or else
     (disk_$dvtbl[vol_idx].mount_proc <> proc1_$current) then begin
    status.all := status_$volume_not_properly_mounted;
    return;
  end;

  disk_$get_qblks_internal(1, false, head, tail);
  req := head;
  io_wait := disk_bptbl[proc1_$current].io_ec.value + 1;
  err_wait := disk_bptbl[proc1_$current].err_ec.value + 1;

  req^.owner_op.op := disk_$req_op_format_whole;
  disk_$do_io(disk_$dvtbl[vol_idx], req^, req^, queued);

  if queued then
    disk_$wait_io([vol_idx], io_wait, err_wait);

  status := req^.status;
  disk_$rtn_qblks_internal(1, req, tail);
end;
