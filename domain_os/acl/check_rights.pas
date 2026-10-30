{ ACL_$CHECK_RIGHTS - an object's rights for a given SID context.

  Image addresses:
    sau2  0x00E46A8E  ACL_$CHECK_RIGHTS

  - acl_$eval_rights for the context's SIDs and projects, never
    ignoring super-user mode, with the current process's super-user
    state and no subsystem; its result is the routine's.

  Status stored:
    acl_$eval_rights' status: always
}

function acl_$check_rights(in acl_ctx: acl_$exsid_t; file_uid: uid_$t;
                           in required_mask: integer32;
                           in option_flags: integer;
                           out status: status_$t): integer32;
begin
  acl_$check_rights := acl_$eval_rights(acl_ctx.sids, acl_ctx.proj_uids,
                                        file_uid, false, required_mask,
                                        option_flags,
                                        acl_$super_count[proc1_$current]
                                        > 0, false, status);
end;
