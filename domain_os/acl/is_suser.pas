{ ACL_$IS_SUSER - whether the current process is a super-user.

  Image addresses:
    sau2  0x00E47E8C  ACL_$IS_SUSER

  - acl_$check_suser_pid for the current process.

  Status stored: none.
}

function acl_$is_suser: boolean;
begin
  acl_$is_suser := acl_$check_suser_pid(proc1_$current);
end;
