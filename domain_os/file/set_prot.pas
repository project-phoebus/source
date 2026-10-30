{ file_$get_default_prot - the object's type, for a default protection.

  Image addresses:
    sau2  0x00E5DEF4  file_$get_default_prot

  - Nested in FILE_$SET_PROT: the common attributes of its parent's
    object (AST_$GET_COMMON_ATTRIBUTES, selector 1) give the object's
    type byte, the result as a word.

  Status stored (in the parent's local_status):
    ast_$get_common_attributes's status: in either case
}

{ FILE_$SET_PROT - set an object's protection of a given kind.

  Image addresses:
    sau2  0x00E5DF3A  FILE_$SET_PROT

  - With the ACL UID's kind bit 4, the object's default protection: the
    nested file_$get_default_prot looks its type up; type 0 gets the
    default ACL data and kind 6.
  - Otherwise the caller's record and UID; the kind selects the
    attribute, and FILE_$SET_PROT_INT does the rest.

  Status stored:
    file_$set_prot_int's status: the protection was set, or not
    ast_$get_common_attributes's status: the type could not be had
    file_$invalid_arg: a default for a type other than 0, or a kind
      above 6
}

procedure file_$set_prot(in file_uid: uid_$t; in prot_type: integer;
                         in acl_data: acl_$prot_data_t;
                         in def_acl: uid_$t; out status_ret: status_$t);
label
  10;
var
  def_uid: uid_$t;
  rec: file_$set_prot_rec_t;
  local_status: status_$t;
  default_prot: integer;
  type_val: integer;
  attr_id: integer;

  procedure file_$get_default_prot(out prot: integer);
  var
    desc: file_$obj_loc_t;
    cattr: ast_$common_attr_t;
  begin
    desc.uid := file_uid;
    desc.flags := desc.flags - [6];

    ast_$get_common_attributes(desc, 1, cattr, local_status);
    prot := ord(cattr.obj_type);
  end;

begin
  type_val := prot_type;
  if (rshft(file_$uid_view_t(def_acl).w2 & 16#FF0, 4) & 16#10) <> 0 then
    begin
    { the default protection }
    rec.acl_uid.uid := def_acl;
    rec.acl_uid.low_set := rec.acl_uid.low_set - [24..27];
    file_$get_default_prot(default_prot);
    status_ret := local_status;
    if local_status.all <> status_$ok then
      return;
    if default_prot <> 0 then begin
      status_ret.all := file_$invalid_arg;
      goto 10;
    end;
    type_val := file_$prot_acl;
    acl_$def_acldata(rec.prot, def_uid);
  end
  else begin
    rec.prot := acl_data;
    rec.acl_uid.uid := def_acl;
  end;

  { the attribute }
  case type_val of
    file_$prot_owner1: begin
      attr_id := 16#10;
    end;
    file_$prot_owner2: begin
      attr_id := 16#11;
    end;
    file_$prot_owner3: begin
      attr_id := 16#12;
    end;
    file_$prot_rights: begin
      attr_id := 16#15;
    end;
    file_$prot_acl_image: begin
      attr_id := 16#13;
    end;
    file_$prot_merge_acl: begin
      attr_id := 16#14;
    end;
    file_$prot_acl: begin
         attr_id := 3;
         rec.prot.owner := rec.acl_uid.uid;
       end;
    otherwise begin
      status_ret.all := file_$invalid_arg;
      goto 10;
    end;
  end;

  file_$set_prot_int(file_uid, rec, attr_id, type_val, false, status_ret);
  return;

10:
  if audit_$enabled then
    file_$audit_set_prot(file_uid, acl_data, def_acl, prot_type,
                         status_ret);
end;
