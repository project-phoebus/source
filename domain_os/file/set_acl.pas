{ FILE_$SET_ACL - set an object's protection from an ACL UID.

  Image addresses:
    sau2  0x00E5E06A  FILE_$SET_ACL

  - ACL_$CONVERT_FUNKY_ACL turns the ACL UID into a protection record and
    a normalized UID, and FILE_$SET_PROT sets them as kind 4.
  - The paths that do not reach FILE_$SET_PROT (which audits for
    itself) are audited here.

  Status stored:
    file_$set_prot's status: the protection was set, or not
    status_$acl_unimplemented_call: the ACL UID's kind field has none of
      the bits 16#E0
    acl_$convert_funky_acl's status: the conversion failed
}

procedure file_$set_acl(in file_uid: uid_$t; acl_uid: uid_$t;
                        out status_ret: status_$t);
label
  10;
var
  target_uid: uid_$t;
  prot_info: uid_$t;
  acl_data: acl_$prot_data_t;
begin
  if (rshft(file_$uid_view_t(acl_uid).w2 & 16#FF0, 4) & 16#E0) <> 0 then
    begin
    acl_$convert_funky_acl(acl_uid, acl_data, prot_info, target_uid,
                           status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end
  else begin
    status_ret.all := status_$acl_unimplemented_call;
    goto 10;
  end;

  file_$set_prot(file_uid, file_$prot_acl_image, acl_data, prot_info,
                 status_ret);
  return;

10:
  if audit_$enabled then
    file_$audit_set_prot(file_uid, acl_data, prot_info, 4, status_ret);
end;
