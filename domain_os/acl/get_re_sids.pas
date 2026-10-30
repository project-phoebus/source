{ ACL_$GET_RE_SIDS - the current process's original and current SIDs.

  Image addresses:
    sau2  0x00E488B6  ACL_$GET_RE_SIDS

  Status stored:
    status_$ok: always
}

procedure acl_$get_re_sids(out original_sids: acl_sid_block_t;
                           out current_sids: acl_sid_block_t;
                           out status_ret: status_$t);
begin
  original_sids := acl_$original_sids[proc1_$current];
  current_sids := acl_$current_sids[proc1_$current];

  status_ret.all := status_$ok;
end;
