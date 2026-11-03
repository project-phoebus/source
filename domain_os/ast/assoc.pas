{ AST_$ASSOC - associate a physical page with a page of an object.

  Image addresses:
    sau2  0x00E0444E  AST_$ASSOC
    sau4  0x0F80480A  AST_$ASSOC
    sau9  0x3C40574C  AST_$ASSOC

  - The object's segment is activated and wired, and under the PMAP
    lock the object is marked busy.
  - When its concurrency word is the caller's mode or 1, the page goes
    to AST_$PMAP_ASSOC, retried after faulting the page in with
    AST_$TOUCH for as long as the association is bad.

  Status stored:
    ast_$pmap_assoc's status: the page was associated, or not
    file_$object_not_found: a remote object, for a type-8 process
    status_$ast_write_concurrency_violation: another concurrency word
    the callees' statuses: the activation or a touch failed
}

procedure ast_$assoc(in uid: uid_$t; seg: pinteger; mode: integer32;
                     page: pinteger; flags: pinteger; ppn: integer32;
                     out status: status_$t);
  options(val_param);
label
  10;
var
  ppn_array: ast_$ppn_ulist_t;
  aste: ast_$aste_ptr_t;
  aote: ast_$aote_view_ptr_t;
  concurrency: integer32;
  touch_flags: pinteger;
begin
  aste := ast_$activate_and_wire(uid, seg, status);
  if aste = nil then
    return;

  ml_$lock(ml_$pmap_lock);

  aote := ast_$aote_view_ptr_t(aste^.aote);
  if aote^.aote.loc.remote and then
     (proc1_$type[proc1_$current] = 8) then begin
    status.all := file_$object_not_found;
    goto 10;
  end;

  aote^.aote.flags := aote^.aote.flags + [6];

  concurrency := aote^.attrs.fattr.acl_checksum;
  if (concurrency = mode) or else (concurrency = 1) then begin
    touch_flags := 16#42 ! flags;
    repeat
      ast_$pmap_assoc(aste, page, ppn, false, false, status);
      if status.all <> status_$pmap_bad_assoc then
        exit;
      discard(ast_$touch(aste^, mode, page, 1, ppn_array, status,
                         touch_flags));
    until (status.all <> status_$ok) and then
          (status.all <> status_$pmap_page_null);
  end
  else
    status.all := status_$ast_write_concurrency_violation;

10:
  ml_$unlock(ml_$pmap_lock);
  aste^.wire_count := aste^.wire_count - 1;
end;
