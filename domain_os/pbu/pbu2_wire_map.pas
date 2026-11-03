{ PBU2_$WIRE_MAP - wire a buffer and map it in a PBU unit's I/O map
  space.

  Image addresses:
    sau3  0x00E59D7E  PBU2_$WIRE_MAP
    sau5  0x00E59FDE  PBU2_$WIRE_MAP
    sau8  0x03C62476  PBU2_$WIRE_MAP

  - Under the exclusion lock each page is wired for the unit
    (PBU_$SAVE_PPN) and its I/O map entry written: the page number plus
    the unit's control, a longword (`long_iomap') or the entry's word
    and the control's high word.
  - A page already wired ends the loop; another failure unwires the
    pages wired so far (a failure there crashes the system).
  - The result is iova plus the buffer's offset in its page, its address
    on the bus (unset when a check fails).
  - The fit test compares with the space's end address; the failed
    page's entry is written and no fail bit set; the undo loop's bounds
    are unsigned.
  - Without the I/O map space (`io_regions') nothing is wired: the
    result is 0.

  Status stored:
    pbu_$save_ppn's status: the buffer was wired and mapped, a page was
      wired already, or a page could not be wired
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_not_supported: the unit is on the VME bus (`vme_bus')
    status_$pbu_bad_controller_memory_length: length is not positive
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$pbu_invalid_iova: iova is not a page inside the space with
      the length after it
    status_$pbu_protection_violation: the buffer is below the private
      address space
    status_$pbu_buffer_too_large: the buffer does not fit
    status_$pbu_too_many_wired_pages: no pages to spare
    status_$pbu_not_supported: always, without `io_regions'
}

%if io_regions %then
function pbu2_$wire_map(in unit: integer; in buffer: univ pbu_$buffer_t;
                        in length: linteger; in iova: linteger;
                        out status: status_$t): integer32;
var
  dcte: pbu_$dcte_ptr_t;
  offset: integer32;
  va: linteger;
  page_offset: integer;
  npages: integer32;
  first: linteger;
  last: linteger;
  slot: linteger;
  ctl: pbu_$ctl_t;
  j: linteger;
  undo_status: status_$t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
%if vme_bus %then
  if dcte^.unit_info.bus = io_$bus_vme then begin
    status.all := status_$pbu_not_supported;
    return;
  end;
%endif
  if length <= 0 then begin
    status.all := status_$pbu_bad_controller_memory_length;
    return;
  end;
  if not dcte^.flags.map_allocated then begin
    status.all := status_$pbu_iomap_not_allocated;
    return;
  end;
  offset := iova - dcte^.map_start;
  if (offset < 0) or else (iova + length > dcte^.map_end) or else
     ((offset & 16#3FF) <> 0) then begin
    status.all := status_$pbu_invalid_iova;
    return;
  end;
  va := linteger(addr(buffer));
  if va < as_$private then begin
    status.all := status_$pbu_protection_violation;
    return;
  end;
  page_offset := va & 16#3FF;
  if page_offset + offset + length > dcte^.map_end then begin
    status.all := status_$pbu_buffer_too_large;
    return;
  end;
  npages := (va + length - 1) div 1024 - va div 1024;
  if mmap_$pageable_pages - npages < mmap_$pageable_pages_lower_limit then
  begin
    status.all := status_$pbu_too_many_wired_pages;
    return;
  end;
  first := linteger(offset) div 1024 + dcte^.map_page;
  ctl := dcte^.ctl;
  ml_$exclusion_start(pbu_$exclusion_lock);
  last := first + npages;
  for slot := first to last do begin
%if long_iomap %then
    iomap[slot] := pbu_$save_ppn(unit, va, status) + ctl.all;
%else
    iomap[slot].entry := pbu_$save_ppn(unit, va, status) + ctl.entry;
%endif
    if status.all <> status_$ok then begin
      if status.all <> status_$pbu_page_already_wired then
        for j := first to slot - 1 do begin
          va := va - 1024;
          pbu_$delete_ppn(unit, mst_$find(va, 0), undo_status);
          if undo_status.all <> status_$ok then
            crash_system(undo_status);
        end;
      exit;
    end;
    va := va + 1024;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
  pbu2_$wire_map := page_offset + iova;
end;
%else
function pbu2_$wire_map(in unit: integer; in buffer: univ pbu_$buffer_t;
                        in length: linteger; in iova: linteger;
                        out status: status_$t): integer32;
begin
  status.all := status_$pbu_not_supported;
  pbu2_$wire_map := 0;
end;
%endif
