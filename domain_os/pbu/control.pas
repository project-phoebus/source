{ PBU_$CONTROL - inquire and set a PBU unit's transfer control.

  Image addresses:
    sau3  0x00E58CE2  PBU_$CONTROL
    sau5  0x00E58E8E  PBU_$CONTROL

  - The answer is [0] while the unit's control has wide clear (with
    `long_iomap'; narrow set without), [1] otherwise, plus member 2, 3
    or 4 for its mode 0, 1 or 2.
  - A nonempty request sets the control anew: member 0 without 1 clears
    wide (sets narrow), member 3 sets mode 1, member 4 (without 3) mode
    2.  The fourth argument is not read.

  Status stored:
    pbu_check_unit's status: the control was read or set, or the unit is
      not the caller's
    status_$pbu_not_supported: the unit is on the VME bus (`vme_bus')
    status_$pbu_bad_parameter: member 0 with 1, 3 with 2 or 4, or 4 with
      2 (the control unchanged)
}

procedure pbu_$control(in unit: integer; in request: pbu_$ctl_word_t;
                       out answer: pbu_$ctl_word_t; in unused: integer;
                       out status: status_$t);
var
  new_ctl: pbu_$ctl_t;
  old_ctl: pbu_$ctl_t;
  dcte: pbu_$dcte_ptr_t;
begin
  new_ctl.all := 0;
%if long_iomap %then
  new_ctl.wide := true;
%endif
  new_ctl.bit_15 := true;
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
%if vme_bus %then
  if dcte^.unit_info.bus = io_$bus_vme then begin
    status.all := status_$pbu_not_supported;
    return;
  end;
%endif
  old_ctl := dcte^.ctl;
%if long_iomap %then
  if not old_ctl.wide then
%else
  if old_ctl.narrow then
%endif
    answer := [0]
  else
    answer := [1];
  case old_ctl.mode of
    0: answer := answer + [2];
    1: answer := answer + [3];
    2: answer := answer + [4];
  end;
  if request = [] then
    return;
  if 0 in request then begin
    if 1 in request then begin
      status.all := status_$pbu_bad_parameter;
      return;
    end;
%if long_iomap %then
    new_ctl.wide := false;
%else
    new_ctl.narrow := true;
%endif
  end;
  if 3 in request then begin
    if request * [2, 4] <> [] then begin
      status.all := status_$pbu_bad_parameter;
      return;
    end;
    new_ctl.mode := 1;
  end
  else if 4 in request then begin
    if request * [2, 3] <> [] then begin
      status.all := status_$pbu_bad_parameter;
      return;
    end;
    new_ctl.mode := 2;
  end;
  dcte^.ctl := new_ctl;
end;
