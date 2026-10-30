{ SMD_$REL_DISPLAY - release the display lock of the caller's unit.

  Image addresses:
    sau2  0x00E6EC10  SMD_$REL_DISPLAY
    sau5  0x00E71094  SMD_$REL_DISPLAY
    sau9  0x3C4755DC  SMD_$REL_DISPLAY

  - In lock state 4 (a scroll in progress) SMD_$CONTINUE_SCROLL takes the
    lock over; any other state becomes 0, unlocked.  With
    `display_devices' (base/config.ins.pas) the state becomes 0 and the
    unit's device releases the display.
  - The lock eventcount is advanced, waking SMD_$ACQ_DISPLAY's waiters.

  Status stored: none.
}

procedure smd_$rel_display;
var
  unit_num: pinteger;
  disp: smd_display_hw_ptr_t;
begin
  unit_num := asid_to_unit[proc1_$as_id];
  with smd_$wired_data.unit[unit_num] do begin
    disp := hw;
%if display_devices %then
    disp^.lock_state := 0;
    vector^.rel_display^(dcte, disp^);
%else
    if disp^.lock_state = 4 then
      smd_$continue_scroll(disp^, ctrl_regs)
    else
      disp^.lock_state := 0;
%endif
    ec_$advance(disp^.lock_ec);
  end;
end;
