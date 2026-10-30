{ PBU_$WIRE_SPECIAL - wire a buffer for a VME unit and list its pages'
  physical addresses.

  Image addresses:
    sau5  0x00E5A1C4  PBU_$WIRE_SPECIAL

  - With options member 0 each page must be wired for the unit already;
    otherwise it is wired (PBU_$SAVE_PPN), a page already wired ending
    the loop, another failure unwiring the pages so far.
  - A failure of that unwiring crashes the system.  count is the number
    of pages, 0 on a failure.
  - Member 1 is refused before anything else.

  Status stored:
    status_$ok: the pages were listed
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_vme_only: the unit is not on the VME bus
    status_$pbu_page_not_wired: options has member 1
    status_$pbu_bad_controller_memory_length: length is not positive
    status_$pbu_protection_violation: the buffer is below the private
      address space
    status_$pbu_address_list_too_small: max entries are too few
    status_$pbu_too_many_wired_pages: no pages to spare
    status_$pbu_buffer_page_not_wired: member 0, and a page not wired
    status_$pbu_bad_buffer_address: a page outside MMAP_$LPPN..HPPN
    pbu_$save_ppn's status: a page was wired already
    pbu_$save_ppn's status, its fail bit set: a page could not be wired
}

procedure pbu_$wire_special(in unit: integer;
                            in options: pbu_$wire_options_t;
                            in buffer: univ pbu_$buffer_t;
                            in length: linteger;
                            out pa_list: univ pbu_$pa_list_t;
                            in max: integer; out count: integer;
                            out status: status_$t);
label
  unlock;
var
  dcte: pbu_$dcte_ptr_t;
  va: linteger;
  npages: integer32;
  i: integer32;
  j: integer32;
  ppn: linteger;
  owners: pbu_$unit_set_t;
  undo_status: status_$t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.unit_info.bus <> io_$bus_vme then begin
    status.all := status_$pbu_vme_only;
    return;
  end;
  if 1 in options then begin
    status.all := status_$pbu_page_not_wired;
    return;
  end;
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
  if max < npages then begin
    status.all := status_$pbu_address_list_too_small;
    return;
  end;
  if (0 in options) and then (1 in options) then begin
    status.all := status_$pbu_bad_parameter;
    return;
  end;
  if mmap_$pageable_pages - npages < mmap_$pageable_pages_lower_limit then
  begin
    status.all := status_$pbu_too_many_wired_pages;
    return;
  end;
  ml_$exclusion_start(pbu_$exclusion_lock);
  for i := 1 to npages do begin
    ppn := mst_$find(va, 0);
    if (ppn <> 0) and then (ppn >= mmap_$lppn) and then
       (ppn <= mmap_$hppn) then
      owners := pbu_$ppn_owners[ppn]
    else
      owners := [];
    if 0 in options then begin
      if not (unit in owners) then begin
        status.all := status_$pbu_buffer_page_not_wired;
        goto unlock;
      end;
    end
    else if 1 in options then begin
      if owners <> [] then begin
        if (ppn < mmap_$lppn) or else (ppn > mmap_$hppn) then
          status.all := status_$pbu_bad_buffer_address
        else
          status.all := status_$pbu_page_already_wired;
        goto unlock;
      end;
    end
    else begin
      if (ppn < mmap_$lppn) or else (ppn > mmap_$hppn) then
        status.all := status_$pbu_bad_buffer_address
      else
        ppn := pbu_$save_ppn(unit, va, status);
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
        goto unlock;
      end;
    end;
    pa_list[i] := ppn * 1024;
    va := va + 1024;
  end;
unlock:
  ml_$exclusion_stop(pbu_$exclusion_lock);
  if status.all = status_$ok then
    count := npages
  else
    count := 0;
end;
