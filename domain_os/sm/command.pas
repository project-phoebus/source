{ sm_$command - issue a command to a storage module drive and wait for
  its completion.

  Image addresses:
    sau3  0x00E6DE20  sm_$command (module-local)
    sau4  0x0F87759C  sm_$command (module-local)
    sau5  0x00E6F178  sm_$command (module-local)

  - The other command words (cylinder, head, buffer) are its callers'.
  - The wait for completion ends when the clock's high half advances by
    8; a timeout is counted in the drive's counters.

  Returns:
    0: the command completed
    sm_$wait_ready's status: the controller did not become free
    status_$drive_timed_out: the command did not complete in time

  Status stored: none.
}

function sm_$command(unit: integer; cmd: integer): integer32; internal;
var
  status: integer32;
  wait_value: integer32;
begin
  sm_$cb.cmd_word.unit := unit;
  sm_$cb.cmd_word.cmd := cmd;
%if memory_parity %then
  sm_$cb.drive[unit].parity_err := false;
%endif
  status := sm_$wait_ready;
  if status <> 0 then begin
    sm_$command := status;
    return;
  end;

  wait_value := sm_$cb.drive[unit].ec.value + 1;
  pbu_sm_page.go := sm_$cb.go_cmd;
  if ec_$wait(addr(sm_$cb.drive[unit].ec), addr(time_$clockh_ec),
              addr(ec_$nil_ec), wait_value, time_$clockh + 8, 0) <> 0 then
  begin
    sm_$cb.drive[unit].stats.counts[5] :=
      sm_$cb.drive[unit].stats.counts[5] + 1;
    sm_$command := status_$drive_timed_out;
  end
  else
    sm_$command := 0;
end;
