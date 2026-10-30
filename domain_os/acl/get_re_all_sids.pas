{ ACL_$GET_RE_ALL_SIDS - the current process's original and current SIDs
  and its two project lists.

  Image addresses:
    sau2  0x00E48792  ACL_$GET_RE_ALL_SIDS
    sau9  0x3C44FE70  ACL_$GET_RE_ALL_SIDS

  - The original SIDs, current SIDs, saved project list and project
    list, whole-record copies.

  Status stored:
    status_$ok: always
}

procedure acl_$get_re_all_sids(out acl_data: acl_sid_block_t;
                               out re_sids: acl_sid_block_t;
                               out prot_info: acl_prot_info_t;
                               out subsys_ids: acl_prot_info_t;
                               out status: status_$t);
begin
  acl_data := acl_$original_sids[proc1_$current];
  re_sids := acl_$current_sids[proc1_$current];
  prot_info := acl_$saved_proj[proc1_$current];
  subsys_ids := acl_$proj_lists[proc1_$current];

  status.all := status_$ok;
end;
