{ scsi_alloc_iova - give a device an I/O map region for a buffer.

  Image addresses:
    sau7  0x3C4B83B8  scsi_alloc_iova (module-local)

  - The region covers len bytes at any alignment, in 1 KB pages, from
    IO_$ALLOC of the bus's unit; it is noted in the device's record.
  - Returns the region's bus address, 0 on a failure.

  Status stored:
    status_$ok: the region was allocated
    status_$scsi_device_already_allocated: the device has one
    status_$scsi_bad_length: len is not positive
    io_$alloc's status, its fail bit set: it failed
}

function scsi_alloc_iova(var t: scsi_tinfo_t; len: integer32;
                         out status: status_$t): integer32; internal;
var
  cb: scsi_mb_cb_ptr_t;
  pages: integer;
  size: integer32;
  iova: integer32;
  result: integer32;
begin
  result := 0;
  cb := addr(scsi_$cb[t.bus]);
  if scsi_tf_wired in t.flags then
    status.all := status_$scsi_device_already_allocated
  else if len <= 0 then
    status.all := status_$scsi_bad_length
  else begin
    pages := (len + 1022) div 1024 + 1;
    size := integer32(pages) * 1024;
    iova := io_$alloc(cb^.unit, size, true, 0, status);
    if status.all <> status_$ok then
      status.fail := true
    else begin
      result := iova;
      t.flags := t.flags + [scsi_tf_wired];
      t.iova := iova;
      t.iova_end := size + iova;
    end;
  end;
  scsi_alloc_iova := result;
end;
