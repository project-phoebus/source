{ PROC1_$GET_ANY_CPU_USAGE - any process's CPU time and two counters.

  Image addresses:
    sau2  0x00E1543E  PROC1_$GET_ANY_CPU_USAGE
    sau4  0x0F815CB2  PROC1_$GET_ANY_CPU_USAGE
    sau6  0x78015B92  PROC1_$GET_ANY_CPU_USAGE
    sau7  0x3C4170EA  PROC1_$GET_ANY_CPU_USAGE

  - An invalid pid crashes the system.  The counters are the PCB's two
    last longwords.
  - The CPU time returned is doubled, as PROC1_$GET_INFO's.

  Status stored: none.
}

procedure proc1_$get_any_cpu_usage(in pid_ptr: pinteger;
                                   out cpu_time_ret: time_$clock_t;
                                   out stat1_ret: integer32;
                                   out stat2_ret: integer32);
var
  pcb: proc1_$pcb_ptr_t;
begin
  if (pid_ptr = 0) or else (pid_ptr > 64) then
    crash_system(status_$illegal_process_id);
  pcb := pcbs[pid_ptr];
  cpu_time_ret := pcb^.cpu.total;
  add48(cpu_time_ret, pcb^.cpu.total);
  stat1_ret := pcb^.field_60;
  stat2_ret := pcb^.field_64;
end;
