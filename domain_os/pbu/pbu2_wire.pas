{ PBU2_$WIRE - wire a buffer for a PBU unit.

  Image addresses:
    sau3  0x00E59C4A  PBU2_$WIRE
    sau5  0x00E59EAE  PBU2_$WIRE

  - Under the exclusion lock each page is wired for the unit
    (PBU_$SAVE_PPN).  A page already wired ends the loop; another
    failure unwires the pages wired so far (a failure there crashes the
    system).

  Status stored:
    pbu_$save_ppn's status: the buffer was wired, or a page was wired
      already
    pbu_$save_ppn's status, its fail bit set: a page could not be wired
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_bad_controller_memory_length: length is not positive
    status_$pbu_protection_violation: the buffer is below the private
      address space
    status_$pbu_too_many_wired_pages: MMAP_$PAGEABLE_PAGES would fall
      below MMAP_$PAGEABLE_PAGES_LOWER_LIMIT
}

procedure pbu2_$wire(in unit: integer; in buffer: univ pbu_$buffer_t;
                     in length: linteger; out status: status_$t);
var
  va: linteger;
  npages: integer32;
  i: integer32;
  j: integer32;
  undo_status: status_$t;
begin
  discard(pbu_check_unit(unit, status));
  if status.all <> status_$ok then
    return;
  if length <= 0 then begin
    status.all := status_$pbu_bad_controller_memory_length;
    return;
  end;
  va := linteger(addr(buffer));
  if va < as_$private then begin
    status.all := status_$pbu_protection_violation;
    return;
  end;
  npages := (va + length - 1) div 1024 - va div 1024 + 1;
  if mmap_$pageable_pages - npages < mmap_$pageable_pages_lower_limit then
  begin
    status.all := status_$pbu_too_many_wired_pages;
    return;
  end;
  ml_$exclusion_start(pbu_$exclusion_lock);
  for i := 1 to npages do begin
    discard(pbu_$save_ppn(unit, va, status));
    if status.all <> status_$ok then begin
      if status.all <> status_$pbu_page_already_wired then begin
        for j := 1 to i - 1 do begin
          va := va - 1024;
          pbu_$delete_ppn(unit, mst_$find(va, 0), undo_status);
          if undo_status.all <> status_$ok then
            crash_system(undo_status);
        end;
        status.fail := true;
      end;
      exit;
    end;
    va := va + 1024;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
