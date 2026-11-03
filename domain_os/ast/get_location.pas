{ AST_$GET_LOCATION - an object's location record and its location word.

  Image addresses:
    sau2  0x00E046C8  AST_$GET_LOCATION
    sau4  0x0F804A74  AST_$GET_LOCATION
    sau9  0x3C4059B2  AST_$GET_LOCATION

  - A nil UID is validated instead of looked up.
  - Under the AST lock the object's AOTE is looked up and marked busy,
    or the object activated (forced when bit 0 of flags is set).
  - The AOTE's location word and 32-byte location record are returned;
    a record with no network locator gets this node's (NETWORK_$ME).

  Status stored:
    status_$ok: the location was returned
    ast_$validate_uid's result: loc_rec's UID is nil
    ast_$force_activate_segment's status: the object was not activated
}

procedure ast_$get_location(var loc_rec: file_$obj_loc_t; flags: integer;
                            var unused: integer32;
                            out location: ast_$location_t;
                            out status: status_$t);
var
  loc_word: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
begin
  if loc_rec.uid = uid_$nil then begin
    status.all := ast_$validate_uid(loc_rec.uid, 16#30F01);
    return;
  end;

  ml_$lock(ml_$ast_lock);
  aote := ast_$lookup_aote_by_uid(loc_rec.uid);
  if aote = nil then begin
    loc_word.all := 0;
    aote := ast_$force_activate_segment(loc_rec.uid, loc_word, status,
                                        odd(flags));
    if aote = nil then begin
      ml_$unlock(ml_$ast_lock);
      return;
    end;
  end
  else
    aote^.flags := aote^.flags + [6];

  location := ast_$aote_view_ptr_t(aote)^.loc;
  loc_rec := ast_$aote_view_ptr_t(aote)^.obj_loc.floc;
  ml_$unlock(ml_$ast_lock);

  if loc_rec.loc_info = 0 then
    loc_rec.loc_info := network_$me;
  status.all := status_$ok;
end;
