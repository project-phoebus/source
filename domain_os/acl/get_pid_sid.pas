{ ACL_$GET_PID_SID - a process's current SID block.

  Image addresses:
    sau2  0x00E489E2  ACL_$GET_PID_SID

  - The pid is not range-checked.

  Status stored:
    status_$ok: always
}

procedure acl_$get_pid_sid(pid: integer; out sid_ret: acl_sid_block_t;
                           out status_ret: status_$t);
begin
  sid_ret := acl_$current_sids[pid];

  status_ret.all := status_$ok;
end;
