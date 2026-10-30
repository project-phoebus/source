{ ACL_$CHECK_DEBUG_RIGHTS - whether a process may debug another.

  Image addresses:
    sau2  0x00E48ADA  ACL_$CHECK_DEBUG_RIGHTS
    sau9  0x3C4501B2  ACL_$CHECK_DEBUG_RIGHTS

  - The first process must be allowed the second's saved and original
    SID blocks (acl_$sids_allowed) and hold every project of the
    second's.
  - The super-user test only presets the result true, so a failing SID
    or project test returns true for a super-user.
  - A first process's list with no nil entry fails as a nil entry would
    when nothing matches (k left at 9).

  Status stored: none.
}

function acl_$check_debug_rights(in pid1: pinteger; in pid2: pinteger):
  boolean;
var
  j: integer;                             { held as 8 * j }
  k: integer;
begin
  { the super-user preset }
  acl_$check_debug_rights := false;
  if acl_$check_suser_pid(pid1) then
    acl_$check_debug_rights := true;

  { the second process's saved and original
    SIDs }
  if not acl_$sids_allowed(acl_$saved_sids[pid2], pid1) then
    return;
  if not acl_$sids_allowed(acl_$original_sids[pid2], pid1) then
    return;

  { every project of the second process is one
    of the first's }
  for j := 1 to 8 do begin
    if acl_$proj_uids[pid2, j] = uid_$nil then
      exit;
    for k := 1 to 8 do
      if (acl_$proj_uids[pid1, k] = uid_$nil) or else
         (acl_$proj_uids[pid2, j] = acl_$proj_uids[pid1, k]) then
        exit;
    if k > 8 then
      return;
    if acl_$proj_uids[pid1, k] = uid_$nil then
      return;
  end;

  acl_$check_debug_rights := true;
end;
