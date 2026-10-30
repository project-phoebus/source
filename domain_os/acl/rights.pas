{ ACL_$RIGHTS - the rights the current process has to an object.

  Image addresses:
    sau2  0x00E46A00  ACL_$RIGHTS
    sau9  0x3C44E158  ACL_$RIGHTS

  - acl_$eval_rights for the current process's SIDs and projects, with
    its super-user and subsystem states; its result is the routine's.

  Status stored:
    acl_$eval_rights' status: always
}

function acl_$rights(uid: uid_$t; in ignore_super: boolean;
                     in required_mask: integer32; in option_flags: integer;
                     out status: status_$t): integer32;
begin
  acl_$rights := acl_$eval_rights(acl_$current_sids[proc1_$current],
                                  acl_$proj_uids[proc1_$current], uid,
                                  ignore_super, required_mask,
                                  option_flags,
                                  acl_$super_count[proc1_$current] > 0,
                                  acl_$subsys_level[proc1_$current] > 0,
                                  status);
end;
