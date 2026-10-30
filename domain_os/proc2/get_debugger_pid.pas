{ PROC2_$GET_DEBUGGER_PID - the PROC1 pid of the caller's debugger.

  Image addresses:
    sau2  0x00E41B72  PROC2_$GET_DEBUGGER_PID

  - 0 when the caller has no debugger, else the debugger's level-1 pid.

  Status stored: none.
}

function proc2_$get_debugger_pid: pinteger;
var
  dbg: pinteger;
begin
  dbg := proc2_$info_table[proc2_$pid_to_index[proc1_$current]].debugger_idx;

  if dbg = 0 then
    proc2_$get_debugger_pid := 0
  else
    proc2_$get_debugger_pid := proc2_$info_table[dbg].level1_pid;

end;
