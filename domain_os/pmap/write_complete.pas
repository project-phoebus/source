{ pmap_$write_complete - finish a page write: clean the page or put it back.

  Image addresses:
    sau2  0x00E12D84  pmap_$write_complete
    sau4  0x0F8136BC  pmap_$write_complete (module-local)
    sau7  0x3C414B3C  pmap_$write_complete
    sau9  0x3C415100  pmap_$write_complete

  Assume we're called with the PMAP lock held.

  - status comes in as the write's own; "disk write protected" counts as
    success.
  - A good write moves the page's pending dirty mark to its segment and
    makes a page of a low list pure (list 1).
  - A failed write marks the page modified and referenced again and makes
    it available.

  Status stored:
    status_$ok: the write succeeded, or the disk was write protected
    the write's status, its fail bit set: the write failed
}

procedure pmap_$write_complete(vpn: integer32; var status: status_$t);
  internal;
var
  page: mmap_$mmape_ptr_t;
  segment: pinteger;
  seg_offset: integer;
begin
  page := addr(mmap[vpn]);
  segment := page^.segment;
  seg_offset := page^.seg_offset;

  if (status.all = status_$ok) or else
     (status.all = status_$disk_write_protected) then begin
    status.all := status_$ok;
    if not page^.flags2_7 and then page^.disk_addr.aste_dirty then begin
      page^.disk_addr.aste_dirty := false;
      ast[segment].flags := ast[segment].flags + [13];
    end;
    ast_pmaps[segment][seg_offset].flags :=
      ast_pmaps[segment][seg_offset].flags - [ast_$pmap_in_trans];
    if page^.wsl_index < 5 then
      page^.wsl_index := 1;
  end
  else begin
    status.fail := true;
    page^.modified := true;
%if pmmu_page_maps or region_mmu %then
    ast_pmaps[segment][seg_offset].flags :=
      ast_pmaps[segment][seg_offset].flags + [ast_$pmap_used];
%else
    pft[vpn].w_02 := pft[vpn].w_02 ! 16#2000;
%endif
    mmap_$avail(ast_pmaps[segment][seg_offset].vpn);
    ast_pmaps[segment][seg_offset].flags :=
      ast_pmaps[segment][seg_offset].flags - [ast_$pmap_in_trans];
    ec_$advance(ast_$pmap_in_trans_ec);
  end;
end;
