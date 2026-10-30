{ ACL_$DEFAULT_ACL - the default ACL UID for an object type.

  Image addresses:
    sau2  0x00E4787E  ACL_$DEFAULT_ACL

  - Types 0, 5 and 4 get ACL_$FNDWRX, types 1 and 2 ACL_$DNDCAL, type 3
    the nil UID; any other type leaves the result unwritten.

  Status stored: none.
}

function acl_$default_acl(in acl_type: integer): uid_$t;
begin
  if (acl_type = 0) or else (acl_type = 5) or else (acl_type = 4) then
    acl_$default_acl := acl_$fndwrx
  else if (acl_type = 1) or else (acl_type = 2) then
    acl_$default_acl := acl_$dndcal
  else if acl_type = 3 then
    acl_$default_acl := uid_$nil;
end;
