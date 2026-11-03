{ AST_$ALLOCATE_ASTE - take an ASTE: from the free list, else by
  deactivating a segment.

  Image addresses:
    sau2  0x00E01F1C  AST_$ALLOCATE_ASTE
    sau4  0x0F802334  AST_$ALLOCATE_ASTE
    sau9  0x3C4032C6  AST_$ALLOCATE_ASTE

  - As ast_$allocate_aote, for segments: twelve entries are looked at,
    one in transition or wired passed over, one with no pages
    deactivated and taken, else the two holding the fewest pages tried.
  - A deactivated entry leaves the count of its kind (area, remote,
    local).

  Status stored: none.
}

function ast_$allocate_aste: ast_$aste_ptr_t;
label
  10, 30;
var
  cands: array[1..2] of ast_$aste_ptr_t;
  local_status: status_$t;
  aste: ast_$aste_ptr_t;
  k: integer;
begin
  { the free list }
  if ast_$free_aste_head <> nil then begin
    aste := ast_$free_aste_head;
    ast_$free_aste_head := aste^.next;
    ast_$free_astes := ast_$free_astes - 1;
    goto 10;
  end;

  { twelve entries from the scan position }
  cands[1] := nil;
  cands[2] := nil;
  aste := ast_$aste_scan_pos;
  for k := 1 to 12 do begin
    aste := ast_$aste_ptr_t(integer32(aste) + sizeof(ast_$aste_t));
    if linteger(aste) >= linteger(ast_$aste_limit) then
      aste := addr(ast[1]);
    if 14 in aste^.flags then begin
      aste^.flags := aste^.flags - [14];
      next;
    end;
    if 15 in aste^.flags then
      next;
    if aste^.wire_count <> 0 then
      next;
    if aste^.page_count = chr(0) then begin
      ast_$deactivate_segment(aste^, false, false, local_status);
      if local_status.all <> status_$ok then
        next;
      ast_$aste_scan_pos := aste;
      goto 30;
    end;
    if (cands[1] = nil) or else
       (cands[1]^.page_count > aste^.page_count) then begin
      cands[2] := cands[1];
      cands[1] := aste;
    end
    else if (cands[2] = nil) or else
            (cands[2]^.page_count > aste^.page_count) then
      cands[2] := aste;
  end;

  ast_$aste_scan_pos := aste;

  { the two candidates }
  for k := 1 to 2 do begin
    aste := cands[k];
    if aste <> nil then begin
      ast_$deactivate_segment(aste^, false, false, local_status);
      if local_status.all = status_$ok then
        goto 30;
    end;
  end;

  { the sweep }
  aste := ast_$aste_scan_pos;
  for k := 1 to 2 * ast_$size_ast do begin
    aste := ast_$aste_ptr_t(integer32(aste) + sizeof(ast_$aste_t));
    if linteger(aste) >= linteger(ast_$aste_limit) then
      aste := addr(ast[1]);
    if 14 in aste^.flags then
      aste^.flags := aste^.flags - [14]
    else begin
      ast_$deactivate_segment(aste^, false, false, local_status);
      if local_status.all = status_$ok then begin
        ast_$alloc_worst_ast := ast_$alloc_worst_ast + 1;
        ast_$aste_scan_pos := aste;
        goto 30;
      end;
    end;
  end;

  crash_system(16#80030003);
  aste := nil;

  { the kind's count }
30:
  if 12 in aste^.flags then
    ast_$aste_area_cnt := ast_$aste_area_cnt - 1
  else if 11 in aste^.flags then
    ast_$aste_r_cnt := ast_$aste_r_cnt - 1
  else
    ast_$aste_l_cnt := ast_$aste_l_cnt - 1;

10:
  ast_$alloc_total_ast := ast_$alloc_total_ast + 1;
  ast_$allocate_aste := aste;
end;
