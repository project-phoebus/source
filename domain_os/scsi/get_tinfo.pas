{ scsi_get_tinfo - the device record a handle names.

  Image addresses:
    sau7  0x3C4B8084  scsi_get_tinfo (module-local)

  - The handle's low word is the device's number; the record must be in
    use, and its owner the current process or scsi_any_owner.
  - Returns the record, nil for a number past scsi_max_dev.

  Status stored:
    status_$ok: the record may be used
    status_$scsi_bad_handle: the number is past scsi_max_dev
    status_$scsi_device_not_acquired: the record is not in use
    status_$scsi_device_in_use: another process owns it
}

function scsi_get_tinfo(handle: integer32;
                        out status: status_$t): scsi_tinfo_ptr_t; internal;
var
  h: scsi_$handle_t;
  t: scsi_tinfo_ptr_t;
begin
  status.all := status_$ok;
  h.all := handle;
  if h.dev > scsi_max_dev then begin
    t := nil;
    status.all := status_$scsi_bad_handle;
  end
  else begin
    t := addr(scsi_$tinfo_list[h.dev]);
    if not (scsi_tf_in_use in t^.flags) then
      status.all := status_$scsi_device_not_acquired
    else if t^.owner = scsi_any_owner then
      status.all := status_$ok
    else if t^.owner <> proc1_$current then
      status.all := status_$scsi_device_in_use;
  end;
  scsi_get_tinfo := t;
end;
