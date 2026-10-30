{ AUDIT_$SUSPEND - suspend auditing of the current process.

  Image addresses:
    sau2  0x00E70DB6  AUDIT_$SUSPEND

  - The current process's suspension count is raised by one; the
    process is not audited while the count is above 0.

  Status stored: none.
}

procedure audit_$suspend;
begin
  audit_$suspend_count[proc1_$current] :=
    audit_$suspend_count[proc1_$current] + 1;
end;
