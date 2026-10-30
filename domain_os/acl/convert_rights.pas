{ acl_$convert_rights - convert a version-4 rights longword to version 5.

  Image addresses:
    sau2  0x00E44DBE  acl_$convert_rights (module-local)

  - A file ACL: old bits 1, 2, 0 give new 2, 1, 0, and old 3 clear new
    6.  A directory ACL: old 0 new 2, old 3, 1, 2 and 6 together new 1,
    old 5 new 0, old 4 clear new 6.  Any type: old 25 gives new 3.

  Status stored: none.
}

function acl_$convert_rights(old_rights: integer32;
                             in acl_type_uid: uid_$t): pinteger;
  internal;
var
  new_rights: pinteger;
begin
  new_rights := 0;

  { a file ACL }
  if acl_type_uid = acl_$file_acl then begin
    if (old_rights & 16#2) <> 0 then
      new_rights := 16#4;
    if (old_rights & 16#4) <> 0 then
      new_rights := new_rights ! 16#2;
    if (old_rights & 16#1) <> 0 then
      new_rights := new_rights ! 16#1;
    if (old_rights & 16#8) = 0 then
      new_rights := new_rights ! 16#40;
  end;

  { a directory ACL }
  if acl_type_uid = acl_$dir_acl then begin
    if (old_rights & 16#1) <> 0 then
      new_rights := new_rights ! 16#4;
    if ((old_rights & 16#8) <> 0) and then ((old_rights & 16#2) <> 0)
       and then ((old_rights & 16#4) <> 0)
       and then ((old_rights & 16#40) <> 0) then
      new_rights := new_rights ! 16#2;
    if (old_rights & 16#20) <> 0 then
      new_rights := new_rights ! 16#1;
    if (old_rights & 16#10) = 0 then
      new_rights := new_rights ! 16#40;
  end;

  { any type }
  if (old_rights & 16#2000000) <> 0 then
    new_rights := new_rights ! 16#8;

  acl_$convert_rights := new_rights;
end;
