{ AREA_$ASSOC - associate one page of an area with a physical page.

  Image addresses:
    sau2  0x00E096A2  AREA_$ASSOC
    sau4  0x0F809D2A  AREA_$ASSOC
    sau6  0x78009ED8  AREA_$ASSOC
    sau7  0x3C40A810  AREA_$ASSOC
    sau9  0x3C40B010  AREA_$ASSOC

  - The page's segment's ASTE is found and wired; AST_$ASSOC_AREA
    associates the page with ppn under the PMAP lock, and the wire count
    is dropped.

  Status stored:
    ast_$assoc_area's status: the page was associated
    status_$area_not_active: an id outside 1..AREA_$N_AREAS
    area_$find_entry_by_uid's status: the ASTE could not be had
}

procedure area_$assoc(area_id: pinteger; bste_idx: pinteger; page: pinteger;
                      ppn: integer32; out status_ret: status_$t);
var
  aste: ast_$aste_ptr_t;
begin
  if (area_id = 0) or else (area_id > area_$n_areas) then begin
    status_ret.all := status_$area_not_active;
    return;
  end;

  aste := area_$find_entry_by_uid(area_id, bste_idx, page, status_ret);
  if status_ret.all <> status_$ok then
    return;

  ml_$lock(ml_$pmap_lock);
  ast_$assoc_area(aste^.seg_index, page, ppn, status_ret);
  aste^.wire_count := aste^.wire_count - 1;
  ml_$unlock(ml_$pmap_lock);
end;
