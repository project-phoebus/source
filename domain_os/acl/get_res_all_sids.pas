{ ACL_$GET_RES_ALL_SIDS - the current process's original, current and
  saved SIDs and its two project lists.

  Image addresses:
    sau2  0x00E4881C  ACL_$GET_RES_ALL_SIDS
    sau9  0x3C44FEF4  ACL_$GET_RES_ALL_SIDS

  Status stored:
    status_$ok: always
}

procedure acl_$get_res_all_sids(out original_sids: acl_sid_block_t;
                                out current_sids: acl_sid_block_t;
                                out saved_sids: acl_sid_block_t;
                                out saved_proj: acl_proj_list_t;
                                out current_proj: acl_proj_list_t;
                                out status_ret: status_$t);
begin
  original_sids := acl_$original_sids[proc1_$current];
  current_sids := acl_$current_sids[proc1_$current];
  saved_sids := acl_$saved_sids[proc1_$current];
  saved_proj := acl_$saved_proj[proc1_$current];
  current_proj := acl_$proj_lists[proc1_$current];

  status_ret.all := status_$ok;
end;
