%if scsi_mailbox_ctlr %then
{ SCSI_$WIRE - wire a device's buffer.

  Image addresses:
    sau7  0x3C4B9588  SCSI_$WIRE

  - With the mailbox host adapter: a buffer of the process's private
    space, whose pages leave the pageable pages above their lower limit,
    is wired a 1 KB page at a time for the device (scsi_wire_page) under
    the spin lock.  A page already wired ends the wiring; another
    failure unwires the pages wired before it (a failure of that crashes
    the system).

  Status stored:
    status_$ok: the pages were wired
    scsi_get_tinfo's status: the handle is not the caller's
    status_$scsi_bad_length: len is not positive
    status_$scsi_protection_violation: the buffer is below the private
      space
    status_$scsi_too_many_wired_pages: too few pageable pages would be
      left
    status_$scsi_page_already_wired: a page is wired for the device
    scsi_wire_page's status, its fail bit set: a page could not be wired
}

procedure scsi_$wire(in handle: scsi_$handle_t; in buf: univ char;
                     in len: integer32; out status: status_$t);
var
  t: scsi_tinfo_ptr_t;
  dev: integer;
  va: integer32;
  pages: integer;
  i: integer;
  j: integer;
  token: pinteger;
  st: status_$t;
  st2: status_$t;
begin
  t := scsi_get_tinfo(handle.all, status);
  if status.all <> status_$ok then
    return;
  dev := t^.dev;
  if status.all <> status_$ok then
    return;
  if len <= 0 then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  va := integer32(addr(buf));
  if linteger(va) < as_$private then begin
    status.all := status_$scsi_protection_violation;
    return;
  end;
  pages := rshft(va + len - 1, 10) - rshft(va, 10) + 1;
  if mmap_$pageable_pages - pages < mmap_$pageable_pages_lower_limit then begin
    status.all := status_$scsi_too_many_wired_pages;
    return;
  end;
  st := status;
  token := ml_$spin_lock(scsi_lock);
  for i := 1 to pages do begin
    discard(scsi_wire_page(dev, va, st));
    if st.all <> status_$ok then begin
      if st.all = status_$scsi_page_already_wired then
        exit;
      for j := 1 to i - 1 do begin
        va := va - 1024;
        scsi_unwire_page(dev, mst_$find(va, 0), st2);
        if st2.all <> status_$ok then
          crash_system(st2);
      end;
      st.fail := true;
      exit;
    end;
    va := va + 1024;
  end;
  ml_$spin_unlock(scsi_lock, token);
  status := st;
end;
%else
{ SCSI_$WIRE - wire a device's buffer.

  Image addresses:
    sau9  0x3C4A6D30  SCSI_$WIRE

  - The buffer must be in the process's private space and leave the
    pageable pages above their lower limit.
  - A page the device has wired already stops the loop, keeping the
    pages before it; any other failure unwires them again (crashing if
    that fails) and sets the status's fail bit.

  Status stored:
    status_$ok: the buffer was wired
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_not_acquired: the device is not set up
    status_$scsi_bad_length: len is not positive
    status_$scsi_protection_violation: the buffer is below the private
      space
    status_$scsi_too_many_wired_pages: too few pageable pages would be
      left
    status_$scsi_page_already_wired: a page was wired already
    MST_$WIRE's status, its fail bit set: a page could not be wired
}

procedure scsi_$wire(in handle: scsi_$handle_t; in buf: univ char;
                     in len: integer32; out status: status_$t);
var
  tgt: scsi_target_ptr_t;
  dev: integer;
  va: integer32;
  last: integer32;
  npages: integer;
  i: integer;
  j: integer;
  st: status_$t;
  st2: status_$t;
  token: integer;
begin
  status.all := status_$ok;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  tgt := addr(scsi_$cb[handle.bus].target[handle.target]);
  if not tgt^.allocated then
    status.all := status_$scsi_device_not_acquired;
  if tgt^.gen <> handle.gen then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  dev := handle.bus * 8 + handle.target;
  if status.all <> status_$ok then
    return;
  if len <= 0 then begin
    status.all := status_$scsi_bad_length;
    return;
  end;
  va := integer32(addr(buf));
  if linteger(va) < as_$private then begin
    status.all := status_$scsi_protection_violation;
    return;
  end;
  last := va + len - 1;
  npages := rshft(last, 10) - rshft(va, 10) + 1;
  if mmap_$pageable_pages - npages
     < mmap_$pageable_pages_lower_limit then begin
    status.all := status_$scsi_too_many_wired_pages;
    return;
  end;

  st := status;
  token := ml_$spin_lock(scsi_lock);
  for i := 1 to npages do begin
    discard(scsi_wire_page(dev, va, st));
    if st.all <> status_$ok then begin
      if st.all <> status_$scsi_page_already_wired then begin
        for j := 1 to i - 1 do begin
          va := va - 1024;
          scsi_unwire_page(dev, mst_$find(va, 0), st2);
          if st2.all <> status_$ok then
            crash_system(st2);
        end;
        st.fail := true;
      end;
      exit;
    end;
    va := va + 1024;
  end;
  ml_$spin_unlock(scsi_lock, token);
  status := st;
end;
%endif
