{ AUDIT_$IS_PROCESS_AUDITED - whether the current process is audited.

  Image addresses:
    sau2  0x00E70D94  AUDIT_$IS_PROCESS_AUDITED

  - True when the current process's suspension count is 0.

  Status stored: none.
}

function audit_$is_process_audited: boolean;
begin
  audit_$is_process_audited :=
    audit_$suspend_count[proc1_$current] = 0;
end;
