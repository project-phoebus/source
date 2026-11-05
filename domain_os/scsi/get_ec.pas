%if scsi_mailbox_ctlr %then
{ SCSI_$GET_EC - return a device's eventcount.

  Image addresses:
    sau7  0x3C4B8B48  SCSI_$GET_EC

  - With the mailbox host adapter: only eventcount 0, the device's
    commands' ends, registered with EC2_.

  Status stored:
    status_$ok: the eventcount was returned
    status_$scsi_bad_parameter: which is not 0
    scsi_get_tinfo's status: the handle is not the caller's
    ec2_$register_ec1's status, its fail bit set: it failed
}

procedure scsi_$get_ec(in handle: scsi_$handle_t; in which: integer;
                       out ec: ec2_$ptr_t; out status: status_$t);
var
  t: scsi_tinfo_ptr_t;
begin
  if which <> 0 then
    status.all := status_$scsi_bad_parameter
  else begin
    t := scsi_get_tinfo(handle.all, status);
    if status.all = status_$ok then begin
      ec := ec2_$register_ec1(addr(t^.done_ec), status);
      status.fail := status.all <> status_$ok;
    end;
  end;
end;
%else
{ SCSI_$GET_EC - return a device's eventcount.

  Image addresses:
    sau9  0x3C4A5622  SCSI_$GET_EC

  - The target's eventcount, advanced each time one of its requests
    ends, registered as a level-2 eventcount.  Only eventcount 0 exists.

  Status stored:
    status_$scsi_bad_parameter: which is not 0
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    EC2_$REGISTER_EC1's status, its fail bit set when not ok
}

procedure scsi_$get_ec(in handle: scsi_$handle_t; in which: integer;
                       out ec: ec2_$ptr_t; out status: status_$t);
var
  tgt: scsi_target_ptr_t;
begin
  if which <> 0 then begin
    status.all := status_$scsi_bad_parameter;
    return;
  end;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  tgt := addr(scsi_$cb[handle.bus].target[handle.target]);
  if not tgt^.allocated then
    status.all := status_$scsi_device_not_acquired
  else
    status.all := status_$ok;
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  if status.all = status_$ok then begin
    ec := ec2_$register_ec1(addr(tgt^.ec), status);
    status.fail := status.all <> status_$ok;
  end;
end;
%endif
