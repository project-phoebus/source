{ ast_$allocate_aote - take an AOTE: from the free list, else by
  deactivating one.

  Image addresses:
    sau2  0x00E01D66  ast_$allocate_aote (module-local)
    sau4  0x0F80217E  ast_$allocate_aote (module-local)
    sau9  0x3C403110  ast_$allocate_aote (module-local)

  - A free AOTE is taken from the free list's head.  Otherwise seven
    entries from the scan position are looked at: a busy entry loses its
    mark, one in transition or referenced is passed over.
  - An entry with no segments is deactivated and taken; of the others
    the two with the fewest segments are tried in turn.
  - Failing those, twice the table's size of entries are swept, the
    first that deactivates taken; if none does, the system crashes.

  Status stored: none.
}

function ast_$allocate_aote: ast_$aote_ptr_t;
  internal;
label
  10;
var
  cands: array[1..2] of ast_$aote_view_ptr_t;
  local_status: status_$t;
  aote: ast_$aote_view_ptr_t;
  k: integer;
  sf: pinteger;
begin
  { the free list }
  if ast_$free_aote_head <> nil then begin
    aote := ast_$aote_view_ptr_t(ast_$free_aote_head);
    ast_$free_aote_head := aote^.aote.hash_next;
    ast_$free_aotes := ast_$free_aotes - 1;
    goto 10;
  end;

  { seven entries from the scan position }
  cands[1] := nil;
  cands[2] := nil;
  aote := ast_$aote_view_ptr_t(ast_$aote_scan_pos);
  for k := 1 to 7 do begin
    aote := ast_$aote_view_ptr_t(integer32(aote) + 192);
    if linteger(aote) >= linteger(ast_$aote_limit) then
      aote := ast_$aote_view_ptr_t(addr(aot[1]));
    if 6 in aote^.aote.flags then begin
      aote^.aote.flags := aote^.aote.flags - [6];
      next;
    end;
    if 7 in aote^.aote.flags then
      next;
    if aote^.ref_count <> 0 then
      next;
    if aote^.aote.status_flags = 0 then begin
      ast_$process_aote(aote^, false, false, false, local_status);
      if local_status.all <> status_$ok then
        next;
      ast_$aote_scan_pos := ast_$aote_ptr_t(aote);
      goto 10;
    end;
    if (cands[1] = nil) or else
       (cands[1]^.aote.status_flags > aote^.aote.status_flags) then begin
      cands[2] := cands[1];
      cands[1] := aote;
    end
    else begin
      sf := aote^.aote.status_flags;
      if (cands[1]^.aote.status_flags = sf) and then (sf = 1) and then
         (ast_$aste_ptr_t(cands[1]^.aote.aste_list)^.page_count >
          ast_$aste_ptr_t(aote^.aote.aste_list)^.page_count) then begin
        cands[2] := cands[1];
        cands[1] := aote;
      end
      else if (cands[2] = nil) or else
              (sf < cands[2]^.aote.status_flags) or else
              ((sf = cands[2]^.aote.status_flags) and then (sf = 1) and then
               (ast_$aste_ptr_t(cands[2]^.aote.aste_list)^.page_count >
                ast_$aste_ptr_t(aote^.aote.aste_list)^.page_count)) then
        cands[2] := aote;
    end;
  end;

  ast_$aote_scan_pos := ast_$aote_ptr_t(aote);

  { the two candidates }
  for k := 1 to 2 do begin
    aote := cands[k];
    if aote <> nil then begin
      ast_$process_aote(aote^, false, false, false, local_status);
      if local_status.all = status_$ok then
        goto 10;
    end;
  end;

  { the sweep }
  aote := ast_$aote_view_ptr_t(ast_$aote_scan_pos);
  for k := 1 to 2 * ast_$size_aot do begin
    aote := ast_$aote_view_ptr_t(integer32(aote) + 192);
    if linteger(aote) >= linteger(ast_$aote_limit) then
      aote := ast_$aote_view_ptr_t(addr(aot[1]));
    if 6 in aote^.aote.flags then
      aote^.aote.flags := aote^.aote.flags - [6]
    else begin
      ast_$process_aote(aote^, false, false, false, local_status);
      if local_status.all = status_$ok then begin
        ast_$alloc_worst_aot := ast_$alloc_worst_aot + 1;
        ast_$aote_scan_pos := ast_$aote_ptr_t(aote);
        goto 10;
      end;
    end;
  end;

  crash_system(16#80030003);
  aote := nil;

10:
  ast_$alloc_total_aot := ast_$alloc_total_aot + 1;
  ast_$allocate_aote := ast_$aote_ptr_t(aote);
end;
