{ SCSI_$GET_INFO - return the driver's limits.

  Image addresses:
    sau9  0x3C4A56D2  SCSI_$GET_INFO

  - Version 1, transfers of up to 32768 bytes; size is the caller's
    buffer's, at least 8 bytes.

  Status stored:
    status_$ok: the limits were returned
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_bad_length: size is less than 8
}

procedure scsi_$get_info(in handle: scsi_$handle_t; in size: pinteger;
                         out info: scsi_$info_t; out status: status_$t);
var
  tgt: scsi_target_ptr_t;
begin
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
  if status.all = status_$ok then
    if size < 8 then
      status.all := status_$scsi_bad_length
    else begin
      info.version := 1;
      info.max_transfer := scsi_$max_transfer;
    end;
end;
