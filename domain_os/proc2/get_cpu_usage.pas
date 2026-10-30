{ PROC2_$GET_CPU_USAGE - the calling process's CPU usage.

  Image addresses:
    sau2  0x00E41D2A  PROC2_$GET_CPU_USAGE

  - PROC1's CPU time and two statistics, the last longword 16#411C (as
    PROC2_$GET_INFO's).

  Status stored: none.
}

procedure proc2_$get_cpu_usage(out usage: proc2_$wait_usage_t);
var
  unused_04: integer32;                   { a stand-in, below }
  local_usage: proc2_$wait_usage_t;
begin
  proc1_$get_cpu_usage(local_usage.cpu_time, local_usage.counts.stat1,
                       local_usage.counts.stat2);
  usage := local_usage;
  usage.counts.field_10 := 16#411C;
end;
