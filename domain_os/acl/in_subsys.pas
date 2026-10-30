{ ACL_$IN_SUBSYS - whether the current process is in a protected
  subsystem.

  Image addresses:
    sau2  0x00E47098  ACL_$IN_SUBSYS

  - True when the subsystem level is above 0.

  Status stored: none.
}

function acl_$in_subsys: boolean;
begin
  acl_$in_subsys := acl_$subsys_level[proc1_$current] > 0;
end;
