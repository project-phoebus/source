{ SMD_$ACQ_DISPLAY - acquire the display lock of the caller's unit.

  Image addresses:
    sau2  0x00E6EB42  SMD_$ACQ_DISPLAY
    sau5  0x00E70FC0  SMD_$ACQ_DISPLAY
    sau9  0x3C47552E  SMD_$ACQ_DISPLAY

  - SMD_$LOCK_DISPLAY is tried until it succeeds; lock_data 1 marks a
    request in the record (+0x20) while the routine waits.
  - Lock states 1..5 and 7 wait for the lock eventcount, or 40 ticks
    after which the state is forced to 0; state 6 is forced to 0 at once.
  - With `display_devices' (base/config.ins.pas) the unit's device
    locks the display; any state times out after 40 ticks.
  - The result is the display's video flags, read at entry.

  Status stored: none.
}

function smd_$acq_display(in lock_data: integer): integer;
var
  clock_target: integer32;
  lock_ec_target: integer32;
  disp: smd_display_hw_ptr_t;
  unit_num: pinteger;
  video_flags: integer;
  timed_out: boolean;
begin
  unit_num := asid_to_unit[proc1_$as_id];
%if display_devices %then
  with smd_$wired_data.unit[unit_num] do begin
    disp := hw;
    video_flags := disp^.video_flags;
    while not vector^.lock_display^(dcte, disp^, lock_data) do begin
      lock_ec_target := disp^.lock_ec.value + 1;
      clock_target := time_$clockh + 40;
      timed_out := ec_$wait(addr(disp^.lock_ec),
                            ec_$eventcount_ptr_t(addr(time_$clockh)),
                            addr(ec_$nil_ec),
                            lock_ec_target, clock_target, 0) <> 0;
      if timed_out then
        disp^.lock_state := 0;
    end;
  end;
%else
  disp := smd_$wired_data.unit[unit_num].hw;
  video_flags := disp^.video_flags;
  while not smd_$lock_display(disp^, lock_data) do begin
    lock_ec_target := disp^.lock_ec.value + 1;
    clock_target := time_$clockh + 40;
    if lock_data = 1 then
      disp^.field_20 := true;
    case disp^.lock_state of
      1, 2, 3, 4, 5, 7: begin
        timed_out := ec_$wait(addr(disp^.lock_ec),
                              ec_$eventcount_ptr_t(addr(time_$clockh)),
                              addr(ec_$nil_ec),
                              lock_ec_target, clock_target, 0) <> 0;
        if timed_out then
          disp^.lock_state := 0;
      end;
      6: begin
        disp^.lock_state := 0;                       { merged with arm 1's }
      end;
    end;
    disp^.field_20 := false;
  end;
%endif
  smd_$acq_display := video_flags;
end;
