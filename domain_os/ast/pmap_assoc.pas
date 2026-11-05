{ AST_$PMAP_ASSOC - associate a physical page with a page of a segment.

  Image addresses:
    sau2  0x00E042B0  AST_$PMAP_ASSOC
    sau4  0x0F80468A  AST_$PMAP_ASSOC
    sau6  0x78004984  AST_$PMAP_ASSOC
    sau7  0x3C404DD4  AST_$PMAP_ASSOC
    sau8  0x03C045C8  AST_$PMAP_ASSOC
    sau9  0x3C4055D4  AST_$PMAP_ASSOC

  - The page-map entry is waited out of any transition; an installed
    page is torn down unless it is wired.
  - A page number of 0 crashes the system.  A real page joins the
    working set (unwired), and the entry records it as installed and
    wired.

  Status stored:
    status_$ok: the page was associated
    status_$pmap_pages_wired: the installed page's MMAP entry is wired
    status_$pmap_bad_assoc: a local object's entry has neither a page
      nor a disk address (stopping there unless allow_no_disk)
}

procedure ast_$pmap_assoc(aste: ast_$aste_ptr_t; page: integer;
                          ppn: linteger; flags1: boolean;
                          allow_no_disk: boolean; out status: status_$t);
  options(val_param);
var
  old_ppn: linteger;
begin
  status.all := status_$ok;

  with ast_pmaps[aste^.seg_index, page] do begin
    while ast_$pmap_in_trans in flags do
      ast_$wait_for_page_transition;

    if ast_$pmap_installed in flags then begin
      old_ppn := vpn;
      with mmap[old_ppn] do begin
%if pmmu_page_maps or region_mmu %then
        flags := flags - [ast_$pmap_resident];
        mmu_$purge;
%else
        if ast_$pmap_resident in flags then begin
          flags := flags - [ast_$pmap_resident];
          mmu_$remove(old_ppn);
        end;
%endif
        if wire_count <> 0 then begin
          status.all := status_$pmap_pages_wired;
          return;
        end;
        flags := flags - [ast_$pmap_installed];
%if pmmu_page_maps %then
        vpn := disk_addr.all;
%else
        fentry.fm_daddr := linteger(disk_addr.all);
%endif
        mmap_$free_remove(mmap[old_ppn], old_ppn);
      end;
      aste^.page_count := pred(aste^.page_count);
    end
%if pmmu_page_maps %then
    else if (vpn = 0) and then
%else
    else if (fentry.fm_daddr = 0) and then
%endif
            (aste^.aote^.loc_flags >= 0) then begin
      status.all := status_$pmap_bad_assoc;
      if not allow_no_disk then
        return;
    end;

    if ppn = 0 then
      crash_system(status_$pmap_mismatch);

    if (ppn >= mmap_$first_ppn) and then (ppn <= mmap_$last_ppn) then
      with mmap[ppn] do begin
        if in_wsl then
          crash_system(status_$mmap_bad_install);
        segment := aste^.seg_index;
        impure := true;
        seg_offset := page;
        modified := true;
        flags2_7 := false;
%if pmmu_page_maps %then
        disk_addr.all := vpn;
%else
        disk_addr.all := fentry.fm_daddr;
%endif
        if wire_count = 0 then
          mmap_$install_list(ppn, 1, false);
      end;

    vpn := ppn;
%if pmmu_page_maps or region_mmu %then
    flags := flags + [ast_$pmap_installed, ast_$pmap_used];
    flags := flags - [ast_$pmap_modified];
%else
    flags := flags + [ast_$pmap_installed];
    pft[ppn].w_02 := (pft[ppn].w_02 & 16#BFFF) ! 16#2000;
%endif
    flags := flags + [ast_$pmap_resident];
    aste^.page_count := succ(aste^.page_count);
  end;
end;
