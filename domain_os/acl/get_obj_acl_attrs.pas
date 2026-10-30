{ acl_$get_obj_acl_attrs - an object's location and ACL attributes.

  Image addresses:
    sau2  0x00E45F78  acl_$get_obj_acl_attrs (module-local)

  - The UID is normalized (bit 24 cleared; a "funky" one converted
    first); the hint cache says whether to ask AST in remote mode.
  - The well-known UIDs answer for themselves (sub-type 3, type 1);
    otherwise AST_$GET_ACL_ATTRIBUTES, asked again remotely when AST
    says local but the hint cache did not.
  - A file or directory's default ACL is adjusted (ACL_$DNDCAL for
    ACL_$NIL); the default ACL's bit 24 is cleared last.

  Status stored:
    status_$ok: a well-known UID, or the attributes were read
    file_$object_not_found: UID_$NIL
    ast_$get_acl_attributes' status: the attributes could not be read
}

procedure acl_$get_obj_acl_attrs(uid: uid_$t; var loc: file_$obj_loc_t;
                                 var attrs: ast_$acl_attr_t;
                                 out status: status_$t); internal;
var
  acl_type_uid: uid_$t;
  norm_uid: acl_$uid_view_t;
  ast_status: status_$t;
  ast_mode: integer;
  hint_flag: boolean;
begin
  status.all := status_$ok;

  { the normalized UID }
  norm_uid.uid := uid;
  norm_uid.low_set := norm_uid.low_set - [24];
  if (rshft(acl_$uid_view_t(uid).w2 & 16#FF0, 4) & 16#E0) <> 0 then begin
    acl_$convert_funky_acl(uid, attrs.prot, norm_uid.uid, acl_type_uid,
                           status);
    norm_uid.low_set := norm_uid.low_set - [24];
  end;

  loc.uid := norm_uid.uid;
  loc.flags := loc.flags - [6];
  hint_$lookup_cache(norm_uid.low & 16#FFFFF, hint_flag);
  if hint_flag then
    ast_mode := 16#21
  else
    ast_mode := 1;

  { the well-known UIDs }
  if (norm_uid.b0 = 0) and then
     ((acl_$uid_view_ptr_t(addr(norm_uid))^.w0 = 1) or else
      (acl_$uid_view_ptr_t(addr(norm_uid))^.w0 = 2) or else
      (uid = acl_$nil) or else (uid = uid_$nil)) then begin
    attrs.default_acl := norm_uid.uid;
    attrs.sub_type := 3;
    attrs.obj_type := 1;
    loc.flags := loc.flags - [7];
    attrs.obj_flags := attrs.obj_flags - [0];
    if uid = uid_$nil then
      status.all := file_$object_not_found;
    return;
  end;

  { ask AST }
  ast_$get_acl_attributes(loc, ast_mode, attrs, ast_status);
  if ast_status.code <> 0 then begin
    status := ast_status;
    return;
  end;
  if (0 in attrs.obj_flags) and then not hint_flag then begin
    ast_$get_acl_attributes(loc, 16#21, attrs, ast_status);
    if ast_status.code <> 0 then begin
      status := ast_status;
      return;
    end;
  end;

  { the default ACL }
  if (acl_$uid_view_t(attrs.default_acl).high <> 0) and then
     ((attrs.sub_type = 2) or else (attrs.sub_type = 1)) then begin
    if attrs.default_acl = acl_$nil then
      attrs.default_acl := acl_$dndcal
    else if acl_$uid_view_ptr_t(addr(attrs.default_acl))^.w0 = 1 then
      acl_$uid_view_ptr_t(addr(attrs.default_acl))^.w0 := 2;
  end
  else if attrs.sub_type = 3 then
    attrs.default_acl := uid;
  acl_$uid_view_ptr_t(addr(attrs.default_acl))^.low_set :=
    acl_$uid_view_ptr_t(addr(attrs.default_acl))^.low_set - [24];
end;
