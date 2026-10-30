{ ACL_$USED_SUSER - whether the current process has used its super-user
  rights.

  Image addresses:
    sau2  0x00E492CC  ACL_$USED_SUSER
    sau9  0x3C450982  ACL_$USED_SUSER

  - The process's element of acl_$asid_suser_bitmap, set by
    acl_$check_suser_pid and ACL_$SET_LOCAL_LOCKSMITH, cleared by
    ACL_$FREE_ASID.

  Status stored: none.
}

function acl_$used_suser: boolean;
begin
  acl_$used_suser := acl_$asid_suser_bitmap[proc1_$current];
end;
