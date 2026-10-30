{ AST_$ASSOC_AREA - associate a physical page with a page of an area's
  segment.

  Image addresses:
    sau2  0x00E04542  AST_$ASSOC_AREA
    sau9  0x3C40583E  AST_$ASSOC_AREA

  - As AST_$PMAP_ASSOC, for an ASTE given by its index: the entry is
    waited out of any transition and an installed page torn down.
  - A page number of 0 crashes the system; a real page joins the working
    set (unwired) and the entry records it as installed.

  Status stored:
    status_$ok: always
}

procedure ast_$assoc_area(seg_index: pinteger; page: integer;
                          ppn: linteger; out status: status_$t);
  options(val_param);
var
  wired: integer;
  old_ppn: linteger;
begin
  with ast_pmaps[seg_index, page] do begin
    while ast_$pmap_in_trans in flags do
      ast_$wait_for_page_transition;

    wired := 0;

    if ast_$pmap_installed in flags then begin
      old_ppn := vpn;
      with mmap[old_ppn] do begin
%if pmmu_page_maps %then
        flags := flags - [ast_$pmap_resident];
        mmu_$purge;
%else
        if ast_$pmap_resident in flags then begin
          flags := flags - [ast_$pmap_resident];
          mmu_$remove(old_ppn);
        end;
%endif
        flags := flags - [ast_$pmap_installed];
        wired := wire_count;
%if pmmu_page_maps %then
        vpn := disk_addr.all;
%else
        all := all & 16#FF800000;
        all := all ! disk_addr.all;
%endif
        mmap_$free_remove(mmap[old_ppn], old_ppn);
      end;
      ast[seg_index].page_count := pred(ast[seg_index].page_count);
    end;

    if ppn = 0 then
      crash_system(status_$pmap_mismatch);

    if (ppn >= mmap_$first_ppn) and then (ppn <= mmap_$last_ppn) then
      with mmap[ppn] do begin
        if in_wsl then
          crash_system(status_$mmap_bad_install);
        wire_count := wired;
        segment := seg_index;
        impure := true;
        seg_offset := page;
        flags2_7 := true;
        modified := true;
%if pmmu_page_maps %then
        disk_addr.all := vpn;
%else
        disk_addr.all := all & 16#7FFFFF;
%endif
        if wired = 0 then
          mmap_$install_list(ppn, 1, false);
      end;

    vpn := ppn;
    flags := flags + [ast_$pmap_installed];
%if pmmu_page_maps %then
    { installed but not resident: the next touch maps it }
    flags := flags - [ast_$pmap_resident];
    flags := flags + [ast_$pmap_used];
    flags := flags - [ast_$pmap_modified];
%else
    pft[ppn].w_02 := (pft[ppn].w_02 & 16#BFFF) ! 16#2000;
%endif
    ast[seg_index].page_count := succ(ast[seg_index].page_count);
  end;

  status.all := status_$ok;
end;
