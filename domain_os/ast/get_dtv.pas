{ AST_$GET_DTV - an object's date-time verified clock.

  Image addresses:
    sau2  0x00E05476  AST_$GET_DTV
    sau9  0x3C406720  AST_$GET_DTV

  - With process switching inhibited and under the AST lock, the
    object's AOTE is looked up and marked busy, or the object activated
    (forced, with the caller's location word).
  - The AOTE's DTV clock is copied out under the PMAP lock.

  Status stored:
    status_$ok: the clock was returned
    file_$object_not_found: the object is remote (the clock returned)
    ast_$force_activate_segment's status: the object was not activated
}

procedure ast_$get_dtv(uid: uid_$t; location: integer32;
                       out dtv: time_$clock_t; out status: status_$t);
label
  10;
var
  local_status: status_$t;
  aote: ast_$aote_ptr_t;
begin
  local_status.all := status_$ok;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then begin
    aote := ast_$force_activate_segment(uid, ast_$loc_word_t(location),
                                        local_status, true);
    if aote = nil then
      goto 10;
  end
  else
    aote^.flags := aote^.flags + [6];

  ml_$lock(ml_$pmap_lock);
  dtv := aote^.dtv;
  ml_$unlock(ml_$pmap_lock);

  if aote^.loc.remote then
    local_status.all := file_$object_not_found;

10:
  ml_$unlock(ml_$ast_lock);
  proc1_$inhibit_end;
  status := local_status;
end;
