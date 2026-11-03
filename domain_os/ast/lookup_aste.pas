{ ast_$lookup_aste - find the ASTE of an object's segment.

  Image addresses:
    sau2  0x00E0250C  ast_$lookup_aste (module-local)
    sau4  0x0F802924  ast_$lookup_aste (module-local)
    sau9  0x3C4038A4  ast_$lookup_aste (module-local)

  - The AOTE's ASTE list (descending by segment) is walked for the
    segment; an entry in transition is waited for, the AOTE's reference
    count held, and the walk started again.
  - The result is the entry, or nil.

  Status stored: none.
}

function ast_$lookup_aste(var aote: univ ast_$aote_view_t;
                          segment: pinteger): ast_$aste_ptr_t;
  internal;
var
  aste: ast_$aste_ptr_t;
begin
  aste := aote.aote.aste_list;
  while aste <> nil do
    if aste^.segment = segment then begin
      if not (15 in aste^.flags) then begin
        ast_$lookup_aste := aste;
        return;
      end;
      aote.ref_count := aote.ref_count + 1;
      ast_$wait_for_ast_intrans;
      aote.ref_count := aote.ref_count - 1;
      aste := aote.aote.aste_list;
    end
    else begin
      if segment >= aste^.segment then
        exit;
      aste := aste^.next;
    end;

  ast_$lookup_aste := nil;
end;
