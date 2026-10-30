{ acl_$check_suser_pid - whether a process is a super-user.

  Image addresses:
    sau2  0x00E463E4  acl_$check_suser_pid (module-local)

  - Process 1, a process in super mode (a count above 0, signed), one
    logged in as the login UID, or one with the locksmith as its user,
    group or login SID.
  - A super-user's bit in the "used super-user rights" map is set.

  Status stored: none.
}

function acl_$check_suser_pid(pid: integer): boolean; internal;
begin
  acl_$check_suser_pid := false;

  with acl_$current_sids[pid] do
    if (pid = 1) or else (acl_$super_count[pid] > 0) or else
       (login_sid = acl_$login_uid) or else
       (user_sid = acl_$locksmith_uid) or else
       (group_sid = acl_$locksmith_uid) or else
       (login_sid = acl_$locksmith_uid) then begin
      acl_$check_suser_pid := true;
      acl_$asid_suser_bitmap[pid] := true;
    end;
end;
