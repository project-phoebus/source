{ ACL_$GET_SID - the current process's original SID block.

  Image addresses:
    sau2  0x00E74C24  ACL_$GET_SID

  - The original SIDs are the process's before it entered any
    subsystem.

  Status stored:
    status_$ok: always
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure acl_$get_sid(out sid_ret: acl_sid_block_t;
                       out status_ret: status_$t);
begin
  sid_ret := acl_$original_sids[proc1_$current];
  status_ret.all := status_$ok;
end;
