{ TIME_$WAIT2 - wait until a time or until an eventcount reaches a value.

  Image addresses:
    sau2  0x00E16654  TIME_$WAIT2
    sau4  0x0F817034  TIME_$WAIT2
    sau6  0x780170D0  TIME_$WAIT2
    sau7  0x3C4180BC  TIME_$WAIT2
    sau8  0x03C1756C  TIME_$WAIT2
    sau9  0x3C4186D8  TIME_$WAIT2

  - A local eventcount is set to be advanced at the time (a failure
    crashes the system), then the given eventcount (for wait_value) and
    the local one are waited for.
  - If the time did not come first, the advance is canceled.
  - The result is whether the given eventcount ended the wait.  An
    element left in use crashes the system.

  Status stored:
    status_$ok: always
}

function time_$wait2(rel_abs: time_$rel_abs_t; in delay: time_$clock_t;
                     var ec: ec_$eventcount_t; in wait_value: integer32;
                     out status: status_$t): boolean;
var
  local_ec: ec_$eventcount_t;
  elem: time_$queue_elem_t;
  local_status: status_$t;
  which: integer;
begin
  status.all := status_$ok;
  elem.flags := [];
  ec_$init(local_ec);

  time_$advance(rel_abs, delay, local_ec, elem, local_status);
  if local_status.all <> status_$ok then begin
    crash_system(local_status);
    status := local_status;
    return;
  end;

  which := ec_$wait(addr(ec), addr(local_ec), addr(ec_$nil_ec), wait_value,
                    1, 0);
  if which <> 1 then
    time_$cancel(1, elem, local_status);

  if elem.flags <> [] then
    crash_system(time_$q_elem_in_use);
  time_$wait2 := which = 0;
end;
