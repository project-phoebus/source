{ ACL_$EXIT_SUPER - leave super-user mode.

  Image addresses:
    sau2  0x00E46FB4  ACL_$EXIT_SUPER

  - A process not in super-user mode crashes the system
    (status_$acl_exit_super_unbalanced); the count goes down by one.

  Status stored: none.
}

procedure acl_$exit_super;
begin
  if acl_$super_count[proc1_$current] = 0 then
    crash_system(status_$acl_exit_super_unbalanced);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;
end;
