{ ACL_$CHECK_FAULT_RIGHTS - whether a process may handle another's faults.

  Image addresses:
    sau2  0x00E48A28  ACL_$CHECK_FAULT_RIGHTS

  - True for a super-user, a process of the other type
    (acl_$is_process_type_2), or a match of one of four user-SID pairs:
    the first's original or current with the second's saved or current.
  - The super-user and type tests only preset the result; the SID
    compares always run.

  Status stored: none.
}

function acl_$check_fault_rights(in pid1: pinteger; in pid2: pinteger):
  boolean;
begin
  { the super-user and process-type presets }
  acl_$check_fault_rights := false;
  if acl_$check_suser_pid(pid1) then
    acl_$check_fault_rights := true;
  if acl_$is_process_type_2(pid1) then
    acl_$check_fault_rights := true;

  { the four user SID pairs }
  if (acl_$original_sids[pid1].user_sid = acl_$saved_sids[pid2].user_sid)
     or else
     (acl_$original_sids[pid1].user_sid = acl_$current_sids[pid2].user_sid)
     or else
     (acl_$current_sids[pid1].user_sid = acl_$current_sids[pid2].user_sid)
     or else
     (acl_$current_sids[pid1].user_sid = acl_$saved_sids[pid2].user_sid)
  then
    acl_$check_fault_rights := true;
end;
