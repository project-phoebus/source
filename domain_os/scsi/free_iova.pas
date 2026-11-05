{ scsi_free_iova - free a device's I/O map region.

  Image addresses:
    sau7  0x3C4B8458  scsi_free_iova (module-local)

  Status stored:
    io_$free's status: the region was freed (status_$ok)
    status_$scsi_internal_error: the device has no region
    io_$free's status, its fail bit set: it failed
}

procedure scsi_free_iova(var t: scsi_tinfo_t; out status: status_$t);
  internal;
var
  cb: scsi_mb_cb_ptr_t;
begin
  cb := addr(scsi_$cb[t.bus]);
  if not (scsi_tf_wired in t.flags) then
    status.all := status_$scsi_internal_error
  else begin
    io_$free(cb^.unit, t.iova, status);
    if status.all <> status_$ok then
      status.fail := true
    else
      t.flags := t.flags - [scsi_tf_wired];
  end;
end;
