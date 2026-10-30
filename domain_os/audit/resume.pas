{ AUDIT_$RESUME - resume auditing of the current process.

  Image addresses:
    sau2  0x00E70DD6  AUDIT_$RESUME

  - The current process's suspension count is lowered by one.

  Status stored: none.
}

procedure audit_$resume;
begin
  audit_$suspend_count[proc1_$current] :=
    audit_$suspend_count[proc1_$current] - 1;
end;
