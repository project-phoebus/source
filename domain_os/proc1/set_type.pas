{ PROC1_$SET_TYPE - record a process's type.

  Image addresses:
    sau2  0x00E152E4  PROC1_$SET_TYPE
    sau4  0x0F815B58  PROC1_$SET_TYPE

  - An invalid pid crashes the system.

  Status stored: none.
}

procedure proc1_$set_type(pid: pinteger; proc_type: integer);
begin
  if (pid = 0) or else (pid > 64) then
    crash_system(status_$illegal_process_id);
  proc1_$type[pid] := proc_type;
end;
