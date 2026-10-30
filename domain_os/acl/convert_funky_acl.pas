{ ACL_$CONVERT_FUNKY_ACL - turn a "funky" ACL UID into ACL data.

  Image addresses:
    sau2  0x00E4900C  ACL_$CONVERT_FUNKY_ACL

  - The selector is bits 4..11 of the UID's low half's high word,
    masked with 16#E0; the UID used has bits 25..27 of its low half
    cleared.
  - 16#80: the named object's ACL attributes, copied out whatever the
    status; 16#40 and 16#20: the named directory's default file or
    directory protection.

  Status stored:
    ast_$get_acl_attributes' status: selector 16#80
    dir_$get_def_protection's status: selector 16#40 or 16#20
    status_$ok: any other selector (nothing else is written)
}

procedure acl_$convert_funky_acl(in acl_uid: uid_$t;
                                 var prot: acl_$prot_data_t;
                                 var norm_uid: uid_$t;
                                 out acl_type_uid: uid_$t;
                                 out status: status_$t);
var
  loc: file_$obj_loc_t;
  attr: ast_$acl_attr_t;
  uid: acl_$uid_view_t;
  attr_status: status_$t;
begin
  status.all := status_$ok;
  uid.uid := acl_uid;
  uid.low_set := uid.low_set - [25..27];

  case rshft(acl_$uid_view_t(acl_uid).w2 & 16#FF0, 4) & 16#E0 of
    16#80: begin
      loc.uid := uid.uid;
      loc.flags := loc.flags - [6];
      ast_$get_acl_attributes(loc, 16#21, attr, attr_status);
      status := attr_status;
      prot := attr.prot;
      norm_uid := attr.default_acl;
      if (attr.sub_type = 1) or else (attr.sub_type = 2) then
        acl_type_uid := acl_$dir_acl
      else
        acl_type_uid := acl_$file_acl;
      if attr.obj_type = 0 then
        acl_$uid_view_ptr_t(addr(norm_uid))^.low_set :=
          acl_$uid_view_ptr_t(addr(norm_uid))^.low_set + [24];
    end;
    16#40: begin
      dir_$get_def_protection(uid.uid, acl_$file_acl, prot, norm_uid,
                              status);
      acl_type_uid := acl_$file_acl;
    end;
    16#20: begin
      dir_$get_def_protection(uid.uid, acl_$dir_acl, prot, norm_uid,
                              status);
      acl_type_uid := acl_$dir_acl;
    end;
  end;
end;
