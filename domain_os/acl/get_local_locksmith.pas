{ ACL_$GET_LOCAL_LOCKSMITH - the local locksmith value.

  Image addresses:
    sau2  0x00E4923C  ACL_$GET_LOCAL_LOCKSMITH

  - The result is the module's local locksmith word, which
    ACL_$SET_LOCAL_LOCKSMITH sets.

  Status stored: none.
}

function acl_$get_local_locksmith: integer;
begin
  acl_$get_local_locksmith := acl_$local_locksmith;
end;
