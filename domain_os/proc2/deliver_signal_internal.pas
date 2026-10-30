{ proc2_$deliver_signal_internal - post a signal to a process entry.

  Image addresses:
    sau2  0x00E3EB8C  proc2_$deliver_signal_internal (module-local)

  - SIGCONT, SIGKILL or a BLAST SIGAPOLLO resume a suspended target; a
    target stopped for its debugger gets SIGKILL or BLAST as its fault.
  - SIGCONT and the stop signals take each other out of the pending set;
    a signal the target does not take, or one of the dropped set, ends.
  - Otherwise the signal is marked pending and, unless the target is
    suspended, delivered.

  Status stored:
    status_$ok: the signal was posted, or dropped
    status_$proc2_another_fault_pending: a SIGAPOLLO with one pending
}

procedure proc2_$deliver_signal_internal(proc_index: integer;
                                         signal: integer;
                                         param: status_$t;
                                         out status_ret: status_$t);
var
  sig_m1: integer;
  sig_bit: set of 0..31;
begin
  status_ret.all := status_$ok;
  sig_m1 := signal - 1;
  sig_bit := [sig_m1];
  with proc2_$info_table[proc_index] do begin
    if 6 in flags.bits then
      if ((signal = proc2_$sig_cont) or (signal = proc2_$sig_kill))
         or else ((signal = proc2_$sig_apollo)
                  and then (param.all = fault_$blast)) then begin

        flags.bits := flags.bits - [6];
        proc1_$resume(level1_pid, status_ret);
      end;
    if (4 in flags.bits)
       and then ((signal = proc2_$sig_kill)
                 or else ((signal = proc2_$sig_apollo)
                          and then (param.all = fault_$blast))) then begin

      fault_param.all := param.all;
      fault_param.signal_flag := true;
      pad_94 := signal;
      flags.bits := flags.bits - [4];
      proc1_$resume(level1_pid, status_ret);
      return;
    end;
    if signal = proc2_$sig_cont then
      sig_mask_2 := sig_mask_2 - proc2_$stop_signals;
    if sig_bit - sig_blocked.blocked_1 = [] then begin
      if signal = proc2_$sig_hup then
        flags.bits := flags.bits + [9];
      if debugger_idx = 0 then
        return;
    end;
    if sig_bit * proc2_$not_stop_signals = [] then begin
      sig_mask_2 := sig_mask_2 - [proc2_$sig_cont - 1];
      if 6 in flags.bits then
        return;
    end;
    if (sig_bit - sig_pending <> [])
       and then (sig_bit - sig_blocked.blocked_2 <> [])
       and then (sig_bit * proc2_$not_default_ignored_signals = [])
       then
      return;
    if signal = proc2_$sig_apollo then begin
      if (sig_bit - sig_mask_2 = [])
         and then (param.all <> fault_$blast) then begin
        status_ret.all := status_$proc2_another_fault_pending;

        return;
      end;
      sig_status := param.all;
    end;
    sig_mask_2 := sig_mask_2 + sig_bit;
    if not (6 in flags.bits) then
      proc2_$deliver_pending_internal(proc_index);
  end;
end;
