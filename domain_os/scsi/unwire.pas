%if scsi_mailbox_ctlr %then
{ SCSI_$UNWIRE - unwire a device's buffer.

  Image addresses:
    sau7  0x3C4B92A8  SCSI_$UNWIRE

  - With the mailbox host adapter: with touch, a word of each 1 KB page
    of the buffer is read and written back first; then under
    scsi_$exclusion_lock each page is unwired for the device
    (scsi_unwire_page), up to the first failure.
  - A record not in use stores its status, and the unwiring goes on.

  Status stored:
    status_$ok: the pages were unwired
    scsi_get_tinfo's status: the handle is not the caller's
    status_$scsi_device_not_acquired: the record is not in use
    status_$scsi_bad_length: len is not positive
    status_$scsi_page_not_wired: a page has no physical page, or is not
      wired for the device
}

procedure scsi_$unwire(in handle: scsi_$handle_t; in buf: univ char;
                       in len: integer32; in touch: boolean;
                       out status: status_$t);
type
  word_ptr_t = ^integer;
var
  t: scsi_tinfo_ptr_t;
  dev: integer;
  va: integer32;
  pages: integer;
  i: integer;
  ppn: integer32;
  st: status_$t;
begin
  status.all := status_$ok;
  t := scsi_get_tinfo(handle.all, status);
  if status.all <> status_$ok then
    return;
  dev := t^.dev;
  if status.all <> status_$ok then
    return;
  if not (scsi_tf_in_use in t^.flags) then
    status.all := status_$scsi_device_not_acquired;
  if len <= 0 then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  va := integer32(addr(buf));
  pages := rshft(va + len - 1, 10) - rshft(va, 10) + 1;
  if touch then begin
    for i := 1 to pages do begin
      word_ptr_t(va)^ := word_ptr_t(va)^;
      va := va + 1024;
    end;
    va := integer32(addr(buf));
  end;
  st := status;
  ml_$exclusion_start(scsi_$exclusion_lock);
  for i := 1 to pages do begin
    ppn := mst_$find(va, 0);
    if ppn = 0 then
      st.all := status_$scsi_page_not_wired
    else
      st.all := status_$ok;
    if st.all <> status_$ok then
      exit;
    scsi_unwire_page(dev, ppn, st);
    if st.all <> status_$ok then
      exit;
    va := va + 1024;
  end;
  ml_$exclusion_stop(scsi_$exclusion_lock);
  status := st;
end;
%else
{ SCSI_$UNWIRE - unwire a device's buffer.

  Image addresses:
    sau9  0x3C4A690E  SCSI_$UNWIRE

  - With touch, each page of the buffer is first written (a word read
    and written back), so that it is kept as modified.
  - Stops at the first page that is not wired for the device.
  - A device not set up is refused with
    status_$scsi_device_not_acquired, which the first page's outcome
    then replaces.

  Status stored:
    status_$ok: the buffer was unwired
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_bad_length: len is not positive
    status_$scsi_page_not_wired: a page of the buffer has no page, or is
      not wired for the device
}

procedure scsi_$unwire(in handle: scsi_$handle_t; in buf: univ char;
                       in len: integer32; in touch: boolean;
                       out status: status_$t);
type
  word_ptr_t = ^pinteger;
var
  tgt: scsi_target_ptr_t;
  dev: integer;
  va: integer32;
  last: integer32;
  npages: integer;
  i: integer;
  st: status_$t;
  ppn: integer32;
begin
  status.all := status_$ok;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  tgt := addr(scsi_$cb[handle.bus].target[handle.target]);
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  dev := handle.bus * 8 + handle.target;
  if status.all <> status_$ok then
    return;
  if not tgt^.allocated then
    status.all := status_$scsi_device_not_acquired;
  if len <= 0 then begin
    status.all := status_$scsi_bad_length;
    return;
  end;

  va := integer32(addr(buf));
  last := va + len - 1;
  npages := rshft(last, 10) - rshft(va, 10) + 1;
  if touch then begin
    for i := 1 to npages do begin
      word_ptr_t(va)^ := word_ptr_t(va)^;
      va := va + 1024;
    end;
    va := integer32(addr(buf));
  end;

  st := status;
  ml_$exclusion_start(scsi_$exclusion_lock);
  for i := 1 to npages do begin
    ppn := mst_$find(va, 0);
    if ppn = 0 then
      st.all := status_$scsi_page_not_wired
    else
      st.all := status_$ok;
    if st.all <> status_$ok then
      exit;
    scsi_unwire_page(dev, ppn, st);
    if st.all <> status_$ok then
      exit;
    va := va + 1024;
  end;
  ml_$exclusion_stop(scsi_$exclusion_lock);
  status := st;
end;
%endif
