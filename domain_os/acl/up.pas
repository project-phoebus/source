{ ACL_$UP - enter a protected subsystem for rights checking.

  Image addresses:
    sau2  0x00E4703E  ACL_$UP

  - The current process's subsystem level goes up by one.  Apollo's
    aclm.ins.pas: "afterwards, all accesses are granted (unless
    weakened), on the assumption that the object is being used by the
    owning subsystem".

  Status stored: none.
}

procedure acl_$up;
begin
  acl_$subsys_level[proc1_$current] := acl_$subsys_level[proc1_$current] + 1;
end;
