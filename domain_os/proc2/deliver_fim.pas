{ PROC2_$DELIVER_FIM - pick the signal FIM is to deliver to the current
  process.

  Image addresses:
    sau2  0x00E3EDC0  PROC2_$DELIVER_FIM

  - Under ml_$proc2_lock: with the status's signal flag FIM asks for the
    next pending signal (a default-ignored one not caught dropped);
    without it a blocked SIGILL, SIGTRAP or SIGFPE is left pending.
  - A signal goes first to the debugger (XPD_$CAPTURE_FAULT); then it is
    marked pending and the mask to restore handed back.  The result is
    whether there is one; with none, FIM's acknowledge is called.

  Status stored (in status, the fault parameter):
    the signal's SIGAPOLLO status, or 0: the next pending signal
}

function proc2_$deliver_fim(in out signal: integer;
                            in out status: univ proc2_$fault_param_t;
                            in out usp: integer32;
                            regs: univ_ptr;
                            sr_pc: univ_ptr;
                            out mask: integer32;
                            out flag: boolean): boolean;
label
  caller_signal, deliver, no_signal, unlock;
var
  result: boolean;
  idx: integer;
  sig_bit: set of 0..31;
  sig_m1: integer;
begin
  result := true;
  idx := proc2_$pid_to_index[proc1_$current];
  ml_$lock(ml_$proc2_lock);
  with proc2_$info_table[idx] do begin
    repeat
      if not status.signal_flag then
        goto caller_signal;
      signal := proc2_$get_next_pending_signal(
                  proc2_$info_table[idx]);
      if signal = 0 then
        goto no_signal;
      sig_bit := [signal - 1];
      if (sig_bit * proc2_$not_default_ignored_signals <> [])
         or else (sig_bit - sig_pending = []) then
        exit;
      sig_mask_2 := sig_mask_2 - sig_bit;
    until false;
    if signal = proc2_$sig_apollo then
      status.all := sig_status
    else
      status.all := 0;
    status.signal_flag := true;
    goto deliver;
  caller_signal:
    sig_m1 := signal - 1;
    sig_bit := [sig_m1];
    if sig_bit * proc2_$not_fault_signals <> [] then
      goto deliver;
    if sig_bit - sig_blocked.blocked_2 <> [] then begin
      if sig_bit - sig_blocked.blocked_1 <> [] then
        goto deliver;
      if sig_bit - sig_blocked.blocked_2 <> [] then
        goto no_signal;
    end;
    sig_mask_2 := sig_mask_2 + sig_bit;
    goto no_signal;
  deliver:
    if debugger_idx <> 0 then begin
      xpd_$capture_fault(regs, sr_pc, signal, status);
      if signal = 0 then begin
        result := false;
        goto unlock;
      end;
      sig_m1 := signal - 1;
      sig_bit := [sig_m1];
    end;
    sig_mask_2 := sig_mask_2 + sig_bit;
    flag := 10 in flags.bits;
    if (sig_bit - sig_mask_3 = [])
       and then not (10 in flags.bits) then
      usp := integer32(sig_mask_4);
    if 14 in flags.bits then begin
      mask := pad_88;
      flags.bits := flags.bits - [14];
    end
    else
      mask := integer32(sig_blocked.blocked_2);
    goto unlock;
  end;
no_signal:
  result := false;
  fim_$acknowledge;
unlock:
  ml_$unlock(ml_$proc2_lock);
  proc2_$deliver_fim := result;
end;
