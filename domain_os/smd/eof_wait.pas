{ SMD_$EOF_WAIT - wait for the display's next end of frame, or a quit.

  Image addresses:
    sau2  0x00E6F3AE  SMD_$EOF_WAIT
    sau4  0x0F879B0E  SMD_$EOF_WAIT
    sau5  0x00E7177A  SMD_$EOF_WAIT

  - The display is acquired, its end-of-frame interrupt armed (mode word
    16#21: ieof and dispon), and the mode word SMD_$ACQ_DISPLAY returned
    put back after the wait; a quit is noted as seen.
  - With `color_displays' a color display is refused after the display
    is acquired.

  Status stored:
    status_$ok: the end of frame came
    smd_$illegal_caller: the process has no display unit
    smd_$quit_while_waiting: the process was told to quit
    smd_$not_on_color: with `color_displays' (base/config.ins.pas), a
      color display (types 3..6)
}

{ TODO(pascal) SMD_$EOF_WAIT's frame: 4 of its 0x14 bytes not accounted

  The image's frame is 20 bytes, and the code addresses one frame slot,
  target at -0x4; unit_num, mode and woken are in registers, the `with'
  pointers too.  dpc's layout of the four locals (target -4, unit_num
  -6, mode -8, woken -10, and a `with' slot) is 16 bytes; the other 4
  (a second `with' slot for the two records?) are not accounted, as in
  SMD_$SOFT_SCROLL. }

procedure smd_$eof_wait(out status: status_$t);
var
  target: integer32;                      { also held in a register }
  unit_num: pinteger;
  mode: integer;
  woken: boolean;
begin
  unit_num := asid_to_unit[proc1_$as_id];
  if unit_num = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  mode := smd_$acq_display(0);
  with smd_$wired_data.unit[unit_num], hw^ do begin
%if color_displays %then
    if display_type in [smd_$color_display..smd_$color3_display] then
      begin
      status.all := smd_$not_on_color;
      return;
      end;
%endif
    target := lock_ec.value + 1;
    lock_state := 7;
    ctrl_regs^.mode := 16#21;
    woken := ec_$wait(addr(lock_ec),
                      addr(fim_$quit_ec[proc1_$as_id]),
                      addr(ec_$nil_ec),
                      target, fim_$quit_value[proc1_$as_id] + 1,
                      0) = 0;
    if woken then
      status.all := status_$ok
    else begin
      status.all := smd_$quit_while_waiting;
      fim_$quit_value[proc1_$as_id] :=
        fim_$quit_ec[proc1_$as_id].value;
    end;
    ctrl_regs^.mode := mode;
  end;
  smd_$rel_display;
end;
