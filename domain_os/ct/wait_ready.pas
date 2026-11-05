{ ct_wait_ready - wait for the tape adapter to show ready.

  Image addresses:
    sau7  0x3C485536  ct_wait_ready (module-local)
    sau8  0x03C7A168  ct_wait_ready (module-local)

  - The adapter's status is polled until it shows ready or, unless
    ct_ignore_exception is set, an exception, or until timeout clock
    ticks (of 4) have gone by; then ct_ignore_exception is cleared.
  - The result is whether the adapter shows ready at the end.

  Status stored:
    status_$ok: the adapter is ready
    status_$ct_controller_timeout: it is not
}

function ct_wait_ready(timeout: integer32; out status: status_$t):
  boolean; internal;
var
  exception: boolean;
  ready: boolean;
  deadline: integer32;
begin
  exception := false;
  status.all := status_$ok;
  deadline := timeout * 4 + time_$clockh;
  repeat
    if ct_regs^.stat.not_ready then
      ready := false
    else
      ready := true;
    if not ct_ignore_exception then
      if ct_regs^.stat.no_exception then
        exception := false
      else
        exception := true;
  until exception or ready or (time_$clockh > deadline);
  if ct_regs^.stat.not_ready then
    ready := false
  else
    ready := true;
  ct_ignore_exception := false;
  if ready then
    ct_wait_ready := true
  else begin
    status.all := status_$ct_controller_timeout;
    ct_wait_ready := false;
  end;
end;
