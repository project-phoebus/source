{ ACL_$ENTER_SUPER - enter super-user mode.

  Image addresses:
    sau2  0x00E46F90  ACL_$ENTER_SUPER
    sau9  0x3C44E6C6  ACL_$ENTER_SUPER

  - The current process's super-user count goes up by one.

  Status stored: none.
}

procedure acl_$enter_super;
begin
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
end;
