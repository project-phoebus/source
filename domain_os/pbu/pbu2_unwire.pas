{ PBU2_$UNWIRE - unwire a buffer a PBU unit wired.

  Image addresses:
    sau3  0x00E59996  PBU2_$UNWIRE
    sau5  0x00E59C06  PBU2_$UNWIRE
    sau8  0x03C620F0  PBU2_$UNWIRE

  - With touch each page is first referenced (its first word read and
    written back); then, under the exclusion lock, each page loses the
    unit from its owners (PBU_$DELETE_PPN), until one fails.
  - A page's physical page is MMU_$VTOP's, else MST_$FIND's; with the
    large virtual memory (`large_vm') MST_$FIND's.

  Status stored:
    status_$ok: the buffer was unwired
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_bad_controller_memory_length: length is not positive
    status_$pbu_page_not_wired: a page has no physical page
    pbu_$delete_ppn's status: a page could not be given up
}

procedure pbu2_$unwire(in unit: integer; var buffer: univ pbu_$buffer_t;
                       in length: linteger; in touch: boolean;
                       out status: status_$t);
type
  word_ptr_t = ^integer;
var
  p: linteger;
  npages: integer32;
  i: integer32;
  ppn: linteger;
begin
  discard(pbu_check_unit(unit, status));
  if status.all <> status_$ok then
    return;
  if length <= 0 then begin
    status.all := status_$pbu_bad_controller_memory_length;
    return;
  end;
  p := linteger(addr(buffer));
  npages := (p + length - 1) div 1024 - p div 1024 + 1;
  if touch then begin
    for i := 1 to npages do begin
      word_ptr_t(p)^ := word_ptr_t(p)^;
      p := p + 1024;
    end;
    p := linteger(addr(buffer));
  end;
  ml_$exclusion_start(pbu_$exclusion_lock);
  for i := 1 to npages do begin
%if large_vm %then
    ppn := mst_$find(p, 0);
%else
    ppn := mmu_$vtop(p, status);
    if status.all <> status_$ok then
      ppn := mst_$find(p, 0);
%endif
    if ppn = 0 then
      status.all := status_$pbu_page_not_wired
    else
      status.all := status_$ok;
    if status.all <> status_$ok then
      exit;
    pbu_$delete_ppn(unit, ppn, status);
    if status.all <> status_$ok then
      exit;
    p := p + 1024;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
