{ PROC2_$COMPLETE_FORK - tell the parent that the forked child runs.

  Image addresses:
    sau2  0x00E735F8  PROC2_$COMPLETE_FORK

  - The current process's fork eventcount advances, which PROC2_$FORK's
    caller waits on.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$complete_fork;
var
  idx: integer;
begin
  idx := proc2_$pid_to_index[proc1_$current];
  ec_$advance(proc2_$ec[idx].fork_ec);
end;
