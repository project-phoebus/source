{ TIME_$SET_CPU_LIMIT_CALLBACK - the CPU time limit's expiry callback.

  Image addresses:
    sau2  0x00E58AF8  TIME_$SET_CPU_LIMIT_CALLBACK
    sau4  0x0F860F6C  TIME_$SET_CPU_LIMIT_CALLBACK

  - While the address space's CPU-limit element's expiry is set, the
    process is signaled (signal 27, time_$cpu_limit_f).

  Status stored: none.
}

procedure time_$set_cpu_limit_callback(in arg: time_$callback_arg_ptr_t);
var
  a: time_$callback_arg_ptr_t;
  status: status_$t;
begin
  a := arg;
  with time_$cpu_limit_db[a^.as_id].elem do
    if (expire.high <> 0) or else (expire.low <> 0) then
      proc2_$signal_os(proc2_$uid[a^.as_id], 27, time_$cpu_limit_f, status);
end;
