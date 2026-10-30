{ ACL_$CLEAR_SUPER - leave super-user mode altogether.

  Image addresses:
    sau2  0x00E46FF8  ACL_$CLEAR_SUPER
    sau9  0x3C44E71C  ACL_$CLEAR_SUPER

  - The super-user count is cleared; a locksmith override this process
    holds is turned off and the ACL exclusion region left.

  Status stored: none.
}

procedure acl_$clear_super;
var
  unused_4: integer32;                    { a stand-in }
begin
  acl_$super_count[proc1_$current] := 0;
  if acl_$locksmith_override and then
     (proc1_$current = acl_$locksmith_owner_pid) then begin
    ml_$exclusion_stop(acl_$exclusion_lock);
    acl_$locksmith_override := false;
  end;
end;
