{ sm_$seek - seek a storage module drive and wait for it to get there.

  Image addresses:
    sau3  0x00E6E492  sm_$seek (module-local)
    sau5  0x00E6F7EA  sm_$seek (module-local)

  - At most two tries.  A seek completes at the drive's second
    interrupt (the command's own is the first), waited for until the
    clock's high half advances by 8; a timeout is counted and retried.
  - A failed command resets the controller (a failed reset ends the
    tries).

  Returns:
    0: the drive got there
    the last try's status: sm_$reset's, sm_$check_status's or
      status_$drive_timed_out

  Status stored: none.
}

function sm_$seek(unit: integer; dcte: dcte_ptr_t; cyl: integer;
                  head: integer): integer32; internal;
var
  seek_status: status_$t;
  wait_value: integer32;
  try: integer;
begin
  with sm_$cb.drive[unit] do begin
    for try := 1 to 2 do begin
      sm_$cb.cyl := cyl;
      sm_$cb.head := head;
      wait_value := ec.value + 2;
      seek_status.all := sm_$command(unit, sm_cmd_seek);
      if seek_status.all <> 0 then begin
        sm_$reset(dcte, seek_status);
        if seek_status.all <> 0 then
          exit;
      end
      else begin
        seek_status.all := sm_$check_status(unit);
        if seek_status.all = 0 then begin
          if ec_$wait(addr(ec), addr(time_$clockh_ec),
                      addr(ec_$nil_ec), wait_value, time_$clockh + 8,
                      0) <> 0 then begin
            seek_status.all := status_$drive_timed_out;
            stats.counts[5] := stats.counts[5] + 1;
          end
          else begin
            seek_status.all := sm_$check_status(unit);
            if seek_status.all = 0 then
              exit;
          end;
        end;
      end;
    end;
  end;
  sm_$seek := seek_status.all;
end;
