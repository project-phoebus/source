{ ACL_$SET_LOCAL_LOCKSMITH - set the local locksmith value.

  Image addresses:
    sau2  0x00E49196  ACL_$SET_LOCAL_LOCKSMITH
    sau9  0x3C450846  ACL_$SET_LOCAL_LOCKSMITH

  - Only a process whose login, group or user SID is the locksmith UID;
    its super-user bit is set and the module's local locksmith word
    takes the value.

  Status stored:
    status_$ok: the value was set
    status_$no_right_to_perform_operation: the caller is no locksmith
}

procedure acl_$set_local_locksmith(in value: integer; out status: status_$t);
begin
  status.all := status_$no_right_to_perform_operation;

  if (acl_$current_sids[proc1_$current].login_sid = acl_$locksmith_uid)
     or else
     (acl_$current_sids[proc1_$current].group_sid = acl_$locksmith_uid)
     or else
     (acl_$current_sids[proc1_$current].user_sid = acl_$locksmith_uid)
  then begin
    status.all := status_$ok;
    acl_$asid_suser_bitmap[proc1_$current] := true;
    acl_$local_locksmith := value;
  end;
end;
