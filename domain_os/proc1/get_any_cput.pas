{ PROC1_$GET_ANY_CPUT - any process's CPU time.

  Image addresses:
    sau2  0x00E153F8  PROC1_$GET_ANY_CPUT
    sau4  0x0F815C6C  PROC1_$GET_ANY_CPUT
    sau6  0x78015B4C  PROC1_$GET_ANY_CPUT
    sau7  0x3C4170A4  PROC1_$GET_ANY_CPUT

  - An invalid pid crashes the system.

  Status stored: none.
}

procedure proc1_$get_any_cput(out cpu_time_ret: time_$clock_t; pid: pinteger);
begin
  if (pid = 0) or else (pid > 64) then
    crash_system(status_$illegal_process_id);
  cpu_time_ret := pcbs[pid]^.cpu.total;
end;
