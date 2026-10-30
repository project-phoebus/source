{ AUDIT_$INHERIT_AUDIT - give a child process its parent's suspension
  count.

  Image addresses:
    sau2  0x00E7169C  AUDIT_$INHERIT_AUDIT

  - The child's suspension count becomes the current process's.

  Status stored:
    status_$ok: always
}

procedure audit_$inherit_audit(in child_pid: integer;
                               out status_ret: status_$t);
begin
  audit_$suspend_count[child_pid] := audit_$suspend_count[proc1_$current];
  status_ret.all := status_$ok;
end;
