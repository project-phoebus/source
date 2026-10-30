{ ACL_$RIGHTS_CHECK - an object's rights for a given SID context, in or
  out of a subsystem.

  Image addresses:
    sau2  0x00E46AEC  ACL_$RIGHTS_CHECK

  - ACL_$CHECK_RIGHTS with the caller's flag as the in-subsystem state;
    acl_$eval_rights' result is the routine's.

  Status stored:
    acl_$eval_rights' status: always
}

function acl_$rights_check(in acl_ctx: acl_$exsid_t; file_uid: uid_$t;
                           in required_mask: integer32;
                           in option_flags: integer;
                           in check_flag: boolean;
                           out status: status_$t): integer32;
begin
  acl_$rights_check := acl_$eval_rights(acl_ctx.sids, acl_ctx.proj_uids,
                                        file_uid, false, required_mask,
                                        option_flags,
                                        acl_$super_count[proc1_$current]
                                        > 0, check_flag, status);
end;
