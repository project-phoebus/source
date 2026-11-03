{ LPR_$STATE - the port's state; set its mode.

  Image addresses:
    sau3  0x00E6E792  LPR_$STATE
    sau4  0x0F87B5CC  LPR_$STATE

  - For the process that acquired the printer.  When the request's mode
    has bit 7 set, its low two bits select the mode, which is set unless
    it is 3 or is mode 2 while bit 9 of the port's word at 0x40 is set
    (the status is stored and the flags still returned).
  - The answer is the port's flags and the mode word as given.
  - The PNA form reports the port ready (flag 7) and refuses a mode
    with status_$lpr_mode_refused.

  Status stored:
    status_$ok: the state was returned (and the mode set)
    status_$lpr_not_acquired: the caller did not acquire the printer
    status_$lpr_invalid_mode: mode 3
    status_$lpr_mode_unavailable: mode 2 is not available
}

%if lpr_pbu_unit %then
procedure lpr_$state(in out state: lpr_$state_t; out status: status_$t);
begin
  if lpr_owner <> proc1_$current then begin
    status.all := status_$lpr_not_acquired;
    return;
  end;
  status.all := status_$ok;
  lpr_state.flags := [];
  if lpr_ready_bit in lpr_$word_bits_t(pbu_ctl.word_04) then
    lpr_state.flags := lpr_state.flags + [lpr_flag_ready];
  if lpr_mode_set in state.mode_bits then
    status.all := status_$lpr_mode_refused;
  state := lpr_state;
end;
%else
procedure lpr_$state(in out state: lpr_$state_t; out status: status_$t);
begin
  if lpr_owner <> proc1_$current then begin
    status.all := status_$lpr_not_acquired;
    return;
  end;
  status.all := status_$ok;
  lpr_state.flags := [];
  lpr_state.mode := state.mode;
  if lpr_mode_set in lpr_state.mode_bits then
    if (lpr_state.mode & 3) > 2 then
      status.all := status_$lpr_invalid_mode
    else if ((lpr_state.mode & 3) = 2) and then (9 in lpr.config) then
      status.all := status_$lpr_mode_unavailable
    else
      lpr_set_mode;

  if (lpr.reg_18 & 16#FE) = 0 then
    lpr_state.flags := lpr_state.flags + [lpr_flag_status_clear];
  if 1 in lpr.status then
    lpr_state.flags := lpr_state.flags + [lpr_flag_status_1];
  if 2 in lpr.status then
    lpr_state.flags := lpr_state.flags + [lpr_flag_status_2];
  state := lpr_state;
end;
%endif
