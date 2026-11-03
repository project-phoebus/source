{ TIME_$SET_ITIMER_VIRT_CALLBACK - the virtual interval timer's expiry callback.

  Image addresses:
    sau2  0x00E58A98  TIME_$SET_ITIMER_VIRT_CALLBACK
    sau4  0x0F860F0C  TIME_$SET_ITIMER_VIRT_CALLBACK

  - While the address space's virtual interval timer element's expiry
    is set, the process is signaled (signal 29, time_$itimer_virtual).

  Status stored: none.
}

procedure time_$set_itimer_virt_callback(in arg: time_$callback_arg_ptr_t);
var
  a: time_$callback_arg_ptr_t;
  status: status_$t;
begin
  a := arg;
  with time_$itimer_db[1][a^.as_id].elem do
    if (expire.high <> 0) or else (expire.low <> 0) then
      proc2_$signal_os(proc2_$uid[a^.as_id], 29, time_$itimer_virtual, status);
end;
