{ scsi_map_buffer - map a buffer's pages into a device's I/O map
  region.

  Image addresses:
    sau7  0x3C4B84B8  scsi_map_buffer (module-local)

  - The region is first unmapped whole; each 1 KB page of the buffer
    must be wired for the device (scsi_va_to_ppn).  A page that is not
    unmaps the pages mapped so far.
  - Returns the buffer's offset in its first page or'ed into base.

  Status stored:
    iomap_$map's status: the pages were mapped (status_$ok)
    status_$scsi_internal_error: the device has no region
    status_$scsi_buffer_too_large: the buffer does not fit the region
    status_$scsi_page_not_wired: a page is not wired for the device
    iomap_$map's status, its fail bit set: it failed
}

function scsi_map_buffer(var t: scsi_tinfo_t; va: integer32;
                         len: integer32; base: integer32;
                         out status: status_$t): integer32; internal;
var
  cb: scsi_mb_cb_ptr_t;
  off: integer32;
  pages: integer;
  i: integer;
  iova: integer32;
  p: integer32;
  ppn: array[1..1] of integer32;
begin
  cb := addr(scsi_$cb[t.bus]);
  if not (scsi_tf_wired in t.flags) then begin
    status.all := status_$scsi_internal_error;
    return;
  end;
  off := va & 16#3FF;
  if off + len > t.iova_end - t.iova then begin
    status.all := status_$scsi_buffer_too_large;
    return;
  end;
  pages := rshft(va + len - 1, 10) - rshft(va, 10) + 1;
  iova := t.iova;
  iomap_$unmap(cb^.map_bus, iova, (t.iova_end - iova) div 1024);
  for i := 0 to pages - 1 do begin
    p := scsi_va_to_ppn(t.dev, va);
    if p = 0 then begin
      iomap_$unmap(cb^.map_bus, t.iova, i);
      status.all := status_$scsi_page_not_wired;
      return;
    end;
    ppn[1] := p;
    iomap_$map(cb^.map_bus, iova, ppn, 0, 1, 0, status);
    if status.all <> status_$ok then begin
      status.fail := true;
      return;
    end;
    iova := iova + 1024;
    va := va + 1024;
  end;
  scsi_map_buffer := off ! base;
end;
