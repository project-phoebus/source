{ AST_$GET_ATTRIBUTES - an object's attribute record and location.

  Image addresses:
    sau2  0x00E047A0  AST_$GET_ATTRIBUTES
    sau9  0x3C405A8A  AST_$GET_ATTRIBUTES

  - A nil UID is validated instead of looked up.
  - An object not in the AOT is activated; flags bit 7 forces it.
  - flags bit 5 refreshes a remote object's attributes from its node.
  - flags bit 9, or an AOTE touched since, stamps a local object's DTU.
  - A location record with no network locator gets this node's.

  Status stored:
    status_$ok: the attributes and location were returned
    status_$ast_incompatible_request: flags has a bit of 10..15 set
    ast_$validate_uid's result: loc_rec's UID is nil
    ast_$force_activate_segment's status: the object could not be
      activated
    network_$ast_get_info's status: a remote object's refresh failed
    file_$object_not_found: flags bit 7 is set and the object is remote
}

procedure ast_$get_attributes(var loc_rec: file_$obj_loc_t; flags: integer;
                              out attrs: file_$attributes_t;
                              out status: status_$t);
label
  20, 30, 40;
var
  saved_dtv: time_$clock_t;
  local_status: status_$t;
  location: ast_$loc_word_t;
  req_flags: integer;
  aote: ast_$aote_ptr_t;
  len: linteger;
begin
  if ast_$word_set_t(flags) * [10..15] <> [] then begin
    status.all := status_$ast_incompatible_request;
    return;
  end;

  if loc_rec.uid = uid_$nil then begin
    status.all := ast_$validate_uid(loc_rec.uid, 16#30F01);
    return;
  end;

  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);
  aote := ast_$lookup_aote_by_uid(loc_rec.uid);

  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(loc_rec.uid, location,
                                        local_status,
                                        7 in ast_$word_set_t(flags));
    status := local_status;
    if aote = nil then
      goto 40;
  end
  else begin
    aote^.flags := aote^.flags + [6];
    status.all := status_$ok;
    if 5 in ast_$word_set_t(flags) then begin
      if not aote^.loc.remote then
        goto 20;

      { a remote object's attributes, fetched afresh without the AST lock;
        the AOTE is marked in transition meanwhile }
      aote^.flags := aote^.flags + [7];
      ml_$unlock(ml_$ast_lock);
      if not ast_$aote_view_ptr_t(aote)^.attrs.sa.aflags.exec and then
         ((9 in ast_$word_set_t(flags)) or else (4 in aote^.flags)) then
        req_flags := 16#88
      else
        req_flags := 8;
      aote^.flags := aote^.flags - [4];

      network_$ast_get_info(ast_$aote_view_ptr_t(aote)^.obj_loc.net,
                            req_flags,
                            ast_$attr_rec_ptr_t(addr(attrs))^.net,
                            local_status);
      status := local_status;

      ml_$lock(ml_$ast_lock);
      if status.all = status_$ok then begin
        { keep the larger length and the AOTE's DTV across the copy }
        ml_$lock(ml_$pmap_lock);
        len := aote^.length;
        if len <= linteger(attrs.length) then
          len := linteger(attrs.length);
        saved_dtv := aote^.dtv;
        ast_$aote_view_ptr_t(aote)^.attrs.fattr := attrs;
        aote^.length := len;
        aote^.dtv := saved_dtv;
        loc_rec := ast_$aote_view_ptr_t(aote)^.obj_loc.floc;
        ml_$unlock(ml_$pmap_lock);
      end;

      aote^.flags := aote^.flags - [7];
      ec_$advance(ast_$ast_in_trans_ec);
      goto 40;
    end;
  end;

  if aote^.loc.remote then
    goto 30;

20:
  { a local object: bit 9 or the touched mark stamps the DTU }
  if (9 in ast_$word_set_t(flags)) or else (4 in aote^.flags) then begin
    ml_$lock(ml_$pmap_lock);
    time_$clock(aote^.dtu);
    aote^.flags := aote^.flags + [5];
    aote^.flags := aote^.flags - [4];
    ml_$unlock(ml_$pmap_lock);
  end;

30:
  attrs := ast_$aote_view_ptr_t(aote)^.attrs.fattr;
  loc_rec := ast_$aote_view_ptr_t(aote)^.obj_loc.floc;

40:
  ml_$unlock(ml_$ast_lock);
  if (status.all = status_$ok) and then (7 in ast_$word_set_t(flags)) and then
     (7 in loc_rec.flags) then
    status.all := file_$object_not_found;
  proc1_$inhibit_end;
  if loc_rec.loc_info = 0 then
    loc_rec.loc_info := network_$me;
end;
