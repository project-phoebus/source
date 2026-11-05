{ OS_$INSTALL_DISPLAY_ASTE - make the display memory a canned object.

  Image addresses:
    sau2  0x00E6D29A  OS_$INSTALL_DISPLAY_ASTE
    sau4  0x0F876D7A  OS_$INSTALL_DISPLAY_ASTE
    sau6  0x78075DE6  OS_$INSTALL_DISPLAY_ASTE
    sau7  0x3C48075E  OS_$INSTALL_DISPLAY_ASTE
    sau8  0x03C7661A  OS_$INSTALL_DISPLAY_ASTE
    sau9  0x3C473E8E  OS_$INSTALL_DISPLAY_ASTE

  - Compiled only with `display_driver' (base/config.ins.pas).
  - The object's pages are the frames behind va, consecutive from the
    first; touch also maps the object at va and touches every page.
  - Without `pft_mmu' the frames go in as I/O pages, and the
    translations are purged at the end.
  - `pmmu_page_maps': each touched page's descriptor is not resident.
  - Any failure crashes the system.
  - The inner `exit' on the page count leaves only the inner loop; the
    outer count runs on.

  Status stored: none.
}

{ TODO(pascal) OS_$INSTALL_DISPLAY_ASTE's open frame bytes

  The frame leaves four runs of bytes unaddressed (between desc and
  status, status and va's copy, va's copy and segno, segno and pages).
  The register-held locals (ppn, aste, seg, page, left) and the two
  clearing loops' index i may each own a slot there, but which
  declaration order puts them at those offsets is not probed; the
  declarations here follow the addressed objects' order. }

procedure os_$install_display_aste(in uid: uid_$t; va: integer32;
                                   in size: integer32;
                                   in touch: boolean);
type
  loc_view_t = record
    case integer of
      1: (r: file_$obj_loc_t);
      2: (longs: array[1..8] of integer32);
  end;
var
  loc: loc_view_t;
  vtoce: os_$init_vtoce_t;
  desc: integer32;
  status: status_$t;
  segno: pinteger;
  pages: integer;
  segs_m1: integer;
  ppn: integer32;
  aste: ast_$aste_ptr_t;
  seg: integer;
  page: integer;
  left: integer;
  i: integer;                             { the clearing loops' indices,
                                            unused }
begin
  ppn := vtop_or_crash(va);

  { the records cleared }
  for i := 1 to 36 do
    vtoce.longs[i] := 0;
  for i := 1 to 8 do
    loc.longs[i] := 0;

  vtoce.file_uid := uid;
  vtoce.acl_uid := acl_$fndwrx;
  vtoce.length := size;
  loc.r.uid := uid;
  loc.r.node := node_$me;
  desc := 0;
  ast_$activate_aote_canned(vtoce, loc.r);

  { the page and segment counts }
  pages := (size + 1023) div 1024;
  segs_m1 := (size + 32767) div 32768 - 1;
  left := pages;

  { each page associated with its frame }
  for seg := 0 to segs_m1 do begin
    aste := ast_$activate_aste_canned(uid, seg);
    for page := 0 to 31 do begin
%if pft_mmu %then
      ast_$pmap_assoc(aste, page, ppn, true, false, status);
      if status.all <> status_$ok then
        crash_system(status);
%else
      ast_$assoc_ioppn(aste^, page, ppn);
%endif
      ppn := ppn + 1;
      left := left - 1;
      if left = 0 then
        exit;
    end;
  end;

  { mapped at its address and touched }
  if touch then begin
    if mst_$va_to_segno(va, segno, 16#3A) > 16#39 then
      crash_system(status_$reference_to_illegal_address);
    mst_$map_canned_at(va, uid, 0, size, 16#160001, false, false, desc,
                       status);
    if status.all <> status_$ok then
      crash_system(status);

    left := pages;
    for seg := 0 to segs_m1 do
      for page := 0 to 31 do begin
        discard(mst_$touch(va, status, 0));
        if status.all <> status_$ok then
          crash_system(status);
        va := va + 1024;
%if pmmu_page_maps or region_mmu %then
        { the page's descriptor in OS_PMAPS, not resident }
        os_pmaps[segno - mst_$global_a_size + seg][page].flags :=
          os_pmaps[segno - mst_$global_a_size + seg][page].flags -
          [ast_$pmap_resident];
%endif
        left := left - 1;
        if left = 0 then
          exit;
      end;
  end;
%if not pft_mmu %then
  mmu_$purge;
%endif
end;
