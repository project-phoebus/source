{ PROC1_$GET_TYPE - a process's type.

  Image addresses:
    sau2  0x00E15324  PROC1_$GET_TYPE
    sau4  0x0F815B98  PROC1_$GET_TYPE

  - An invalid pid crashes the system.

  Status stored: none.
}

procedure proc1_$get_type(pid: pinteger; out type_ret: integer);
begin
  if (pid = 0) or else (pid > 64) then
    crash_system(status_$illegal_process_id);
  type_ret := proc1_$type[pid];
end;
