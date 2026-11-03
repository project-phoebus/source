{ AST_$LOCATE_ASTE - find the ASTE of a (uid, segment, hint) request.

  Image addresses:
    sau2  0x00E07050  AST_$LOCATE_ASTE
    sau4  0x0F8073B8  AST_$LOCATE_ASTE
    sau9  0x3C408288  AST_$LOCATE_ASTE

  - The request's hint (the low bits of its +0x0A word) names an
    ASTE, the result when it is in range, not in transition, not an
    area's, and carries the wanted segment of the wanted UID's AOTE.
  - Otherwise the object's AOTE and its ASTE list are searched; nil when
    the object is not active.

  Status stored: none.
}

function ast_$locate_aste(in request: ast_$locate_request_t):
  ast_$aste_ptr_t;
var
  hint_index: pinteger;
  aste: ast_$aste_ptr_t;
  aote: ast_$aote_ptr_t;
begin
%if large_vm %then
  hint_index := request.hint.index;
%else
  hint_index := request.hint & 16#1FF;
%endif
  if (hint_index <> 0) and then
     (hint_index <= pinteger(ast_$size_ast)) then begin
    aste := addr(ast[hint_index]);
    if not (15 in aste^.flags) and then
       (aste^.segment = request.segment) and then
       not (12 in aste^.flags) and then
       (aste^.aote <> nil) and then
       not (7 in aste^.aote^.flags) and then
       (aste^.aote^.uid = request.uid) then begin
      ast_$locate_aste := aste;
      return;
    end;
  end;

  aote := ast_$lookup_aote_by_uid(request.uid);
  if aote = nil then
    ast_$locate_aste := nil
  else
    ast_$locate_aste := ast_$lookup_aste(aote^, request.segment);
end;
