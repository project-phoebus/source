{ ast_$lookup_aote_by_uid - find an object's AOTE by its UID.

  Image addresses:
    sau2  0x00E0209E  ast_$lookup_aote_by_uid (module-local)
    sau9  0x3C403448  ast_$lookup_aote_by_uid (module-local)

  - The UID's hash chain (251 buckets) is walked for the UID; an entry
    in transition is waited for and the walk started again.
  - The result is the entry, or nil.

  Status stored: none.
}

function ast_$lookup_aote_by_uid(in uid: uid_$t): ast_$aote_ptr_t;
  internal;
var
  i: integer;
  aote: ast_$aote_ptr_t;
begin
  i := uid_$hash(uid, 251);

  aote := aoth[i];
  while aote <> nil do
    if aote^.uid = uid then begin
      if not (7 in aote^.flags) then begin
        ast_$lookup_aote_by_uid := aote;
        return;
      end;
      ast_$wait_for_ast_intrans;
      aote := aoth[i];
    end
    else
      aote := aote^.hash_next;

  ast_$lookup_aote_by_uid := nil;
end;
