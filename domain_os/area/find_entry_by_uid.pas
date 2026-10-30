{ area_$find_entry_by_uid - find, or activate, the ASTE of one area
  segment.

  Image addresses:
    sau2  0x00E0939C  area_$find_entry_by_uid (module-local)
    sau9  0x3C40AC8E  area_$find_entry_by_uid (module-local)

  - For a reversed area the segment index becomes its group, -1 -
    index, in place.  The page's slot cell is found (an overflow table
    missing crashes the system).
  - Under the AST lock area_$get_aste finds or makes the segment's ASTE,
    the result.
  - The two early exits do not assign the result.

  Status stored:
    status_$ok: the ASTE was found or made
    status_$area_not_active: the area is not active
    status_$ast_eof: the segment's page lies past the area's last page
    area_$get_aste's status: the ASTE could not be had
}

function area_$find_entry_by_uid(id: pinteger; var bste: pinteger;
                                 page: pinteger;
                                 out status: status_$t): ast_$aste_ptr_t;
  internal;
var
  slot: ^area_$seg_slot_t;
  n: pinteger;
  table_idx: pinteger;
  tbl: area_$seg_table_ptr_t;
begin
  status.all := status_$ok;

  with areas[id] do begin
    if not (area_$f_active in flags) then begin
      status.all := status_$area_not_active;
      return;
    end;

    { the segment's page against the size }
    if area_$f_reversed in flags then begin
      bste := 16#FFFF - bste;
      if lshft(bste, 5) + 31 - page > rshft(virt_size - 1, 10) then begin
        status.all := status_$ast_eof;
        return;
      end;
    end
    else if page + lshft(bste, 5) > rshft(virt_size - 1, 10) then begin
      status.all := status_$ast_eof;
      return;
    end;

    { the segment's slot cell }
    n := rshft(page + lshft(bste, 5), 8);
    if n < 2 then
      slot := addr(seg_bitmap[n])
    else begin
      table_idx := rshft(n - 2, 8);
      tbl := area_$seg_table_list[owner_asid];
      while tbl <> nil do begin
        if (id = tbl^.area_id) and then
           (tbl^.table_index = table_idx) then
          exit;
        tbl := tbl^.next;
      end;
      if tbl = nil then
        crash_system(status_$area_internal_error);
      slot := addr(area_$seg_cells_ptr_t(tbl^.bitmap)^[(n - 2) mod 256]);
    end;
  end;

  ml_$lock(ml_$ast_lock);
  area_$find_entry_by_uid := area_$get_aste(id, slot^, bste, false,
                                            true, status);
  ml_$unlock(ml_$ast_lock);
end;
