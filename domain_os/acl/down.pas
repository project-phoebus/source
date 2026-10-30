{ ACL_$DOWN - leave a protected subsystem for rights checking.

  Image addresses:
    sau2  0x00E47068  ACL_$DOWN

  - The current process's subsystem level goes down by one, never below
    0 (a signed test).

  Status stored: none.
}

procedure acl_$down;
begin
  if acl_$subsys_level[proc1_$current] > 0 then
    acl_$subsys_level[proc1_$current] :=
      acl_$subsys_level[proc1_$current] - 1;
end;
