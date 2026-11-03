{ MST_$REMOVE_SEG - release an object segment's pages from the AST.

  Image addresses:
    sau2  0x00E0E0D6  MST_$REMOVE_SEG
    sau4  0x0F80E73C  MST_$REMOVE_SEG
    sau8  0x03C0F10A  MST_$REMOVE_SEG
    sau9  0x3C4101E4  MST_$REMOVE_SEG

  - Under the AST lock the segment's ASTE, if any, releases its pages
    (to the free pool or not, as the caller says).
  - With the large VM layout, an address space's segment map entry
    that points at a page map is made invalid and taken off the page
    map's thread; the pages are released only when the caller asks for
    the pool, and then always to the pool.

  Status stored: none.
}

procedure mst_$remove_seg(in request: univ ast_$locate_request_t;
                          va: integer32; seg: pinteger; segno: pinteger;
                          return_to_pool: boolean);
%if large_vm %then
label
  done;
%endif
var
  aste: ast_$aste_ptr_t;
%if large_vm %then
  link: ^mst_$pmap_link_t;
%endif
begin
%if large_vm %then
  { seg is the segment's index in its address space, segno the address
    space (the ASID): the segment map entry's index }
%if region_mmu %then
  if not smaps[seg + smap_asid_base[segno]].e.valid then
    return;
%else
  if smaps[seg + smap_asid_base[segno]].ctl.dt = mst_smap_invalid then
    return;
%endif
  ml_$lock(ml_$ast_lock);
  aste := ast_$locate_aste(request);
  ml_$lock(ml_$pmap_lock);
%if region_mmu %then
  if smaps[seg + smap_asid_base[segno]].e.valid then begin
    smaps[seg + smap_asid_base[segno]].e.valid := false;
%else
  if smaps[seg + smap_asid_base[segno]].ctl.dt <> mst_smap_invalid then
  begin
    smaps[seg + smap_asid_base[segno]].ctl.dt := mst_smap_invalid;
%endif
    if aste <> nil then begin
      { the entry off its page map's thread }
      link := addr(aste^.pmap_link);
      while (link^.asid <> segno) or else (link^.seg <> seg) do
        link := addr(bst[link^.seg + bst_asid_base[link^.asid]]);
      link^ := bst[bst_asid_base[segno] + seg];
      ml_$unlock(ml_$pmap_lock);
      if return_to_pool then
        ast_$release_pages(aste, true);
      goto done;
    end;
  end;
  ml_$unlock(ml_$pmap_lock);
done:
  ml_$unlock(ml_$ast_lock);
%else
  ml_$lock(ml_$ast_lock);
  aste := ast_$locate_aste(request);
  if aste <> nil then
    ast_$release_pages(aste, return_to_pool);
  ml_$unlock(ml_$ast_lock);
%endif
end;
