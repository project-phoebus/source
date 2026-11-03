{ sm_$wait_ready - wait for the storage module controller to take a
  command.

  Image addresses:
    sau3  0x00E6DB12  sm_$wait_ready (module-local)
    sau5  0x00E6EE6A  sm_$wait_ready (module-local)

  - Waits while the command block's busy byte is set, until the clock's
    high half passes its value at entry plus 9.

  Returns:
    0: the busy byte is clear
    status_$disk_controller_timeout: it is still set

  Status stored: none.
}

function sm_$wait_ready: integer32; internal;
var
  deadline: integer32;
begin
  deadline := time_$clockh + 9;
  repeat
  until (sm_$cb.busy = 0) or else (deadline < time_$clockh);
  if sm_$cb.busy = 0 then
    sm_$wait_ready := 0
  else
    sm_$wait_ready := status_$disk_controller_timeout;
end;
