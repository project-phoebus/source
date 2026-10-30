{ ACL_$GET_RES_SIDS - the current process's original, current and saved
  SIDs.

  Image addresses:
    sau2  0x00E4890C  ACL_$GET_RES_SIDS

  Status stored:
    status_$ok: always
}

procedure acl_$get_res_sids(out original_sids: acl_sid_block_t;
                            out current_sids: acl_sid_block_t;
                            out saved_sids: acl_sid_block_t;
                            out status_ret: status_$t);
begin
  original_sids := acl_$original_sids[proc1_$current];
  current_sids := acl_$current_sids[proc1_$current];
  saved_sids := acl_$saved_sids[proc1_$current];

  status_ret.all := status_$ok;
end;
