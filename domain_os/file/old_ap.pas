{ FILE_$OLD_AP - set an object's protection, the pre-SR10 interface.

  Image addresses:
    sau2  0x00E5E100  FILE_$OLD_AP

  - Kind 6 sets the ACL attribute (3) from the ACL UID alone; any other
    kind sets attribute 16#13 from the caller's protection record.  Both
    go to FILE_$SET_PROT_INT with the subsystem flag set.

  Status stored:
    file_$set_prot_int's status: in either case
}

procedure file_$old_ap(in file_uid: uid_$t; in prot_type: integer;
                       in acl_data: acl_$prot_data_t; in def_acl: uid_$t;
                       out status_ret: status_$t);
var
  rec: file_$set_prot_rec_t;
  attr_id: integer;
begin
  if prot_type = file_$prot_acl then begin
    rec.prot.owner := def_acl;
    rec.acl_uid.uid := def_acl;
    attr_id := 3;
  end
  else begin
    rec.prot := acl_data;
    rec.acl_uid.uid := def_acl;
    attr_id := 16#13;
  end;

  file_$set_prot_int(file_uid, rec, attr_id, prot_type, true, status_ret);
end;
