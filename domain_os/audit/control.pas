{ AUDIT_$CONTROL - the audit trail's control call.

  Image addresses:
    sau2  0x00E71534  AUDIT_$CONTROL

  - Command 6 asks whether the calling process is audited.
  - The others need an audit administrator, a caller whose login SID is
    the login UID, or process 1, and run in super mode with the caller's
    auditing suspended.
  - 0 loads the list, 1 flushes the log (closes and reopens it), 2 and 3
    start and stop logging, 4 and 5 lower and raise the caller's own
    suspension count (4 not below 1).

  Status stored:
    status_$audit_logging_is_enabled: command 6, the process audited
    status_$audit_event_logging_is_disabled: command 6, it is not
    status_$audit_permission_denied: the caller has no right
    status_$audit_invalid_action_code: a command above 6
    status_$ok: commands 4 and 5
    the callees' statuses: commands 0..3, or the rights checks
}

procedure audit_$control(in command: integer; out status: status_$t);
var
  saved_sids: acl_sid_block_t;
  sids: acl_sid_block_t;
begin
  if command = audit_ctrl_is_enabled then begin
    if audit_$enabled and then (audit_$suspend_count[proc1_$current] = 0)
    then
      status.all := status_$audit_logging_is_enabled
    else
      status.all := status_$audit_event_logging_is_disabled;
  end

  else begin
    { the caller's rights }
    status.all := status_$ok;
    if not audit_$administrator(status) then begin
      acl_$get_re_sids(sids, saved_sids, status);
      if (saved_sids.login_sid <> rgyc_$g_login_uid) and then
         (proc1_$current <> 1) then
        status.all := status_$audit_permission_denied;
    end;

    if status.all = status_$ok then begin
      status.all := status_$audit_invalid_action_code;
      audit_$suspend_count[proc1_$current] :=
        audit_$suspend_count[proc1_$current] + 1;
      acl_$enter_super;
      case command of
        audit_ctrl_load_list: begin
          discard(audit_$load_list(status));
        end;
        audit_ctrl_flush: begin
          ml_$exclusion_start(audit_$wired^.lock);
          audit_$close_log(status);
          audit_$open_log(status);
          ml_$exclusion_stop(audit_$wired^.lock);
        end;
        audit_ctrl_start: begin
          audit_$start_logging(status);
        end;
        audit_ctrl_stop: begin
          audit_$stop_logging(status);
        end;
        audit_ctrl_resume_self: begin
          if audit_$suspend_count[proc1_$current] > 1 then
            audit_$suspend_count[proc1_$current] :=
              audit_$suspend_count[proc1_$current] - 1;
          status.all := status_$ok;
        end;
        audit_ctrl_suspend_self: begin
          audit_$suspend_count[proc1_$current] :=
            audit_$suspend_count[proc1_$current] + 1;
          status.all := status_$ok;
        end;
      end;
      acl_$exit_super;
      audit_$suspend_count[proc1_$current] :=
        audit_$suspend_count[proc1_$current] - 1;
    end;
  end;
end;
