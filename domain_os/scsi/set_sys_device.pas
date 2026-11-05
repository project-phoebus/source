%if scsi_mailbox_ctlr %then
{ SCSI_$SET_SYS_DEVICE - make a device a system device.

  Image addresses:
    sau7  0x3C4B8AFC  SCSI_$SET_SYS_DEVICE

  - With the mailbox host adapter: the record gets the system device
    flag and the command routine; scsi_get_tinfo's status is replaced.

  Status stored:
    status_$ok: the device is a system device
    status_$scsi_device_not_acquired: the record is not in use
}

procedure scsi_$set_sys_device(in handle: scsi_$handle_t;
                               in cmd_proc: scsi_$sys_cmd_proc_t;
                               out status: status_$t);
var
  t: scsi_tinfo_ptr_t;
begin
  t := scsi_get_tinfo(handle.all, status);
  if not (scsi_tf_in_use in t^.flags) then
    status.all := status_$scsi_device_not_acquired
  else begin
    status.all := status_$ok;
    t^.flags := t^.flags + [scsi_tf_sys];
    t^.sys_proc := cmd_proc;
  end;
end;
%else
{ SCSI_$SET_SYS_DEVICE - make a device a system device.

  Image addresses:
    sau9  0x3C4A559C  SCSI_$SET_SYS_DEVICE

  - A system device survives its process (SCSI_$FREE_ASID) and takes
    SCSI_$DO_SYS_DEVICE_CMD's commands, through cmd_proc.

  Status stored:
    status_$ok: the device is a system device
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
}

procedure scsi_$set_sys_device(in handle: scsi_$handle_t;
                               in cmd_proc: scsi_$sys_cmd_proc_t;
                               out status: status_$t);
var
  tgt: scsi_target_ptr_t;
begin
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
  status.all := status_$ok;
  tgt^.sys_device := true;
  tgt^.sys_cmd_proc := cmd_proc;
end;
%endif
