{ PBU_$WIRE_SPECIAL - wire a buffer for a PBU unit and list its pages'
  physical addresses.

  Image addresses:
    sau3  0x00E59F52  PBU_$WIRE_SPECIAL
    sau5  0x00E5A1C4  PBU_$WIRE_SPECIAL
    sau6  0x78061E2E  PBU_$WIRE_SPECIAL
    sau7  0x3C46A762  release_pages (nested)
    sau7  0x3C46A7F8  PBU_$WIRE_SPECIAL
    sau8  0x03C6248A  release_pages (nested)
    sau8  0x03C62520  PBU_$WIRE_SPECIAL

  - With the routine's body (`pbu_wire_special'); without it nothing is
    wired: count is 0, the status status_$pbu_not_supported.
  - With options member 0 each page must be wired for the unit already;
    otherwise it is wired (PBU_$SAVE_PPN), a page already wired ending
    the loop, another failure unwiring the pages so far.
  - A failure of that unwiring crashes the system.  count is the number
    of pages, 0 on a failure.
  - Member 1 is refused before anything else, and only VME units are
    taken; with the AT bus's units (`pbu_atbus_units') any unit, and
    member 1 asks for a physically contiguous buffer: page aligned, a
    whole number of pages up to 32, none wired.  Its pages come from
    AST_$ALLOC_CONTIG, retried after a clock tick and then with a page
    fewer each time (no page left crashes the system); each is wired
    for the unit and put at the buffer's address (MST_$ASSOC); with the
    cache-inhibited pages (`pmap_cache_inhibit') each is then
    cache-inhibited (AST_$CACHE_INHIBIT_PPN).
  - release_pages (nested) gives back the contiguous pages from a failed
    one on: those before it are unwired, the rest freed.

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
    status_$pbu_contiguous_not_aligned: member 1, and the buffer is not
      page aligned (`pbu_atbus_units')
    ast_$alloc_contig's status: member 1, the pages could not be had
    mst_$assoc's status: member 1, a page could not be put in place
    status_$pbu_not_supported: without the body
}

%if pbu_atbus_units %then
procedure pbu_$wire_special(in unit: integer;
                            in options: pbu_$wire_options_t;
                            in buffer: univ pbu_$buffer_t;
                            in length: linteger;
                            out pa_list: univ pbu_$pa_list_t;
                            in max: integer; out count: integer;
                            out status: status_$t);
label
  got;
var
  va: linteger;
  npages: integer32;
  i: integer32;
  j: integer32;
  ppn: linteger;
  owners: pbu_$unit_set_t;
  undo_status: status_$t;
  ppns: ast_$ppn_list_t;
  k: integer;
%if pmap_cache_inhibit %then
  last_page: integer;
%endif

  procedure release_pages(n: integer);
  var
    m: integer32;
  begin
    for m := 1 to n - 1 do begin
      wp_$unwire(ppns[m]);
      owners := pbu_$ppn_owners[ppns[m]];
      owners := owners - [unit];
      pbu_$ppn_owners[ppns[m]] := owners;
    end;
    for m := n to npages do
      mmap_$free(ppns[m]);
  end;

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
  if 1 in options then begin
    if (va & 16#3FF) <> 0 then begin
      status.all := status_$pbu_contiguous_not_aligned;
      return;
    end;
    if ((length & 16#3FF) <> 0) or else (length > 16#8000) then begin
      status.all := status_$pbu_bad_controller_memory_length;
      return;
    end;
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
        exit;
      end;
    end
    else if 1 in options then begin
      if owners <> [] then begin
        if (ppn < mmap_$lppn) or else (ppn > mmap_$hppn) then
          status.all := status_$pbu_bad_buffer_address
        else
          status.all := status_$pbu_page_already_wired;
        exit;
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
        exit;
      end;
    end;
    pa_list[i] := ppn * 1024;
    va := va + 1024;
  end;

  { The contiguous buffer.  The SAU8 image tests member 1 twice here. }
  if (status.all = status_$ok) and then (1 in options) then
    if 1 in options then begin
      repeat
        for k := 1 to 2 do begin
          ast_$alloc_contig(npages, ppns, undo_status);
          if undo_status.all = status_$ok then
            goto got;
          discard(ec_$wait(addr(time_$clockh_ec), addr(ec_$nil_ec),
                           addr(ec_$nil_ec), time_$clockh + 4, 0, 0));
        end;
        if undo_status.all = status_$ok then
          goto got;
        npages := npages - 1;
        if npages = 0 then
          crash_system(undo_status);
      until false;
    got:
      va := linteger(addr(buffer));
      status := undo_status;
      if status.all = status_$ok then
        for i := 1 to npages do begin
          ppn := ppns[i];
          owners := pbu_$ppn_owners[ppn];
          if owners <> [] then
            crash_system(status_$pbu_page_already_wired);
          wp_$wire(ppn);
          owners := [unit];
          pbu_$ppn_owners[ppn] := owners;
          pa_list[i] := ppn * 1024;
          mst_$assoc(va, ppn, undo_status);
          if undo_status.all <> status_$ok then begin
            status := undo_status;
            release_pages(i + 1);
            exit;
          end;
%if pmap_cache_inhibit %then
          last_page := i;
%endif
          va := va + 1024;
        end;
%if pmap_cache_inhibit %then
      { The pages placed are cache-inhibited. }
      if status.all = status_$ok then
        for j := 1 to last_page do
          ast_$cache_inhibit_ppn(ppns[j]);
%endif
    end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
  if status.all = status_$ok then
    count := npages
  else
    count := 0;
end;
%elseif pbu_wire_special %then

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
%else

{ TODO(pascal) the SAU3 body's load of pa_list's address

  The SAU3's (and the SAU4's) body loads pa_list's address from its
  argument slot first and does nothing with it; then count and the
  status are stored.  No statement on pa_list that leaves only that load
  is known; the two assignments below give the rest. }

procedure pbu_$wire_special(in unit: integer;
                            in options: pbu_$wire_options_t;
                            in buffer: univ pbu_$buffer_t;
                            in length: linteger;
                            out pa_list: univ pbu_$pa_list_t;
                            in max: integer; out count: integer;
                            out status: status_$t);
begin
  count := 0;
  status.all := status_$pbu_not_supported;
end;
%endif
