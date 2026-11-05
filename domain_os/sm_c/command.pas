{ sm_c_$command - issue a command to the SM_C controller and wait for
  its completion.

  Image addresses:
    sau3  0x00E6F030  sm_c_$command (module-local)
    sau4  0x0F87BE2C  sm_c_$command (module-local)
    sau5  0x00E74B94  sm_c_$command (module-local)
    sau6  0x7807B8E0  sm_c_$command (module-local)

  - The wait is for the unit's eventcount or 20 clock ticks; a time-out
    is counted and gives status_$disk_controller_busy, else the result
    is the unit's status (sm_c_$check_status).
  - The other command bytes are the callers'.

  Status stored: none.
}

function sm_c_$command(unit: integer; cmd: integer): integer32;
  internal;
var
  wait_value: integer32;
begin
  with sm_$cb.c_unit[unit] do begin
    sm_$cb.c_b11 := 0;
    sm_$cb.c_mode_unit.unit := unit;
    sm_c_unit := unit;
    sm_$cb.c_cmd := cmd;
    sm_$cb.c_status.all := 0;
%if memory_parity %then
    flags.parity_err := false;
%endif
    wait_value := ec.value + 1;
    pbu_sm_c_page.cmd := sm_c_reg_go;
    if ec_$wait(addr(ec), addr(time_$clockh_ec), addr(ec_$nil_ec),
                wait_value, time_$clockh + 20, 0) <> 0 then begin
      stats.counts[2] := stats.counts[2] + 1;
      sm_c_$command := status_$disk_controller_busy;
    end
    else
      sm_c_$command := sm_c_$check_status(unit);
  end;
end;
