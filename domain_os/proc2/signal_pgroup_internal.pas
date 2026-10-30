{ proc2_$signal_pgroup_internal - send a signal to every member of a
  process group.

  Image addresses:
    sau2  0x00E3F160  proc2_$signal_pgroup_internal (module-local)

  - Each live member gets the signal when no check is asked for,
    ACL_$CHECK_FAULT_RIGHTS grants it, or for a SIGCONT; the attempt is
    logged (event type 2).
  - The SIGCONT test compares the member's session with its own.

  Status stored:
    status_$ok: a member got the signal
    status_$proc2_permission_denied: a member was refused
    status_$proc2_zombie: nobody got it, a zombie member seen
    proc2_$uid_not_found: group index 0, or nobody got it
}

procedure proc2_$signal_pgroup_internal(pgroup_idx: pinteger;
                                        signal: integer;
                                        param: status_$t;
                                        check_perms: boolean;
                                        out status_ret: status_$t);
  internal;
var
  param_copy: status_$t;
  deliver_status: status_$t;
  delivered: boolean;
  saw_zombie: boolean;
  idx: integer;
  entry: proc2_info_ptr_t;
  session_ref: proc2_info_ptr_t;
begin
  if pgroup_idx = 0 then
    status_ret.all := proc2_$uid_not_found
  else begin
    status_ret.all := status_$ok;
    delivered := false;
    saw_zombie := false;
    param_copy := param;
    idx := p2_info_alloc_ptr;
    if idx <> 0 then
      repeat
        session_ref := addr(proc2_$info_table[idx]);
        entry := session_ref;
        if entry^.pgroup_table_idx = pgroup_idx then
          if proc2_pf_zombie in entry^.flags.bits then
            saw_zombie := true
          else if not check_perms
                  or else acl_$check_fault_rights(proc1_$current,
                                                  entry^.level1_pid)

                  or else ((signal = proc2_$sig_cont)
                           and then (entry^.session_id =
                                     session_ref^.session_id)) then begin

            proc2_$deliver_signal_internal(idx, signal, param_copy,
                                           deliver_status);
            delivered := true;
          end
          else
            status_ret.all := status_$proc2_permission_denied;

        idx := entry^.next_index;
      until idx = 0;
    if not delivered then
      if saw_zombie then
        status_ret.all := status_$proc2_zombie
      else
        status_ret.all := proc2_$uid_not_found;
  end;
  proc2_$log_signal_event(proc2_signal_event_pgroup, pgroup_idx, signal,
                          param, status_ret);
end;
