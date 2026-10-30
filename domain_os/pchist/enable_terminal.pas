{ pchist_$enable_terminal - tell the terminal manager how many profilers
  are on.

  Image addresses:
    sau2  0x00E5CA00  pchist_$enable_terminal (module-local)

  - The number of active profilers (per-process and system) goes to
    TERM_$PCHIST_ENABLE; the first one turned on writes one '.' to
    terminal line 2.  Neither status is looked at.

  Status stored: none.
}

procedure pchist_$enable_terminal(disabling: integer); internal;
var
  status: status_$t;
  total: integer;
  count: integer;
begin
  count := pchist_$proc_profiling_count + pchist_$sys_profiling_count;
  total := count;
  term_$pchist_enable(total, status);

  if (disabling = 0) and then (count = 1) then
    term_$write(2, '..', 1, status);
end;
