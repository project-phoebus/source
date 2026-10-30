{ AUDIT_$SERVER - the audit server process.

  Image addresses:
    sau2  0x00E710C6  AUDIT_$SERVER

  - With its own auditing suspended and in super mode, while logging is
    on it waits for the audit eventcount, or for the flush time when the
    list asks for a periodic flush.
  - After a timeout it writes back a dirty log buffer.
  - When logging is off it marks itself stopped and unbinds its process.

  Status stored: none.
}

procedure audit_$server;
var
  vals: array[1..4] of integer32;
  ecs: array[1..4] of ec_$eventcount_ptr_t;
  status: status_$t;
  wait_count: integer;
  wake: integer;
begin
  audit_$suspend_count[proc1_$current] := 1;
  audit_$server_running := true;
  ecs[1] := addr(audit_$wired^.ec);
  ecs[2] := ec_$eventcount_ptr_t(addr(time_$clockh));
  acl_$enter_super;

  if audit_$enabled then
    repeat
      wait_count := 1;
      ml_$exclusion_start(audit_$wired^.lock);
      if audit_flag_timeout in audit_$flags then begin
        if audit_$timeout <> 0 then
          vals[2] := time_$clockh + audit_$timeout * 4
        else
          vals[2] := time_$clockh + 16#1E0;
        wait_count := 2;
      end;
      ml_$exclusion_stop(audit_$wired^.lock);

      vals[1] := audit_$wired^.ec.value + 1;
      wake := ec_$waitn(ecs, vals, wait_count);

      ml_$exclusion_start(audit_$wired^.lock);
      if (wake = 2) and then (audit_$log_file_uid <> uid_$nil)
         and then audit_$dirty then begin
        audit_$dirty := false;
        file_$fw_file(audit_$log_file_uid, status);
      end;
      ml_$exclusion_stop(audit_$wired^.lock);
    until not audit_$enabled;

  audit_$server_running := false;
  acl_$exit_super;
  proc1_$unbind(audit_$server_pid, status);
end;
