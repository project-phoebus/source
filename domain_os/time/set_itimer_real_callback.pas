{ TIME_$SET_ITIMER_REAL_CALLBACK - the real interval timer's expiry callback.

  Image addresses:
    sau2  0x00E58A38  TIME_$SET_ITIMER_REAL_CALLBACK
    sau4  0x0F860EAC  TIME_$SET_ITIMER_REAL_CALLBACK
    sau6  0x7805FDE8  TIME_$SET_ITIMER_REAL_CALLBACK
    sau7  0x3C468BE8  TIME_$SET_ITIMER_REAL_CALLBACK

  - While the address space's real interval timer element's expiry is
    set, the process is signaled (signal 14, time_$itimer_real).

  Status stored: none.
}

procedure time_$set_itimer_real_callback(in arg: time_$callback_arg_ptr_t);
var
  a: time_$callback_arg_ptr_t;
  status: status_$t;
begin
  a := arg;
  with time_$itimer_db[0][a^.as_id].elem do
    if (expire.high <> 0) or else (expire.low <> 0) then
      proc2_$signal_os(proc2_$uid[a^.as_id], 14, time_$itimer_real, status);
end;
